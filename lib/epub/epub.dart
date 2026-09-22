import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:archive/archive.dart';

// ─────────────────────────────────────────────────────────────
// Content Model (short names)
// ─────────────────────────────────────────────────────────────

sealed class Chunk {
  String get text;
  String get lang => '';
}

class TextBlock extends Chunk {
  @override
  final String lang;
  final List<Inline> inlines;
  final int? headingLevel; // 1–6 for <h1>–<h6>, null = normal <p>
  final String? epubType;

  TextBlock(this.inlines, {this.lang = '', this.headingLevel, this.epubType});
  factory TextBlock.single(String text, {String lang = ''}) =>
      TextBlock([InlineText(text)], lang: lang);

  @override
  String get text => inlines.map((e) => e.text).join('');

  @override
  String toString() => '[${inlines.join("")}]';
}

class BlockImage extends Chunk {
  final String src;
  final String? alt;
  final String? id;
  final String? epubType;

  BlockImage(this.src, {this.alt, this.id, this.epubType});

  @override
  String get text => '';

  @override
  String toString() => '[img $src]';
}

class BlockList extends Chunk {
  final bool ordered;
  final List<ListItem> items;
  final String? epubType; // ← added

  BlockList(this.items, {this.ordered = false, this.epubType});

  @override
  String get text => items.map((i) => i.text).join('');

  @override
  String toString() => '[list ${items.length}:\n${items.join("\n")}]';
}

/// bullet point: ••‣⁃◦▪
class ListItem {
  final List<Chunk> content;

  ListItem(this.content);

  String get text => content.map((c) => c.text).join('');

  @override
  String toString() => '• ${content.join("\n")}';
}

class Table extends Chunk {
  final List<TableRow> rows;

  Table(this.rows);

  @override
  String get text => rows.map((i) => i.text).join('');

  @override
  String toString() => 'Table(rows: ${rows.length})';
}

class TableRow {
  final List<TableCell> cells;
  final bool isHeader;

  String get text => cells.map((cell) => cell.text).join('');

  TableRow(this.cells, {this.isHeader = false});
}

class TableCell {
  final List<Chunk> content;
  final int colspan;
  final int rowspan;

  String get text => content.map((c) => c.text).join('');

  TableCell(this.content, {this.colspan = 1, this.rowspan = 1});
}

class MathBlock extends Chunk {
  final String content;
  final bool display;

  MathBlock(this.content, {this.display = true});

  @override
  String get text => '';
}

class UnknownBlock extends Chunk {
  final String tag;

  UnknownBlock(this.tag);

  @override
  String get text => '';
}

// ─────────────────────────────────────────────────────────────
// Inline content
// ─────────────────────────────────────────────────────────────

sealed class Inline {
  String get text;
}

class InlineText extends Inline {
  @override
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool superscript;
  final bool subscript;

  InlineText(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.superscript = false,
    this.subscript = false,
  });

  @override
  String toString() {
    final mark = [
      if (bold) '*',
      if (italic) '_',
      if (underline) 'u',
      if (superscript) '^',
      if (subscript) 'v',
      '',
    ].join('');
    return '$mark${text.replaceAll("\n", "")}$mark';
  }
}

class InlineImage extends Inline {
  final String src;
  final String? alt;

  InlineImage(this.src, {this.alt});

  @override
  String get text => '';

  @override
  String toString() => '<img $src>';
}

class Hyperlink extends Inline {
  final String href;
  final String? epubType;
  final List<Inline> children;

  @override
  String get text => children.map((e) => e.text).join('');

  Hyperlink(this.href, {this.epubType, this.children = const []});

  @override
  String toString() => '<a to=$href>${children.join("")}></a>';
}

class Anchor extends Inline {
  final String id;
  Anchor(this.id);

  @override
  String get text => '';

  @override
  String toString() => '<a name=$id>';
}

class MathInline extends Inline {
  final String content;
  MathInline(this.content);

  @override
  String get text => '';
}

// ─────────────────────────────────────────────────────────────
// Extractor
// ─────────────────────────────────────────────────────────────

class HtmlExtractor {
  HtmlExtractor(this.href);
  final String href; // base url

  /// for path ../images/some.png
  /// return absolute path base on href
  String resolve(String path) {
    final base = Uri(path: href);
    print('$path => ${base.resolve(path).path}');
    return base.resolve(path).path.toLowerCase();
  }

  List<Chunk> extract(dom.Node root) {
    // TODO: ensure root not Document
    final result = <Chunk>[];
    _walk(root, result, lang: '');
    return result;
  }

  void _walk(dom.Node node, List<Chunk> output, {required String lang}) {
    if (node is dom.Text) {
      final text = _normalize(node.text);
      if (text.isNotEmpty) {
        output.add(TextBlock([InlineText(text)], lang: lang));
      }
      return;
    }

    if (node is! dom.Element) return;

    final tag = node.localName?.toLowerCase() ?? '';
    if (_isIgnorable(tag)) return;

    final currentLang = _langOf(node, lang);

    switch (tag) {
      case 'img':
      case 'image':
        final src = _imageSrc(node);
        if (src.isNotEmpty) {
          output.add(
            BlockImage(
              resolve(src),
              alt: node.attributes['alt'],
              id: node.attributes['id'],
            ),
          );
        }
        return;

      case 'svg':
        for (final child in node.nodes) {
          _walk(child, output, lang: currentLang);
        }
        return;

      case 'ul':
      case 'ol':
        output.add(_extractList(node, ordered: tag == 'ol', lang: currentLang));
        return;

      case 'table':
        output.add(_extractTable(node, lang: currentLang));
        return;

      case 'math':
      case 'mjx-container':
        output.add(MathBlock(node.outerHtml));
        return;

      case 'p':
        // Case: <p><img ...></p>  →  single BlockImage
        final onlyImage = _extractOnlyImage(node);
        if (onlyImage != null) {
          output.add(onlyImage);
          return;
        }

        // Normal paragraph
        final inlines = <Inline>[];
        _collectInlines(node, inlines);
        if (inlines.isNotEmpty) {
          output.add(TextBlock(inlines, lang: currentLang));
        }
        return;

      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final inlines = <Inline>[];
        _collectInlines(node, inlines);
        if (inlines.isNotEmpty) {
          final level = int.parse(tag.substring(1));
          output.add(
            TextBlock(inlines, lang: currentLang, headingLevel: level),
          );
        }
        return;

      case 'br':
        output.add(TextBlock([InlineText('\n')], lang: currentLang));
        return;

      default:
        // Transparent containers (div, section, figure, aside, li, td…)
        for (final child in node.nodes) {
          _walk(child, output, lang: currentLang);
        }
    }
  }

  // ── Helper: detect <p> that contains only an image ─────────
  BlockImage? _extractOnlyImage(dom.Element p) {
    // Collect meaningful children (ignore pure whitespace text nodes)
    final meaningful = p.nodes.where((n) {
      if (n is dom.Text) return n.text.trim().isNotEmpty;
      return n is dom.Element;
    }).toList();

    if (meaningful.length != 1) return null;

    final child = meaningful.first;
    if (child is! dom.Element) return null;

    final tag = child.localName?.toLowerCase();
    if (tag != 'img' && tag != 'image') return null;

    final src = _imageSrc(child);
    if (src.isEmpty) return null;

    return BlockImage(
      resolve(src),
      alt: child.attributes['alt'],
      id: child.attributes['id'],
      epubType: child.attributes['epub:type'] ?? p.attributes['epub:type'],
    );
  }

  // ── Nested lists ──────────────────────────────────────────

  BlockList _extractList(
    dom.Element listEl, {
    required bool ordered,
    required String lang,
  }) {
    final items = <ListItem>[];

    for (final child in listEl.children) {
      if (child.localName?.toLowerCase() != 'li') continue;

      final itemContent = <Chunk>[];
      _walk(child, itemContent, lang: lang);
      items.add(ListItem(itemContent));
    }

    return BlockList(items, ordered: ordered);
  }

  // ── Tables with colspan / rowspan ─────────────────────────

  Table _extractTable(dom.Element tableEl, {required String lang}) {
    final rows = <TableRow>[];
    final trs = tableEl.querySelectorAll('tr');

    for (final tr in trs) {
      final isHeader =
          tr.querySelector('th') != null ||
          tr.parent?.localName?.toLowerCase() == 'thead';

      final cells = <TableCell>[];

      for (final cellEl in tr.children) {
        final cellTag = cellEl.localName?.toLowerCase();
        if (cellTag != 'td' && cellTag != 'th') continue;

        final content = <Chunk>[];
        _walk(cellEl, content, lang: lang);

        cells.add(
          TableCell(
            content,
            colspan: int.tryParse(cellEl.attributes['colspan'] ?? '') ?? 1,
            rowspan: int.tryParse(cellEl.attributes['rowspan'] ?? '') ?? 1,
          ),
        );
      }

      if (cells.isNotEmpty) {
        rows.add(TableRow(cells, isHeader: isHeader));
      }
    }

    return Table(rows);
  }

  // ── Rich inline collection ────────────────────────────────

  void _collectInlines(
    dom.Node node,
    List<Inline> output, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool superscript = false,
    bool subscript = false,
  }) {
    if (node is dom.Text) {
      if (node.text.isNotEmpty) {
        output.add(
          InlineText(
            _normalize(node.text),
            bold: bold,
            italic: italic,
            underline: underline,
            superscript: superscript,
            subscript: subscript,
          ),
        );
      }
      return;
    }

    if (node is! dom.Element) return;

    final tag = node.localName?.toLowerCase() ?? '';
    if (_isIgnorable(tag)) return;

    final nextBold = bold || tag == 'strong' || tag == 'b';
    final nextItalic = italic || tag == 'em' || tag == 'i';
    final nextUnderline = underline || tag == 'u';
    final nextSup = superscript || tag == 'sup';
    final nextSub = subscript || tag == 'sub';

    if (tag == 'img' || tag == 'image') {
      final src = _imageSrc(node);
      if (src.isNotEmpty) {
        output.add(InlineImage(resolve(src), alt: node.attributes['alt']));
      }
      return;
    }

    if (tag == 'a') {
      final href = node.attributes['href'] ?? '';
      final id = node.attributes['id'] ?? node.attributes['name'];
      final epubType = node.attributes['epub:type'];

      if (href.isNotEmpty) {
        final children = <Inline>[];
        for (final c in node.nodes) {
          _collectInlines(
            c,
            children,
            bold: nextBold,
            italic: nextItalic,
            underline: nextUnderline,
            superscript: nextSup,
            subscript: nextSub,
          );
        }
        output.add(Hyperlink(href, epubType: epubType, children: children));
      } else if (id != null && id.isNotEmpty) {
        output.add(Anchor(id));
        for (final c in node.nodes) {
          _collectInlines(
            c,
            output,
            bold: nextBold,
            italic: nextItalic,
            underline: nextUnderline,
            superscript: nextSup,
            subscript: nextSub,
          );
        }
      } else {
        for (final c in node.nodes) {
          _collectInlines(
            c,
            output,
            bold: nextBold,
            italic: nextItalic,
            underline: nextUnderline,
            superscript: nextSup,
            subscript: nextSub,
          );
        }
      }
      return;
    }

    if (tag == 'br') {
      output.add(InlineText('\n', bold: bold, italic: italic));
      return;
    }

    for (final child in node.nodes) {
      _collectInlines(
        child,
        output,
        bold: nextBold,
        italic: nextItalic,
        underline: nextUnderline,
        superscript: nextSup,
        subscript: nextSub,
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────

  String _imageSrc(dom.Element node) =>
      node.attributes['src'] ??
      node.attributes['xlink:href'] ??
      node.attributes['href'] ??
      '';

  String _langOf(dom.Element node, String fallback) =>
      node.attributes['xml:lang'] ?? node.attributes['lang'] ?? fallback;

  String _normalize(String s) => s
      .replaceAll(RegExp(r'\s+'), ' ')
      // remove \r\n
      .replaceAll(RegExp(r'\r?\n'), '')
      .trim();

  bool _isIgnorable(String tag) {
    const ignore = {
      'script',
      'style',
      'link',
      'meta',
      'title',
      'head',
      'noscript',
      'template',
    };
    return ignore.contains(tag);
  }
}

abstract class Chapter {
  String get title;
  List<Chunk> get chunks;
  String get text;
  String get href;

  factory Chapter.from(String href, ArchiveFile file) {
    return ChapterStub._(href: href, file: file);
  }

  factory Chapter.cache({
    required String title,
    required String href,
    required List<Chunk> chunks,
  }) {
    return ChapterStub.cache(href: href, title: title, chunks: chunks);
  }
}

class ChapterStub implements Chapter {
  ChapterStub._({required this.href, required this.file});
  // ChapterStub.fromArchive({required this.href, this.file});

  ChapterStub.cache({
    required this.href,
    required String title,
    required List<Chunk> chunks,
  }) : _title = title,
       _chunks = chunks,
       file = ArchiveFile.noData('stub');

  @override
  final String href;

  @override
  String get title {
    if (_title == null) {
      _parse();
    }
    return _title ?? '';
  }

  @override
  List<Chunk> get chunks {
    if (_chunks == null) {
      _parse();
    }
    return _chunks!;
  }

  String? _title;
  List<Chunk>? _chunks;

  void _parse() {
    final html = utf8.decode(file.content);
    final dom = parse(html);

    /// title
    String? title;
    for (final selector in ['title', 'h1', 'h2', 'h3']) {
      final text = dom.querySelector(selector)?.text.trim();
      if (text != null &&
          text.isNotEmpty &&
          !{'未知', 'Unknown'}.contains(text)) {
        title = text;
        break;
      }
    }
    _title = title;

    /// chunks
    final chs = HtmlExtractor(href).extract(dom.body!);
    _chunks = chs;
  }

  final ArchiveFile file;

  @override
  String get text => chunks.join('\n');

  // List<String> get texts => lines.map((l) => l.text).toList();

  Chapter copyWith(String? title, String? href, List<Chunk>? chunks) {
    return ChapterStub.cache(
      href: href ?? this.href,
      title: title ?? this.title,
      chunks: chunks ?? this.chunks,
    );
  }
}

class Book {
  const Book({
    required this.title,
    required this.author,
    this.language,
    required this.chapters,
    this.files = const <String, ArchiveFile>{},
  });

  final String title;
  final String author;
  final String? language;
  final List<Chapter> chapters;
  final Map<String, ArchiveFile> files;

  int get sentenceCount =>
      chapters.fold(0, (sum, chapter) => sum + chapter.chunks.length);
}

class DrmEpubException implements Exception {
  const DrmEpubException();

  @override
  String toString() =>
      'EPUB is encrypted or DRM-protected and cannot be opened.';
}

class EpubParseException implements Exception {
  const EpubParseException(this.message);
  final String message;

  @override
  String toString() => message;
}

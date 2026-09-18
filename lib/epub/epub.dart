import 'package:html/dom.dart' as dom;

// ─────────────────────────────────────────────────────────────
// Content Model (short names)
// ─────────────────────────────────────────────────────────────

sealed class Chunk {}

class TextBlock extends Chunk {
  final String lang;
  final List<Inline> inlines;
  final int? headingLevel; // 1–6 for <h1>–<h6>, null = normal <p>

  TextBlock(this.inlines, {this.lang = '', this.headingLevel});

  @override
  String toString() =>
      'TextBlock(level: $headingLevel, inlines: ${inlines.length})';
}

class BlockImage extends Chunk {
  final String src;
  final String? alt;
  final String? id;

  BlockImage(this.src, {this.alt, this.id});

  @override
  String toString() => 'BlockImage("$src")';
}

class ListBlock extends Chunk {
  final bool ordered;
  final List<ListItem> items;

  ListBlock(this.items, {this.ordered = false});

  @override
  String toString() => 'ListBlock(ordered: $ordered, items: ${items.length})';
}

class ListItem {
  final List<Chunk> content;

  ListItem(this.content);
}

class Table extends Chunk {
  final List<TableRow> rows;

  Table(this.rows);

  @override
  String toString() => 'Table(rows: ${rows.length})';
}

class TableRow {
  final List<TableCell> cells;
  final bool isHeader;

  TableRow(this.cells, {this.isHeader = false});
}

class TableCell {
  final List<Chunk> content;
  final int colspan;
  final int rowspan;

  TableCell(this.content, {this.colspan = 1, this.rowspan = 1});
}

class MathBlock extends Chunk {
  final String content;
  final bool display;

  MathBlock(this.content, {this.display = true});
}

class UnknownBlock extends Chunk {
  final String tag;

  UnknownBlock(this.tag);
}

// ─────────────────────────────────────────────────────────────
// Inline content
// ─────────────────────────────────────────────────────────────

sealed class Inline {}

class TextSpan extends Inline {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool superscript;
  final bool subscript;

  TextSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.superscript = false,
    this.subscript = false,
  });

  @override
  String toString() {
    final styles = [
      if (bold) 'b',
      if (italic) 'i',
      if (underline) 'u',
      if (superscript) 'sup',
      if (subscript) 'sub',
    ];
    return 'TextSpan("$text"${styles.isNotEmpty ? ' [${styles.join(',')}]' : ''})';
  }
}

class InlineImage extends Inline {
  final String src;
  final String? alt;

  InlineImage(this.src, {this.alt});
}

class Hyperlink extends Inline {
  final String href;
  final String? epubType;
  final List<Inline> children;

  Hyperlink(this.href, {this.epubType, this.children = const []});

  @override
  String toString() => 'Hyperlink($href)';
}

class Anchor extends Inline {
  final String id;
  Anchor(this.id);
}

class MathInline extends Inline {
  final String content;
  MathInline(this.content);
}

// ─────────────────────────────────────────────────────────────
// Extractor
// ─────────────────────────────────────────────────────────────

class HtmlExtractor {
  List<Chunk> extract(dom.Node root) {
    final result = <Chunk>[];
    _walk(root, result, lang: '');
    return result;
  }

  void _walk(dom.Node node, List<Chunk> output, {required String lang}) {
    if (node is dom.Text) {
      final text = _normalize(node.text);
      if (text.isNotEmpty) {
        output.add(TextBlock([TextSpan(text)], lang: lang));
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
              src,
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
        output.add(TextBlock([TextSpan('\n')], lang: currentLang));
        return;

      default:
        for (final child in node.nodes) {
          _walk(child, output, lang: currentLang);
        }
    }
  }

  // ── Nested lists ──────────────────────────────────────────

  ListBlock _extractList(
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

    return ListBlock(items, ordered: ordered);
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
          TextSpan(
            node.text,
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
        output.add(InlineImage(src, alt: node.attributes['alt']));
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
      output.add(TextSpan('\n', bold: bold, italic: italic));
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

  String _normalize(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

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

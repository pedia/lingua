import 'dart:convert';
import 'dart:typed_data';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:archive/archive.dart';
import 'package:lingua/epub/lang.dart';

/// text only for paragraph
class Chunk {
  Chunk(this.text, {this.lang = Lang.unknown});
  final String text;

  /// hardcode: en, zh, es, jp, kr
  final Lang lang;
  @override
  String toString() => '$lang: $text';
}

abstract class Chapter {
  String get title;
  List<Chunk> get chunks;
  String get href;
  String get content;

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
      _parse(title: true);
    }
    return _title ?? '';
  }

  @override
  List<Chunk> get chunks {
    if (_chunks == null) {
      _parse(body: true);
    }
    return _chunks!;
  }

  @override
  String get content => file.name == 'stub' && _chunks != null
      ? toHtml()
      : utf8.decode(file.content);

  String? _title;
  List<Chunk>? _chunks;

  /// chunks to html
  String toHtml() {
    final buf = StringBuffer();
    buf.writeln('<title>${_esc(title)}</title>');
    buf.writeln('<body>');
    _chunks?.forEach((c) => buf.writeln('<p>${_esc(c.text)}</p>'));
    buf.writeln('</body>');
    return buf.toString();
  }

  String _esc(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  void _parse({bool title = false, bool body = false}) {
    final html = utf8.decode(file.content);
    final dom = parse(html);

    if (_title == null && title) {
      for (final selector in ['title', 'h1', 'h2', 'h3']) {
        final text = dom.querySelector(selector)?.text.trim();
        if (text != null && text.isNotEmpty) {
          if ({'未知', 'Unknown'}.contains(text)) {
            continue;
          }
          if (text.contains('<link')) {
            continue;
          }
          _title = text;
          break;
        }
      }

      // fallback, use first line as title
      if (_title == null) {
        final arr = dom.body?.text.split('\n');
        if (arr != null) {
          _title = arr.where((line) => line.trim().isNotEmpty).firstOrNull;
          if (_title != null && _title!.length > 100) {
            _title = _title!.substring(0, 8);
          }
        }
      }
      // fallback, as href
      _title ??= href;
    }

    if (_chunks == null && body) {
      /// parse text/chunks from dom
      _chunks = extract(dom);
    }
  }

  final ArchiveFile file;

  Chapter copyWith(String? title, String? href, List<Chunk>? chunks) {
    return ChapterStub.cache(
      href: href ?? this.href,
      title: title ?? this.title,
      chunks: chunks ?? this.chunks,
    );
  }

  /// Extracts readable text chunks from an EPUB HTML/XHTML page.
  ///
  /// Focuses on paragraph-level content (`<p>` elements). Each chunk
  /// contains the concatenated text of the paragraph and the effective
  /// language (from the element's own `lang`/`xml:lang` attribute or the
  /// nearest ancestor that declares one). Empty paragraphs are skipped.
  List<Chunk> extract(dom.Document dom) {
    final chunks = <Chunk>[];

    // Prefer the body if present; otherwise start from the document root.
    final root = dom.body ?? dom.documentElement ?? dom;

    for (final p in root.querySelectorAll('h1, h2, h3, h4, h5, p')) {
      final text = p.text.trim();
      if (text.isEmpty) continue;

      final lang = _effectiveLang(p);
      print('add $lang ${Chunk(text, lang: lang)}');
      chunks.add(Chunk(text, lang: lang));
    }

    return chunks;
  }

  Lang _effectiveLang(dom.Element e) {
    final lang = _elementLang(e);
    if (lang != Lang.unknown) return lang;
    return detectLang(e.text);
  }

  Lang _elementLang(dom.Element e) {
    // Prefer the explicit HTML lang attribute.
    final lang = e.attributes['lang']?.trim();
    if (lang != null) return Lang.from(lang);

    // Fall back to the XML namespace form commonly used in EPUB/XHTML.
    final xmlLang = e.attributes['xml:lang']?.trim();
    if (xmlLang != null) return Lang.from(xmlLang);

    // only trust tag p's lang
    // dom.Element? p = e;
    // while (p != null && p.localName != 'p') {
    //   p = p.parent;
    // }
    return Lang.unknown;
  }
}

class Book {
  const Book({
    required this.title,
    required this.author,
    required this.description,
    this.language,
    required this.chapters,
    this.files = const <String, ArchiveFile>{},
    this.cover,
  });

  final String title;
  final String author;
  final String description;
  final String? language;
  final List<Chapter> chapters;
  final Map<String, ArchiveFile> files;
  final String? cover;

  factory Book.empty() =>
      Book(title: '', author: '', description: '', chapters: []);

  Uint8List? get coverBytes {
    if (cover != null) {
      return files[cover]?.content;
    }
    return null;
  }

  int get sentenceCount =>
      chapters.fold(0, (sum, chapter) => sum + chapter.chunks.length);

  @override
  String toString() => 'Book($title, $author)';
}

class DRMException implements Exception {
  const DRMException();

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

/// only used in frya
List<Chunk> md2ch(String md) {
  final rs = <Chunk>[];
  for (final line in md.split('\n')) {
    final s = line.trim();
    if (s.isNotEmpty) rs.add(Chunk(line, lang: Lang.zh));
  }
  return rs;
}

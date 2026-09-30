import 'dart:convert';
import 'dart:typed_data';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:archive/archive.dart';

/// text only for paragraph
class Chunk {
  Chunk(this.text, {this.lang = ''});
  final String text;

  /// hardcode: en, zh, es, jp, kr
  final String lang;
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
      _parse(onlyTitle: true);
    }
    return _title ?? '';
  }

  @override
  List<Chunk> get chunks {
    if (_chunks == null) {
      _parse(onlyTitle: false);
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

  void _parse({bool onlyTitle = true}) {
    final html = utf8.decode(file.content);
    final dom = parse(html);

    if (_title == null) {
      for (final selector in ['title', 'h1', 'h2', 'h3']) {
        final text = dom.querySelector(selector)?.text.trim();
        if (text != null &&
            text.isNotEmpty &&
            !{'未知', 'Unknown'}.contains(text)) {
          _title = text;
          break;
        }
      }
    }

    if (!onlyTitle && _chunks == null) {
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

    for (final p in root.querySelectorAll('p')) {
      final text = p.text.trim();
      if (text.isEmpty) continue;

      final lang = _effectiveLang(p);
      chunks.add(Chunk(text, lang: lang));
    }

    return chunks;
  }

  /// Returns the effective language for [element] by walking up the
  /// ancestor chain. Looks for both the HTML `lang` attribute and the
  /// XHTML `xml:lang` attribute. Returns an empty string when none is found.
  String _effectiveLang(dom.Element element) {
    dom.Element? current = element;
    while (current != null) {
      // Prefer the explicit HTML lang attribute.
      final lang = current.attributes['lang']?.trim();
      if (lang != null && lang.isNotEmpty) return lang;

      // Fall back to the XML namespace form commonly used in EPUB/XHTML.
      final xmlLang = current.attributes['xml:lang']?.trim();
      if (xmlLang != null && xmlLang.isNotEmpty) return xmlLang;

      current = current.parent;
    }
    return '';
  }
}

class Book {
  const Book({
    required this.title,
    required this.author,
    this.language,
    required this.chapters,
    this.files = const <String, ArchiveFile>{},
    this.cover,
  });

  final String title;
  final String author;
  final String? language;
  final List<Chapter> chapters;
  final Map<String, ArchiveFile> files;
  final String? cover;

  factory Book.empty() => Book(title: '', author: '', chapters: []);

  Uint8List? get coverBytes {
    if (cover != null) {
      return files[cover]?.content;
    }
    return null;
  }

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

/// Core chunk models and parser for EPUB, MOBI, AZW, AZW3, and HTML/XHTML.
library chunk;

import 'dart:io';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as dom;
import 'epub.dart';
import 'mobi.dart';

export 'epub.dart';
export 'mobi.dart';

/// ignore all html text format
class Span {
  Span(this.text);
  final String text;

  @override
  String toString() => 'Span($text)';
}

/// An inline anchor (`<a>`) carrying resolved footnote [note] and/or [link] target.
class Anchor extends Span {
  Anchor(super.text, {this.note, this.link});
  final String? note;
  final String? link;

  @override
  String toString() =>
      'Anchor($text${link != null ? ", link: $link" : ""}${note != null ? ", note: $note" : ""})';
}

enum Lang {
  unknown,
  all,
  en,
  es,
  jp,
  kr,
  zh;

  static Lang from(String? s) => switch (s) {
    'en' => en,
    'es' => es,
    'jp' => jp,
    'kr' => kr,
    'zh' => zh,
    '' => all,
    _ => unknown, // null
  };
}

/// Contains text or Span(s)
class Chunk {
  Chunk({
    this.id,
    this.idx = 0,
    this.spans = const <Span>[],
    this.text,
    this.lang = Lang.unknown,
    this.strong = false,
  });
  final String? id;
  final int idx;
  final Lang lang;
  final List<Span> spans;
  final String? text;
  final bool strong;

  @override
  String toString() =>
      'Chunk(${lang.name}${strong ? ", strong" : ""}${id != null ? ", #$id" : ""}: ${text ?? spans})';

  Chunk copyWith({
    String? id,
    int? idx,
    Lang? lang,
    List<Span>? spans,
    String? text,
    bool? strong,
  }) => Chunk(
    id: id ?? this.id,
    idx: idx ?? this.idx,
    lang: lang ?? this.lang,
    spans: spans ?? this.spans,
    text: text ?? this.text,
    strong: strong ?? this.strong,
  );
}

class Picture extends Chunk {
  Picture(this.src, {this.alt, this.w, this.h, super.id});
  final String src;
  final String? alt;
  double? w, h;

  @override
  String toString() => 'Picture($src${alt != null ? ", alt: $alt" : ""})';
}

abstract class Chapter {
  Chapter(this.title);
  final String title;
  List<Chunk> get chunks;
}

class LazyChapter extends Chapter {
  LazyChapter(super.title, this._loader);

  final List<Chunk> Function() _loader;
  List<Chunk>? _cached;

  @override
  List<Chunk> get chunks => _cached ??= _loader();
}

class Book {
  Book({
    required this.title,
    this.author,
    this.description,
    this.chapters = const [],
  });
  final String title;
  final String? author;
  final String? description;
  final List<Chapter> chapters;
}

/// Shared HTML/XHTML chunk parser used by EPUB and MOBI/AZW/AZW3 readers.
class HtmlChunkParser {
  static final RegExp _hangul = RegExp(r'[\uac00-\ud7af\u1100-\u11ff]');
  static final RegExp _kana = RegExp(r'[\u3040-\u309f\u30a0-\u30ff]');
  static final RegExp _cjk = RegExp(r'[\u4e00-\u9fff]');
  static final RegExp _spanish = RegExp(r'[¡¿áéíóúüñÁÉÍÓÚÜÑ]');
  static final RegExp _latin = RegExp(r'[a-zA-Z]');

  static const Set<String> _blocks = {
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'aside',
    'blockquote',
  };

  /// Extract footnote definitions (`<aside epub:type="footnote">` / `.duokan-footnote-item`).
  static Map<String, String> extractFootnotes(String html) {
    return _extractFootnotesFromDoc(dom.parseFragment(html));
  }

  /// Extract first heading or `<title>` for a chapter, falling back to [fallback].
  static String extractChapterTitle(String html, String fallback) {
    final doc = dom.parseFragment(html);
    for (final selector in ['h1', 'h2', 'h3', 'title']) {
      final text = doc
          .querySelector(selector)
          ?.text
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return fallback;
  }

  /// Parse an HTML / XHTML fragment into [Chunk]s ([Chunk], [Picture]).
  static List<Chunk> parseHtml(
    String html, {
    Lang defaultLang = Lang.unknown,
    Map<String, String> footnotes = const {},
    String Function(String recindex)? resolveRecindex,
  }) {
    final doc = dom.parseFragment(html);
    final fnMap = <String, String>{
      ...footnotes,
      ..._extractFootnotesFromDoc(doc),
    };
    final chunks = <Chunk>[];

    void process(dom.Node node, Lang inheritedLang) {
      if (node is! dom.Element) return;

      final tag = node.localName?.toLowerCase() ?? '';
      if (tag == 'script' || tag == 'style') return;
      if (_isFootnoteContainer(node, tag)) return;

      final lang = _detectLang(
        node.classes.toList(),
        node.attributes,
        node.text,
        inheritedLang,
      );

      if (tag == 'img' || tag == 'image') {
        if (!_isFootnoteImg(node)) {
          final img = _buildImage(node, resolveRecindex);
          if (img != null) chunks.add(img);
        }
        return;
      }

      if (_blocks.contains(tag) || tag == 'strong') {
        final hasChildBlocks =
            tag != 'aside' &&
            tag != 'strong' &&
            node.children.any(
              (c) => _blocks.contains(c.localName?.toLowerCase()),
            );

        if (hasChildBlocks) {
          for (final child in node.children) {
            process(child, lang);
          }
          return;
        }

        final id = _getId(node);
        final strong =
            _isHeading(tag) || tag == 'strong' || _allContentInStrong(node);
        final spans = _extractSpans(node, fnMap);
        final hasAnchor = spans.any((s) => s is Anchor);

        if (spans.isNotEmpty) {
          var resolvedLang = lang;
          final plainText = spans.map((s) => s.text).join().trim();
          if (plainText.isEmpty) {
            final notes = spans
                .whereType<Anchor>()
                .map((a) => a.note)
                .nonNulls
                .join(' ');
            if (notes.isNotEmpty) {
              resolvedLang = _detectLang(
                node.classes.toList(),
                node.attributes,
                notes,
                inheritedLang,
              );
            }
          }

          if (hasAnchor) {
            chunks.add(
              Chunk(id: id, spans: spans, lang: resolvedLang, strong: strong),
            );
          } else {
            chunks.add(
              Chunk(
                id: id,
                text: spans.first.text,
                lang: resolvedLang,
                strong: strong,
              ),
            );
          }
        }

        for (final imgEl in node.querySelectorAll('img, image')) {
          if (!_isFootnoteImg(imgEl) && !_isInsideFootnoteAnchor(imgEl)) {
            final img = _buildImage(imgEl, resolveRecindex);
            if (img != null) chunks.add(img);
          }
        }
        return;
      }

      for (final child in node.children) {
        process(child, lang);
      }
    }

    for (final child in doc.children) {
      process(child, defaultLang);
    }
    return chunks;
  }

  // --- Helpers ---

  static bool _isHeading(String tag) =>
      tag.length == 2 && tag.startsWith('h') && int.tryParse(tag[1]) != null;

  static bool _allContentInStrong(dom.Element root) {
    if (root.querySelector('strong') == null) return false;
    bool hasAnyText = false;

    bool check(dom.Node node, bool inStrong) {
      if (node is dom.Text) {
        if (node.text.trim().isNotEmpty) {
          hasAnyText = true;
          if (!inStrong) return false;
        }
        return true;
      }
      if (node is! dom.Element) return true;
      final tag = node.localName?.toLowerCase() ?? '';
      if (tag == 'script' || tag == 'style') return true;
      final nextStrong = inStrong || tag == 'strong';
      for (final child in node.nodes) {
        if (!check(child, nextStrong)) return false;
      }
      return true;
    }

    return check(root, false) && hasAnyText;
  }

  static Map<String, String> _extractFootnotesFromDoc(
    dom.DocumentFragment doc,
  ) {
    final map = <String, String>{};
    for (final el in doc.querySelectorAll('aside, .duokan-footnote-item')) {
      final tag = el.localName?.toLowerCase() ?? '';
      if (!_isFootnoteContainer(el, tag)) continue;
      if (el.id.isNotEmpty) {
        final text = el.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.isNotEmpty) map[el.id] = text;
      }
    }
    return map;
  }

  static bool _isFootnoteContainer(dom.Element el, String tag) {
    if (tag == 'aside') {
      return el.attributes['epub:type'] == 'footnote' ||
          el.querySelector('.duokan-footnote-content, .duokan-footnote-item') !=
              null ||
          el.id.contains('footnote');
    }
    return el.classes.contains('duokan-footnote-item') && el.id.isNotEmpty;
  }

  static List<Span> _extractSpans(
    dom.Element root,
    Map<String, String> footnotes,
  ) {
    final spans = <Span>[];

    void addPlain(String raw) {
      final norm = raw.replaceAll(RegExp(r'\s+'), ' ');
      if (norm.isEmpty) return;
      if (spans.isNotEmpty && spans.last is! Anchor) {
        final merged = '${spans.last.text}$norm'.replaceAll(
          RegExp(r' {2,}'),
          ' ',
        );
        spans[spans.length - 1] = Span(merged);
        return;
      }
      spans.add(Span(norm));
    }

    void walk(dom.Node node) {
      if (node is dom.Text) {
        addPlain(node.text);
        return;
      }
      if (node is! dom.Element) return;

      final tag = node.localName?.toLowerCase() ?? '';
      if (tag == 'script' || tag == 'style') return;
      if (tag == 'br') {
        addPlain(' ');
        return;
      }
      if (tag == 'img' || tag == 'image') {
        final fn = _extractImgFootnote(node);
        if (fn != null) spans.add(Anchor('', note: fn));
        return;
      }
      if (tag == 'a') {
        final href = node.attributes['href']?.trim() ?? '';
        final linkText = node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        final hashIdx = href.indexOf('#');
        final targetId = hashIdx >= 0 ? href.substring(hashIdx + 1) : href;
        final resolvedFn = targetId.isNotEmpty ? footnotes[targetId] : null;
        final isFnRef = resolvedFn != null || _isFootnoteAnchor(node, href);

        String? note = resolvedFn;
        if (note == null && isFnRef) {
          note = _extractImgFootnoteFromTree(node);
        }

        if (href.isNotEmpty || note != null) {
          spans.add(
            Anchor(linkText, note: note, link: href.isNotEmpty ? href : null),
          );
          return;
        }
      }

      for (final child in node.nodes) {
        walk(child);
      }
    }

    for (final child in root.nodes) {
      walk(child);
    }

    while (spans.isNotEmpty && spans.first is! Anchor) {
      final trimmed = spans.first.text.trimLeft();
      if (trimmed.isEmpty) {
        spans.removeAt(0);
      } else {
        spans[0] = Span(trimmed);
        break;
      }
    }

    while (spans.isNotEmpty && spans.last is! Anchor) {
      final trimmed = spans.last.text.trimRight();
      if (trimmed.isEmpty) {
        spans.removeLast();
      } else {
        spans[spans.length - 1] = Span(trimmed);
        break;
      }
    }

    int lastTextIdx = spans.length - 1;
    while (lastTextIdx >= 0 &&
        spans[lastTextIdx] is Anchor &&
        spans[lastTextIdx].text.isEmpty) {
      lastTextIdx--;
    }
    while (lastTextIdx >= 0 && spans[lastTextIdx] is! Anchor) {
      final trimmed = spans[lastTextIdx].text.trimRight();
      if (trimmed.isEmpty) {
        spans.removeAt(lastTextIdx);
        lastTextIdx--;
      } else {
        spans[lastTextIdx] = Span(trimmed);
        break;
      }
    }

    return spans;
  }

  static bool _isFootnoteAnchor(dom.Element a, String href) {
    if (a.attributes['epub:type'] == 'noteref') return true;
    if (href.contains('footnote')) return true;
    for (final img in a.querySelectorAll('img')) {
      if (_isFootnoteImg(img)) return true;
    }
    return false;
  }

  static bool _isFootnoteImg(dom.Element img) {
    if (img.classes.contains('epub-footnote')) return true;
    final zy = img.attributes['zy-footnote']?.trim();
    if (zy != null && zy.isNotEmpty) return true;
    final alt = img.attributes['alt']?.trim();
    return alt != null && alt.length > 40 && _isInsideFootnoteAnchor(img);
  }

  static bool _isInsideFootnoteAnchor(dom.Element el) {
    dom.Element? parent = el.parent;
    while (parent != null) {
      if (parent.localName?.toLowerCase() == 'a') {
        final href = parent.attributes['href'] ?? '';
        return parent.attributes['epub:type'] == 'noteref' ||
            href.contains('footnote');
      }
      parent = parent.parent;
    }
    return false;
  }

  static String? _extractImgFootnote(dom.Element img) {
    final zy = img.attributes['zy-footnote']?.trim();
    if (zy != null && zy.isNotEmpty) return zy;
    if (_isFootnoteImg(img)) {
      final alt = img.attributes['alt']?.trim();
      if (alt != null && alt.isNotEmpty) return alt;
    }
    return null;
  }

  static String? _extractImgFootnoteFromTree(dom.Element el) {
    for (final img in el.querySelectorAll('img')) {
      final zy = img.attributes['zy-footnote']?.trim();
      if (zy != null && zy.isNotEmpty) return zy;
      final alt = img.attributes['alt']?.trim();
      if (alt != null && alt.isNotEmpty) return alt;
    }
    return null;
  }

  static Lang _langFromCode(String? code) {
    if (code == null) return Lang.unknown;
    final c = code.trim().toLowerCase();
    for (final v in Lang.values) {
      if (v.name == c) return v;
    }
    if (c.startsWith('zh') || c.contains('chinese')) return Lang.zh;
    if (c.startsWith('en')) return Lang.en;
    if (c.startsWith('es') || c.contains('spanish')) return Lang.es;
    if (c.startsWith('ja') || c.startsWith('jp')) return Lang.jp;
    if (c.startsWith('ko') || c.startsWith('kr')) return Lang.kr;
    if (c == 'all' || c == 'mul') return Lang.all;
    return Lang.unknown;
  }

  static Lang _detectLang(
    List<String> classes,
    Map<dynamic, String> attrs,
    String text,
    Lang fallback,
  ) {
    for (final cls in classes) {
      final l = _langFromCode(cls);
      if (l != Lang.unknown) return l;
    }
    final attrLang = attrs['lang'] ?? attrs['xml:lang'];
    if (attrLang != null) {
      final l = _langFromCode(attrLang);
      if (l != Lang.unknown) return l;
    }
    return _detectFromText(text.trim(), fallback);
  }

  static Lang _detectFromText(String text, Lang fallback) {
    if (text.isEmpty) return fallback;
    if (_hangul.hasMatch(text)) return Lang.kr;
    if (_kana.hasMatch(text)) return Lang.jp;
    if (_cjk.hasMatch(text)) {
      if (_latin.hasMatch(text) && text.length > 25) return Lang.all;
      return Lang.zh;
    }
    if (_spanish.hasMatch(text)) return Lang.es;
    if (_latin.hasMatch(text)) return Lang.en;
    return fallback;
  }

  static String? _getId(dom.Element el) {
    if (el.id.isNotEmpty) return el.id;
    if (el.attributes.containsKey('name')) return el.attributes['name'];
    final a = el.querySelector('a[id], a[name]');
    if (a != null) return a.id.isNotEmpty ? a.id : a.attributes['name'];
    return null;
  }

  static String? _attr(dom.Element el, List<String> names) {
    for (final name in names) {
      final direct = el.attributes[name]?.trim();
      if (direct != null && direct.isNotEmpty) return direct;
    }
    for (final entry in el.attributes.entries) {
      final key = entry.key;
      final keyStr = key is dom.AttributeName
          ? (key.prefix != null && key.prefix!.isNotEmpty
                ? '${key.prefix}:${key.name}'
                : key.name)
          : key.toString();
      final lower = keyStr.toLowerCase();
      for (final name in names) {
        if (lower == name ||
            (key is dom.AttributeName && key.name.toLowerCase() == name)) {
          final val = entry.value.trim();
          if (val.isNotEmpty) return val;
        }
      }
    }
    return null;
  }

  static Picture? _buildImage(
    dom.Element img,
    String Function(String recindex)? resolveRecindex,
  ) {
    var src = _attr(img, ['src', 'xlink:href', 'href']);
    if (src == null || src.isEmpty) {
      final recindex = _attr(img, ['recindex']);
      if (recindex != null && resolveRecindex != null) {
        src = resolveRecindex(recindex);
      }
    }
    if (src == null || src.isEmpty) return null;

    final alt = _attr(img, ['alt', 'xlink:title', 'title']);
    double? w = _parseSize(_attr(img, ['width']));
    double? h = _parseSize(_attr(img, ['height']));

    if ((w == null || h == null) &&
        img.parent?.localName?.toLowerCase() == 'svg') {
      final svg = img.parent!;
      w ??= _parseSize(_attr(svg, ['width']));
      h ??= _parseSize(_attr(svg, ['height']));
      final viewBox = _attr(svg, ['viewbox']);
      if ((w == null || h == null) && viewBox != null) {
        final parts = viewBox
            .split(RegExp(r'[\s,]+'))
            .map(double.tryParse)
            .whereType<double>()
            .toList();
        if (parts.length == 4) {
          w ??= parts[2];
          h ??= parts[3];
        }
      }
    }

    final id =
        _getId(img) ??
        (img.parent?.localName?.toLowerCase() == 'svg'
            ? _getId(img.parent!)
            : null);

    return Picture(src, alt: alt, w: w, h: h, id: id);
  }

  static double? _parseSize(String? raw) {
    if (raw == null) return null;
    final clean = raw.trim().toLowerCase();
    if (clean.endsWith('%')) return null;
    return double.tryParse(clean.replaceAll('px', ''));
  }
}

/// Unified parser auto-detecting HTML, EPUB, MOBI, AZW, and AZW3 inputs.
class ChunkParser {
  static List<Chunk> parseHtml(
    String html, {
    Lang defaultLang = Lang.unknown,
    Map<String, String> footnotes = const {},
  }) => HtmlChunkParser.parseHtml(
    html,
    defaultLang: defaultLang,
    footnotes: footnotes,
  );

  static Book parseBytes(List<int> bytes) {
    if (MobiParser.isMobiBytes(bytes)) {
      return MobiParser.parseBytes(bytes);
    }
    return EpubParser.parseBytes(bytes);
  }

  static Future<Book> parseFile(String filePath) async {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.mobi') ||
        lower.endsWith('.azw') ||
        lower.endsWith('.azw3')) {
      return MobiParser.parseFile(filePath);
    }
    final bytes = await File(filePath).readAsBytes();
    return parseBytes(bytes);
  }
}

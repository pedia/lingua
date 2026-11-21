/// Core chunk models and parser for EPUB, MOBI, AZW, AZW3, and HTML/XHTML.
library chunk;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

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

  /// Parse a language code or class label (e.g. `'en'`, `'zh-TW'`, `'ja-JP'`) into [Lang].
  static Lang from(String? code) {
    if (code == null) return Lang.unknown;
    final c = code.trim().toLowerCase();
    if (c.isEmpty) return Lang.unknown;
    for (final v in Lang.values) {
      if (v.name == c) return v;
    }
    if (c.startsWith('zh-') ||
        c.startsWith('zh_') ||
        c == 'zho' ||
        c == 'chi' ||
        c.contains('chinese')) {
      return Lang.zh;
    }
    if (c.startsWith('en-') ||
        c.startsWith('en_') ||
        c == 'eng' ||
        c.contains('english')) {
      return Lang.en;
    }
    if (c.startsWith('es-') ||
        c.startsWith('es_') ||
        c == 'spa' ||
        c.contains('spanish')) {
      return Lang.es;
    }
    if (c == 'ja' ||
        c.startsWith('ja-') ||
        c.startsWith('ja_') ||
        c.startsWith('jp-') ||
        c.startsWith('jp_') ||
        c == 'jpn' ||
        c.contains('japanese')) {
      return Lang.jp;
    }
    if (c == 'ko' ||
        c.startsWith('ko-') ||
        c.startsWith('ko_') ||
        c.startsWith('kr-') ||
        c.startsWith('kr_') ||
        c == 'kor' ||
        c.contains('korean')) {
      return Lang.kr;
    }
    if (c == 'mul') return Lang.all;
    return Lang.unknown;
  }
}

/// Contains text or Span(s)
class Chunk {
  Chunk({
    this.idx = 0,
    this.id,
    this.spans = const <Span>[],
    this.text,
    this.lang = Lang.unknown,
    this.strong = false,
  });
  final int idx;
  final String? id;
  final Lang lang;
  final List<Span> spans;
  final String? text;
  final bool strong;

  Chunk copyWith({
    int? idx,
    String? id,
    List<Span>? spans,
    String? text,
    Lang? lang,
    bool? strong,
  }) =>
      Chunk(
        idx: idx ?? this.idx,
        id: id ?? this.id,
        spans: spans ?? this.spans,
        text: text ?? this.text,
        lang: lang ?? this.lang,
        strong: strong ?? this.strong,
      );

  @override
  String toString() =>
      'Chunk(#$idx, ${lang.name}${strong ? ", strong" : ""}${id != null ? ", id:$id" : ""}: ${text ?? spans})';
}

class Picture extends Chunk {
  Picture(
    this.src, {
    this.alt,
    this.w,
    this.h,
    super.idx,
    super.id,
    Uint8List? Function()? bytes,
  }) : _bytes = bytes;

  final String src;
  final String? alt;
  double? w, h;
  final Uint8List? Function()? _bytes;

  /// Load raw image bytes on demand from the backing archive (or inline data URI).
  Uint8List? bytes() => _bytes?.call();

  /// Update [w] and [h] before display in a UI view.
  ///
  /// - If [w] or [h] is provided, applies those values directly.
  /// - Otherwise, when either [w] or [h] is missing (or [force] is true),
  ///   reads intrinsic pixel dimensions from [bytes()] headers (PNG, JPEG, GIF,
  ///   WebP, BMP, SVG) and fills missing sides proportionally.
  /// - If [maxWidth] and/or [maxHeight] are specified, scales down
  ///   proportionally to fit within those bounds while preserving aspect ratio.
  ///
  /// Returns `true` if both [w] and [h] are positive numbers after updating.
  bool updateSize({
    double? w,
    double? h,
    double? maxWidth,
    double? maxHeight,
    bool force = false,
  }) {
    if (w != null) this.w = w;
    if (h != null) this.h = h;

    if (force || this.w == null || this.h == null) {
      final data = bytes();
      final intrinsic = data != null ? _readImageDimensions(data) : null;
      if (intrinsic != null && intrinsic.w > 0 && intrinsic.h > 0) {
        if (force) {
          this.w = w ?? intrinsic.w;
          this.h = h ?? intrinsic.h;
        } else if (this.w == null && this.h == null) {
          this.w = intrinsic.w;
          this.h = intrinsic.h;
        } else if (this.w != null && this.h == null) {
          this.h = this.w! * (intrinsic.h / intrinsic.w);
        } else if (this.h != null && this.w == null) {
          this.w = this.h! * (intrinsic.w / intrinsic.h);
        }
      }
    }

    var cw = this.w;
    var ch = this.h;
    if (cw != null && ch != null && cw > 0 && ch > 0) {
      if (maxWidth != null && maxWidth > 0 && cw > maxWidth) {
        final ratio = maxWidth / cw;
        cw = maxWidth;
        ch = ch * ratio;
      }
      if (maxHeight != null && maxHeight > 0 && ch > maxHeight) {
        final ratio = maxHeight / ch;
        ch = maxHeight;
        cw = cw * ratio;
      }
      this.w = cw;
      this.h = ch;
      return true;
    }
    return false;
  }

  static ({double w, double h})? _readImageDimensions(Uint8List data) {
    final len = data.length;
    if (len < 10) return null;

    // PNG: 8-byte signature + IHDR width/height at offsets 16..24 (big-endian)
    if (len >= 24 &&
        data[0] == 0x89 &&
        data[1] == 0x50 &&
        data[2] == 0x4E &&
        data[3] == 0x47 &&
        data[4] == 0x0D &&
        data[5] == 0x0A &&
        data[6] == 0x1A &&
        data[7] == 0x0A) {
      final bd = ByteData.sublistView(data);
      final w = bd.getUint32(16, Endian.big).toDouble();
      final h = bd.getUint32(20, Endian.big).toDouble();
      return (w > 0 && h > 0) ? (w: w, h: h) : null;
    }

    // GIF87a / GIF89a: width/height at offsets 6..10 (little-endian)
    if (len >= 10 &&
        data[0] == 0x47 &&
        data[1] == 0x49 &&
        data[2] == 0x46 &&
        data[3] == 0x38) {
      final bd = ByteData.sublistView(data);
      final w = bd.getUint16(6, Endian.little).toDouble();
      final h = bd.getUint16(8, Endian.little).toDouble();
      return (w > 0 && h > 0) ? (w: w, h: h) : null;
    }

    // BMP: 'BM' + DIB header at 14
    if (len >= 26 && data[0] == 0x42 && data[1] == 0x4D) {
      final bd = ByteData.sublistView(data);
      final dibSize = bd.getUint32(14, Endian.little);
      if (dibSize == 12) {
        final w = bd.getUint16(18, Endian.little).toDouble();
        final h = bd.getUint16(20, Endian.little).toDouble();
        return (w > 0 && h > 0) ? (w: w, h: h) : null;
      }
      final w = bd.getInt32(18, Endian.little).abs().toDouble();
      final h = bd.getInt32(22, Endian.little).abs().toDouble();
      return (w > 0 && h > 0) ? (w: w, h: h) : null;
    }

    // WebP: RIFF....WEBP
    if (len >= 25 &&
        data[0] == 0x52 &&
        data[1] == 0x49 &&
        data[2] == 0x46 &&
        data[3] == 0x46 &&
        data[8] == 0x57 &&
        data[9] == 0x45 &&
        data[10] == 0x42 &&
        data[11] == 0x50) {
      final bd = ByteData.sublistView(data);
      // VP8 (lossy)
      if (len >= 30 &&
          data[12] == 0x56 &&
          data[13] == 0x50 &&
          data[14] == 0x38 &&
          data[15] == 0x20 &&
          data[23] == 0x9D &&
          data[24] == 0x01 &&
          data[25] == 0x2A) {
        final w = (bd.getUint16(26, Endian.little) & 0x3FFF).toDouble();
        final h = (bd.getUint16(28, Endian.little) & 0x3FFF).toDouble();
        return (w > 0 && h > 0) ? (w: w, h: h) : null;
      }
      // VP8L (lossless)
      if (data[12] == 0x56 &&
          data[13] == 0x50 &&
          data[14] == 0x38 &&
          data[15] == 0x4C &&
          data[20] == 0x2F) {
        final bits = bd.getUint32(21, Endian.little);
        final w = ((bits & 0x3FFF) + 1).toDouble();
        final h = (((bits >> 14) & 0x3FFF) + 1).toDouble();
        return (w > 0 && h > 0) ? (w: w, h: h) : null;
      }
      // VP8X (extended)
      if (len >= 30 &&
          data[12] == 0x56 &&
          data[13] == 0x50 &&
          data[14] == 0x38 &&
          data[15] == 0x58) {
        final w = (1 + (data[24] | (data[25] << 8) | (data[26] << 16))).toDouble();
        final h = (1 + (data[27] | (data[28] << 8) | (data[29] << 16))).toDouble();
        return (w > 0 && h > 0) ? (w: w, h: h) : null;
      }
    }

    // JPEG: FF D8 ... SOF0..SOF15 (excluding DHT C4, JPG C8, DAC CC)
    if (data[0] == 0xFF && data[1] == 0xD8) {
      int pos = 2;
      while (pos + 3 < len) {
        while (pos < len && data[pos] != 0xFF) {
          pos++;
        }
        while (pos < len && data[pos] == 0xFF) {
          pos++;
        }
        if (pos >= len) break;
        final marker = data[pos++];
        if (marker == 0x00 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
          continue;
        }
        if (marker == 0xD9 || marker == 0xDA) break; // EOI or SOS
        if (pos + 1 >= len) break;
        final segLen = (data[pos] << 8) | data[pos + 1];
        if (segLen < 2 || pos + segLen > len) break;
        if (marker >= 0xC0 &&
            marker <= 0xCF &&
            marker != 0xC4 &&
            marker != 0xC8 &&
            marker != 0xCC) {
          if (pos + 6 < len) {
            final h = ((data[pos + 3] << 8) | data[pos + 4]).toDouble();
            final w = ((data[pos + 5] << 8) | data[pos + 6]).toDouble();
            return (w > 0 && h > 0) ? (w: w, h: h) : null;
          }
          break;
        }
        pos += segLen;
      }
      return null;
    }

    // SVG text header
    final head = utf8.decode(
      data.length > 2048 ? data.sublist(0, 2048) : data,
      allowMalformed: true,
    );
    final svgMatch = RegExp(r'<svg\b([^>]*)>', caseSensitive: false).firstMatch(head);
    if (svgMatch != null) {
      final attrs = svgMatch.group(1)!;
      double? attrNum(String name) {
        final m = RegExp(
          '\\b$name\\s*=\\s*["\']([^"\']+)["\']',
          caseSensitive: false,
        ).firstMatch(attrs);
        return HtmlChunkParser._parseSize(m?.group(1));
      }

      var w = attrNum('width');
      var h = attrNum('height');
      if (w == null || h == null) {
        final vb = RegExp(
          r'''\bviewBox\s*=\s*["']([^"']+)["']''',
          caseSensitive: false,
        ).firstMatch(attrs);
        if (vb != null) {
          final parts = vb
              .group(1)!
              .trim()
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
      if (w != null && h != null && w > 0 && h > 0) {
        return (w: w, h: h);
      }
    }

    return null;
  }

  @override
  Picture copyWith({
    int? idx,
    String? id,
    List<Span>? spans,
    String? text,
    Lang? lang,
    bool? strong,
    String? src,
    String? alt,
    double? w,
    double? h,
    Uint8List? Function()? bytes,
  }) =>
      Picture(
        src ?? this.src,
        alt: alt ?? this.alt,
        w: w ?? this.w,
        h: h ?? this.h,
        idx: idx ?? this.idx,
        id: id ?? this.id,
        bytes: bytes ?? _bytes,
      );

  @override
  String toString() => 'Picture($src${alt != null ? ", alt: $alt" : ""})';
}

abstract class Chapter {
  Chapter(this.title);
  final String title;
  List<Chunk> get chunks;

  List<Chunk>? _cached;
  bool _cleaned = false;
  double? _cachedMaxWidth;

  /// Whether this chapter's chunks have been processed through a cleaner.
  bool get isCleaned => _cleaned;

  /// Apply [cleaner] once and cache the prepared chunks (and optional
  /// [maxWidth] picture sizing), returning the cached list on subsequent calls.
  List<Chunk> cleanWith(
    Chunk Function(Chunk) cleaner, {
    double? maxWidth,
  }) {
    if (!_cleaned || _cached == null) {
      final base = _cached ?? chunks;
      if (!_cleaned) {
        _cached = [for (final c in base) cleaner(c)];
        _cleaned = true;
        _cachedMaxWidth = maxWidth;
        return _cached!;
      }
    }
    if (maxWidth != null && maxWidth != _cachedMaxWidth && _cached != null) {
      for (final c in _cached!) {
        if (c is Picture) {
          c.updateSize(maxWidth: maxWidth);
        }
      }
      _cachedMaxWidth = maxWidth;
    }
    return _cached!;
  }
}

class LazyChapter extends Chapter {
  LazyChapter(super.title, this._loader, {Chunk Function(Chunk)? clean})
      : _clean = clean;

  final List<Chunk> Function() _loader;
  final Chunk Function(Chunk)? _clean;

  @override
  List<Chunk> get chunks {
    final existing = _cached;
    if (existing != null) return existing;
    final loaded = _loader();
    final cleanFn = _clean;
    if (cleanFn != null) {
      _cached = [for (final c in loaded) cleanFn(c)];
      _cleaned = true;
    } else {
      _cached = loaded;
    }
    return _cached!;
  }
}

/// Reference to a [Chunk] location inside a [Book] by 0-based [chapter] and [chunk] indices.
typedef ChunkRef = ({int chapter, int chunk});

class Book {
  Book({
    required this.title,
    this.author,
    this.lang,
    this.description,
    Uint8List? Function()? cover,
    this.chapters = const [],
  }) : _cover = cover;

  final String title;
  final String? author;
  final String? lang;
  final String? description;
  final List<Chapter> chapters;
  final Uint8List? Function()? _cover;
  Map<String, List<ChunkRef>>? _index;

  /// Load cover image bytes on demand from the book metadata/archive.
  Uint8List? cover() => _cover?.call();

  /// Lazily built, cached inverted index mapping normalized keywords to
  /// ordered `(chapter, chunk)` references across all [chapters].
  Map<String, List<ChunkRef>> get index => _index ??= _buildIndex();

  /// Clear any cached inverted [index] so it rebuilds on next access.
  void invalidateIndex() => _index = null;

  /// Search the book using the inverted [index] for all normalized keywords in [query].
  ///
  /// When [exactPhrase] is `true`, candidate chunks are additionally verified
  /// to contain the normalized query phrase contiguously.
  List<ChunkRef> search(String query, {bool exactPhrase = false}) {
    final terms = _queryTokens(query);
    if (terms.isEmpty) return const [];

    final idx = index;
    final lists = <List<ChunkRef>>[];
    for (final term in terms) {
      final hits = idx[term];
      if (hits == null || hits.isEmpty) return const [];
      lists.add(hits);
    }

    lists.sort((a, b) => a.length.compareTo(b.length));
    var candidates = lists.first;
    for (int i = 1; i < lists.length; i++) {
      candidates = _intersectSorted(candidates, lists[i]);
      if (candidates.isEmpty) return const [];
    }

    if (!exactPhrase) return List<ChunkRef>.unmodifiable(candidates);

    final normQuery = _normalizeForPhrase(query);
    if (normQuery.isEmpty) return const [];
    final matched = <ChunkRef>[];
    for (final ref in candidates) {
      final chunk = chapters[ref.chapter].chunks[ref.chunk];
      if (_normalizeForPhrase(_chunkSearchText(chunk)).contains(normQuery)) {
        matched.add(ref);
      }
    }
    return matched;
  }

  Map<String, List<ChunkRef>> _buildIndex() {
    final map = <String, List<ChunkRef>>{};
    for (int chIdx = 0; chIdx < chapters.length; chIdx++) {
      final chunks = chapters[chIdx].chunks;
      for (int cIdx = 0; cIdx < chunks.length; cIdx++) {
        final text = _chunkSearchText(chunks[cIdx]);
        if (text.isEmpty) continue;
        final ref = (chapter: chIdx, chunk: cIdx);
        for (final token in _indexTokens(text)) {
          final list = map[token];
          if (list == null) {
            map[token] = <ChunkRef>[ref];
          } else if (list.last != ref) {
            list.add(ref);
          }
        }
      }
    }
    return map;
  }

  static String _chunkSearchText(Chunk chunk) {
    if (chunk.text != null) return chunk.text!;
    if (chunk.spans.isEmpty) return '';
    final buf = StringBuffer();
    for (int i = 0; i < chunk.spans.length; i++) {
      if (i > 0) buf.write(' ');
      buf.write(chunk.spans[i].text);
    }
    return buf.toString();
  }

  static List<ChunkRef> _intersectSorted(List<ChunkRef> a, List<ChunkRef> b) {
    final out = <ChunkRef>[];
    int i = 0;
    int j = 0;
    while (i < a.length && j < b.length) {
      final ra = a[i];
      final rb = b[j];
      final cmp = ra.chapter != rb.chapter
          ? ra.chapter.compareTo(rb.chapter)
          : ra.chunk.compareTo(rb.chunk);
      if (cmp == 0) {
        out.add(ra);
        i++;
        j++;
      } else if (cmp < 0) {
        i++;
      } else {
        j++;
      }
    }
    return out;
  }

  static final RegExp _tokenSegment = RegExp(
    r'[a-z0-9\u00c0-\u024f\u1e00-\u1eff]+|[\uac00-\ud7af]+|[\u4e00-\u9fff\u3040-\u30ff]+',
  );

  static String _foldWidthAndCase(String input) {
    final buf = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      if (code >= 0xFF01 && code <= 0xFF5E) {
        buf.writeCharCode(code - 0xFEE0);
      } else if (code == 0x3000) {
        buf.writeCharCode(0x20);
      } else {
        buf.writeCharCode(code);
      }
    }
    return buf.toString().toLowerCase();
  }

  static String _normalizeForPhrase(String input) =>
      _foldWidthAndCase(input).replaceAll(HtmlChunkParser._whitespace, ' ').trim();

  static Iterable<String> _indexTokens(String text) sync* {
    final normalized = _foldWidthAndCase(text);
    for (final m in _tokenSegment.allMatches(normalized)) {
      final seg = m.group(0)!;
      final first = seg.codeUnitAt(0);
      if (_isCjkOrKana(first)) {
        for (int i = 0; i < seg.length; i++) {
          yield seg.substring(i, i + 1);
          if (i + 1 < seg.length) {
            yield seg.substring(i, i + 2);
          }
        }
      } else {
        yield seg;
      }
    }
  }

  static List<String> _queryTokens(String query) {
    final normalized = _foldWidthAndCase(query);
    final tokens = <String>[];
    for (final m in _tokenSegment.allMatches(normalized)) {
      final seg = m.group(0)!;
      final first = seg.codeUnitAt(0);
      if (_isCjkOrKana(first)) {
        if (seg.length == 1) {
          tokens.add(seg);
        } else {
          for (int i = 0; i + 1 < seg.length; i++) {
            tokens.add(seg.substring(i, i + 2));
          }
        }
      } else {
        tokens.add(seg);
      }
    }
    return tokens;
  }

  static bool _isCjkOrKana(int code) =>
      (code >= 0x4E00 && code <= 0x9FFF) ||
      (code >= 0x3040 && code <= 0x30FF);
}

/// Shared HTML/XHTML chunk parser used by EPUB and MOBI/AZW/AZW3 readers.
class HtmlChunkParser {
  static final RegExp _hangul = RegExp(r'[\uac00-\ud7af\u1100-\u11ff]');
  static final RegExp _kana = RegExp(r'[\u3040-\u309f\u30a0-\u30ff]');
  static final RegExp _cjk = RegExp(r'[\u4e00-\u9fff]');
  static final RegExp _spanish = RegExp(r'[¡¿áéíóúüñÁÉÍÓÚÜÑ]');
  static final RegExp _latin = RegExp(r'[a-zA-Z]');

  static const Set<String> _blocks = {
    'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'aside', 'blockquote'
  };

  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _multiSpace = RegExp(r' {2,}');
  static final RegExp _footnoteHint = RegExp(
    r'footnote|doc-endnote|endnotes',
    caseSensitive: false,
  );
  static final RegExp _imgHint = RegExp(r'<img\b|<image\b', caseSensitive: false);
  static final RegExp _anchorHint = RegExp(r'<a\b', caseSensitive: false);
  static final RegExp _strongHint = RegExp(r'<strong\b', caseSensitive: false);
  static final RegExp _tagOrEntity = RegExp(r'[<&]');
  static final RegExp _titleOrComment = RegExp(
    r'<!--[\s\S]*?-->|<(h1|h2|h3|title)\b[^>]*>([\s\S]*?)</\1>',
    caseSensitive: false,
  );
  static final RegExp _headingOpen = RegExp(
    r'<(?:h[1-3]|title)\b',
    caseSensitive: false,
  );

  static const Set<String> _nonVoidSelfClosing = {
    'script',
    'style',
    'title',
    'textarea',
    'noscript',
    'iframe',
    'div',
    'span',
    'p',
    'a',
    'aside',
    'section',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'ul',
    'ol',
    'blockquote',
    'strong',
    'em',
    'b',
    'i',
    'u',
    'sup',
    'sub',
  };

  /// Extract footnote definitions (`<aside epub:type="footnote">`, `.duokan-footnote-item`,
  /// or EPUB3/InDesign `<section role="doc-endnotes">` `<li id="...">`).
  static Map<String, String> extractFootnotes(String html) {
    if (!_footnoteHint.hasMatch(html)) return const {};
    final doc = _parseRoot(html);
    return _extractFootnotesFromNode(doc);
  }

  /// Extract first heading or `<title>` for a chapter, falling back to [fallback].
  static String extractChapterTitle(String html, String fallback) {
    String? bestH2;
    String? bestH3;
    String? bestTitle;
    bool sawEmpty = false;

    String extractInner(String inner) {
      final raw = _tagOrEntity.hasMatch(inner)
          ? (html_parser.parseFragment(inner).text ?? '')
          : inner;
      return raw.replaceAll(_whitespace, ' ').trim();
    }

    for (final m in _titleOrComment.allMatches(html)) {
      final tag = m.group(1)?.toLowerCase();
      if (tag == null) continue;
      if (tag == 'h1') {
        final t = extractInner(m.group(2)!);
        if (t.isNotEmpty) return t;
        sawEmpty = true;
      } else if (tag == 'h2' && bestH2 == null) {
        final t = extractInner(m.group(2)!);
        if (t.isNotEmpty) {
          bestH2 = t;
        } else {
          sawEmpty = true;
          bestH2 = '';
        }
      } else if (tag == 'h3' && bestH3 == null) {
        final t = extractInner(m.group(2)!);
        if (t.isNotEmpty) {
          bestH3 = t;
        } else {
          sawEmpty = true;
          bestH3 = '';
        }
      } else if (tag == 'title' && bestTitle == null) {
        final t = extractInner(m.group(2)!);
        if (t.isNotEmpty) {
          bestTitle = t;
        } else {
          sawEmpty = true;
          bestTitle = '';
        }
      }
    }

    final found = (bestH2 != null && bestH2.isNotEmpty)
        ? bestH2
        : (bestH3 != null && bestH3.isNotEmpty)
            ? bestH3
            : (bestTitle != null && bestTitle.isNotEmpty)
                ? bestTitle
                : null;
    if (found != null) return found;
    if (sawEmpty || !_headingOpen.hasMatch(html)) return fallback;

    final doc = _parseRoot(html);
    for (final selector in ['h1', 'h2', 'h3', 'title']) {
      final text = _queryFirst(doc, selector)
          ?.text
          .replaceAll(_whitespace, ' ')
          .trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return fallback;
  }

  /// Parse an HTML / XHTML document or fragment into [Chunk]s ([Chunk] and [Picture]).
  static List<Chunk> parseHtml(
    String html, {
    Lang defaultLang = Lang.unknown,
    Map<String, String> footnotes = const {},
    String Function(String recindex)? resolveRecindex,
    Uint8List? Function(String src)? resolveImageBytes,
  }) {
    final doc = _parseRoot(html);
    final fnMap = _footnoteHint.hasMatch(html)
        ? <String, String>{
            ...footnotes,
            ..._extractFootnotesFromNode(doc),
          }
        : footnotes;
    final hasImg = _imgHint.hasMatch(html);
    final hasAnchor = _anchorHint.hasMatch(html);
    final hasStrong = _strongHint.hasMatch(html);
    final chunks = <Chunk>[];

    void process(dom.Node node, Lang inheritedLang) {
      if (node is! dom.Element) return;

      final tag = node.localName?.toLowerCase() ?? '';
      if (tag == 'head' || tag == 'title' || tag == 'script' || tag == 'style') {
        return;
      }
      if (_isFootnoteContainer(node, tag)) return;

      final isBlock = _blocks.contains(tag) || tag == 'strong';

      if (tag == 'img' || tag == 'image') {
        if (!_isFootnoteImg(node)) {
          final pic = _buildPicture(
            node,
            resolveRecindex,
            resolveImageBytes,
            idx: chunks.length,
          );
          if (pic != null) chunks.add(pic);
        }
        return;
      }

      if (isBlock) {
        final hasChildBlocks = tag != 'aside' &&
            tag != 'strong' &&
            node.children.any((c) => _blocks.contains(c.localName?.toLowerCase()));

        if (hasChildBlocks) {
          final lang = _detectLang(
            node.classes,
            node.attributes,
            node.text,
            inheritedLang,
          );
          for (final child in node.children) {
            process(child, lang);
          }
          return;
        }

        final id = _getId(node, checkAnchorChild: hasAnchor);
        final strong = _isHeading(tag) ||
            tag == 'strong' ||
            (hasStrong && _allContentInStrong(node));
        final spans = _extractSpans(node, fnMap);
        final hasSpanAnchor = spans.any((s) => s is Anchor);

        if (spans.isNotEmpty) {
          final plainText = hasSpanAnchor
              ? spans.map((s) => s.text).join().trim()
              : spans.first.text;
          var langText = plainText;
          if (langText.isEmpty && hasSpanAnchor) {
            langText = spans.whereType<Anchor>().map((a) => a.note).nonNulls.join(' ');
          }
          final resolvedLang = _detectLang(
            node.classes,
            node.attributes,
            langText,
            inheritedLang,
          );

          if (hasSpanAnchor) {
            chunks.add(Chunk(
              idx: chunks.length,
              id: id,
              spans: spans,
              lang: resolvedLang,
              strong: strong,
            ));
          } else {
            chunks.add(Chunk(
              idx: chunks.length,
              id: id,
              text: spans.first.text,
              lang: resolvedLang,
              strong: strong,
            ));
          }
        }

        if (hasImg) {
          for (final imgEl in node.querySelectorAll('img, image')) {
            if (!_isFootnoteImg(imgEl) && !_isInsideFootnoteAnchor(imgEl)) {
              final pic = _buildPicture(
                imgEl,
                resolveRecindex,
                resolveImageBytes,
                idx: chunks.length,
              );
              if (pic != null) chunks.add(pic);
            }
          }
        }
        return;
      }

      final lang = _detectAttrLang(
        node.classes,
        node.attributes,
        inheritedLang,
      );
      for (final child in node.children) {
        process(child, lang);
      }
    }

    if (doc is dom.Element) {
      process(doc, defaultLang);
    } else {
      for (final child in doc.children) {
        process(child, defaultLang);
      }
    }
    return chunks;
  }

  static String _normalizeSelfClosingXhtml(String html) {
    var idx = html.indexOf('/>');
    if (idx < 0) return html;

    StringBuffer? buf;
    var copiedUpTo = 0;

    while (idx >= 0) {
      // Walk backward to the opening '<' of this tag (ignoring any '>' earlier).
      var open = idx - 1;
      var inSingle = false;
      var inDouble = false;
      var hitGt = false;
      while (open >= copiedUpTo) {
        final c = html.codeUnitAt(open);
        if (c == 0x22 && !inSingle) {
          inDouble = !inDouble;
        } else if (c == 0x27 && !inDouble) {
          inSingle = !inSingle;
        } else if (!inSingle && !inDouble) {
          if (c == 0x3C) break; // '<'
          if (c == 0x3E) {
            hitGt = true;
            break;
          }
        }
        open--;
      }

      if (!hitGt && open >= copiedUpTo && html.codeUnitAt(open) == 0x3C && !inSingle && !inDouble) {
        var nameStart = open + 1;
        while (nameStart < idx && html.codeUnitAt(nameStart) <= 0x20) {
          nameStart++;
        }
        var nameEnd = nameStart;
        while (nameEnd < idx) {
          final c = html.codeUnitAt(nameEnd);
          if (c <= 0x20 || c == 0x2F) break; // whitespace or '/'
          nameEnd++;
        }
        if (nameEnd > nameStart) {
          final tagName = html.substring(nameStart, nameEnd).toLowerCase();
          if (_nonVoidSelfClosing.contains(tagName)) {
            buf ??= StringBuffer();
            buf.write(html.substring(copiedUpTo, idx));
            buf.write('></');
            buf.write(tagName);
            buf.write('>');
            copiedUpTo = idx + 2;
          }
        }
      }

      idx = html.indexOf('/>', idx + 2);
    }

    if (buf == null) return html;
    buf.write(html.substring(copiedUpTo));
    return buf.toString();
  }

  static dom.Node _parseRoot(String html) {
    final normalized = _normalizeSelfClosingXhtml(html);
    if (RegExp(r'<\s*(html|body)\b', caseSensitive: false).hasMatch(normalized)) {
      return html_parser.parse(normalized).documentElement ??
          html_parser.parseFragment(normalized);
    }
    return html_parser.parseFragment(normalized);
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

  static dom.Element? _queryFirst(dom.Node node, String selector) {
    if (node is dom.Element) return node.querySelector(selector);
    if (node is dom.DocumentFragment) return node.querySelector(selector);
    return null;
  }

  static List<dom.Element> _queryAll(dom.Node node, String selector) {
    if (node is dom.Element) return node.querySelectorAll(selector);
    if (node is dom.DocumentFragment) return node.querySelectorAll(selector);
    return const [];
  }

  static Map<String, String> _extractFootnotesFromNode(dom.Node doc) {
    final map = <String, String>{};
    final elements = _queryAll(doc, 'aside, li');

    for (final el in elements) {
      final tag = el.localName?.toLowerCase() ?? '';
      if (el.id.isEmpty) continue;
      if (!_isFootnoteContainer(el, tag) && !_insideEndnoteSection(el)) continue;
      final text = _extractFootnoteBody(el);
      if (text.isNotEmpty) map[el.id] = text;
    }
    return map;
  }

  static bool _insideEndnoteSection(dom.Element el) {
    dom.Element? p = el.parent;
    while (p != null) {
      final tag = p.localName?.toLowerCase() ?? '';
      if (tag == 'section' && _isFootnoteContainer(p, tag)) return true;
      p = p.parent;
    }
    return false;
  }

  static String _extractFootnoteBody(dom.Element root) {
    final buf = StringBuffer();
    bool skippedBacklink = false;

    void walk(dom.Node n) {
      if (n is dom.Text) {
        buf.write(n.text);
        return;
      }
      if (n is! dom.Element) return;
      final tag = n.localName?.toLowerCase() ?? '';
      if (tag == 'script' || tag == 'style') return;
      if (tag == 'a' && _isBacklink(n)) {
        skippedBacklink = true;
        return;
      }
      for (final child in n.nodes) {
        walk(child);
      }
    }

    walk(root);
    var text = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (skippedBacklink) {
      text = text.replaceFirst(RegExp(r'^[:：\s]+'), '');
    }
    return text;
  }

  static bool _isBacklink(dom.Element a) =>
      a.attributes['role'] == 'doc-backlink' ||
      a.attributes['epub:type'] == 'backlink' ||
      a.classes.contains('_idFootnoteAnchor');

  static bool _isFootnoteContainer(dom.Element el, String tag) {
    final epubType = el.attributes['epub:type'];
    final role = el.attributes['role'];
    if (tag == 'aside') {
      return epubType == 'footnote' ||
          role == 'doc-footnote' ||
          el.querySelector('.duokan-footnote-content, .duokan-footnote-item') != null ||
          el.id.contains('footnote');
    }
    if (tag == 'section') {
      return epubType == 'endnotes' ||
          epubType == 'footnotes' ||
          role == 'doc-endnotes' ||
          el.classes.contains('_idFootnotes');
    }
    if (tag == 'li') {
      return (el.classes.contains('duokan-footnote-item') && el.id.isNotEmpty) ||
          el.classes.contains('_idFootnote') ||
          epubType == 'footnote' ||
          role == 'doc-footnote' ||
          role == 'doc-endnote';
    }
    return false;
  }

  static List<Span> _extractSpans(
    dom.Element root,
    Map<String, String> footnotes,
  ) {
    final spans = <Span>[];
    final plainBuf = StringBuffer();

    void flushPlain() {
      if (plainBuf.isEmpty) return;
      final norm = plainBuf
          .toString()
          .replaceAll(_whitespace, ' ')
          .replaceAll(_multiSpace, ' ');
      plainBuf.clear();
      if (norm.isEmpty) return;
      if (spans.isNotEmpty && spans.last is! Anchor) {
        final merged = '${spans.last.text}$norm'.replaceAll(_multiSpace, ' ');
        spans[spans.length - 1] = Span(merged);
        return;
      }
      spans.add(Span(norm));
    }

    void walk(dom.Node node) {
      if (node is dom.Text) {
        plainBuf.write(node.text);
        return;
      }
      if (node is! dom.Element) return;

      final tag = node.localName?.toLowerCase() ?? '';
      if (tag == 'script' || tag == 'style') return;
      if (tag == 'br') {
        plainBuf.write(' ');
        return;
      }
      if (tag == 'img' || tag == 'image') {
        final fn = _extractImgFootnote(node);
        if (fn != null) {
          flushPlain();
          spans.add(Anchor('', note: fn));
        }
        return;
      }
      if (tag == 'a') {
        final href = node.attributes['href']?.trim() ?? '';
        final linkText = node.text.replaceAll(_whitespace, ' ').trim();
        final hashIdx = href.indexOf('#');
        final targetId = hashIdx >= 0 ? href.substring(hashIdx + 1) : href;
        final resolvedFn = targetId.isNotEmpty ? footnotes[targetId] : null;
        final isFnRef = resolvedFn != null || _isFootnoteAnchor(node, href);

        String? note = resolvedFn;
        if (note == null && isFnRef) {
          note = _extractImgFootnoteFromTree(node);
        }

        if (href.isNotEmpty || note != null) {
          flushPlain();
          spans.add(Anchor(
            linkText,
            note: note,
            link: href.isNotEmpty ? href : null,
          ));
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
    flushPlain();

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
    if (a.attributes['epub:type'] == 'noteref' ||
        a.attributes['role'] == 'doc-noteref' ||
        a.classes.contains('_idFootnoteLink')) {
      return true;
    }
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
            parent.attributes['role'] == 'doc-noteref' ||
            parent.classes.contains('_idFootnoteLink') ||
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

  static Lang _detectAttrLang(
    Iterable<String> classes,
    Map<dynamic, String> attrs,
    Lang fallback,
  ) {
    if (attrs.containsKey('class')) {
      for (final cls in classes) {
        final l = Lang.from(cls);
        if (l != Lang.unknown) return l;
      }
    }
    final attrLang = attrs['lang'] ?? attrs['xml:lang'];
    if (attrLang != null) {
      final l = Lang.from(attrLang);
      if (l != Lang.unknown) return l;
    }
    return fallback;
  }

  static Lang _detectLang(
    Iterable<String> classes,
    Map<dynamic, String> attrs,
    String text,
    Lang fallback,
  ) {
    final explicit = _detectAttrLang(classes, attrs, Lang.unknown);
    if (explicit != Lang.unknown) return explicit;
    return _detectFromText(text.trim(), fallback);
  }

  static Lang _detectFromText(String text, Lang fallback) {
    if (text.isEmpty) return fallback;
    if (_hangul.hasMatch(text)) return Lang.kr;
    if (_kana.hasMatch(text)) return Lang.jp;
    if (_cjk.hasMatch(text)) {
      final cjkCount = _cjk.allMatches(text).length;
      final latinCount = _latin.allMatches(text).length;
      if (latinCount >= cjkCount && text.length > 25) return Lang.all;
      return Lang.zh;
    }
    if (_spanish.hasMatch(text)) return Lang.es;
    if (_latin.hasMatch(text)) return Lang.en;
    return fallback;
  }

  static String? _getId(dom.Element el, {bool checkAnchorChild = true}) {
    if (el.id.isNotEmpty) return el.id;
    if (el.attributes.containsKey('name')) return el.attributes['name'];
    if (!checkAnchorChild) return null;
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

  static Picture? _buildPicture(
    dom.Element img,
    String Function(String recindex)? resolveRecindex,
    Uint8List? Function(String src)? resolveImageBytes, {
    int idx = 0,
  }) {
    var src = _attr(img, ['src', 'xlink:href', 'href']);
    if (src == null || src.isEmpty) {
      final recindex = _attr(img, ['recindex']);
      if (recindex != null && resolveRecindex != null) {
        src = resolveRecindex(recindex);
      }
    }
    if (src == null || src.isEmpty) return null;

    final resolvedSrc = src;
    Uint8List? Function()? loader;
    if (resolvedSrc.startsWith('data:')) {
      final idx = resolvedSrc.indexOf(';base64,');
      if (idx >= 0) {
        loader = () => Uint8List.fromList(
              base64Decode(resolvedSrc.substring(idx + 8).trim()),
            );
      }
    } else if (resolveImageBytes != null) {
      loader = () => resolveImageBytes(resolvedSrc);
    }

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

    final id = _getId(img) ??
        (img.parent?.localName?.toLowerCase() == 'svg'
            ? _getId(img.parent!)
            : null);

    return Picture(
      resolvedSrc,
      alt: alt,
      w: w,
      h: h,
      idx: idx,
      id: id,
      bytes: loader,
    );
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
  }) =>
      HtmlChunkParser.parseHtml(
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

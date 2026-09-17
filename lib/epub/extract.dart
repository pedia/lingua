import 'package:html/dom.dart' as dom;
import 'book.dart';

/// Extracts a flat list of [Line] / [Picture] from an HTML DOM subtree.
List<Line> extract(dom.Node root) {
  final result = <Line>[];

  void walk(dom.Node node, {String inheritedLang = ''}) {
    if (node is dom.Text) {
      final t = node.text.trim();
      if (t.isNotEmpty) {
        result.add(Line(t, inheritedLang));
      }
      return;
    }

    if (node is! dom.Element) return;

    final tag = node.localName?.toLowerCase() ?? '';

    // ── Picture ────────────────────────────────────────────────
    if (tag == 'img') {
      final src = node.attributes['src'] ?? '';
      if (src.isNotEmpty) {
        result.add(Picture(src));
      }
      return;
    }

    // ── Paragraph / Heading (may contain text + images) ────────
    if (tag == 'p' || RegExp(r'^h[1-5]$').hasMatch(tag)) {
      final lang = node.attributes['lang'] ?? inheritedLang;
      _extractMixedContent(node, lang, result);
      return;
    }

    // ── Line break ─────────────────────────────────────────────
    if (tag == 'br') {
      result.add(Line('', inheritedLang));
      return;
    }

    // ── Structural / inline containers ─────────────────────────
    // div, ul, li, span, a, i, em, strong, b, sup, …
    final nextLang = node.attributes['lang'] ?? inheritedLang;
    for (final child in node.nodes) {
      walk(child, inheritedLang: nextLang);
    }
  }

  walk(root);
  return result;
}

/// Handles mixed content inside <p> / <h1>–<h5>:
/// consecutive text → one Line, <img> → Picture, etc.
void _extractMixedContent(dom.Element element, String lang, List<Line> result) {
  final buffer = StringBuffer();

  void flushText() {
    final text = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isNotEmpty) {
      result.add(Line(text, lang));
    }
    buffer.clear();
  }

  void process(dom.Node node) {
    if (node is dom.Text) {
      buffer.write(node.text);
      return;
    }

    if (node is! dom.Element) return;

    final tag = node.localName?.toLowerCase() ?? '';

    if (tag == 'img') {
      flushText(); // emit any pending text first
      final src = node.attributes['src'] ?? '';
      if (src.isNotEmpty) {
        result.add(Picture(src));
      }
      return;
    }

    if (tag == 'br') {
      buffer.write(' ');
      return;
    }

    // Inline / formatting tags (a, span, i, strong, b, …) → keep walking
    for (final child in node.nodes) {
      process(child);
    }
  }

  for (final child in element.nodes) {
    process(child);
  }
  flushText(); // remaining text at the end
}

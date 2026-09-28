import 'dart:typed_data';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as dom;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'data/sample.dart';

bool canLaunchUrl(Uri _) => false;
Future<void> launchUrl(Uri _) => Future.value();

abstract class FileProvider {
  Uint8List bytes(String path);
}

/// Html to Widget
class HtmlWidget extends StatefulWidget {
  const HtmlWidget(
    this.doc, {
    this.provider,
    this.initialIndex = 0,
    this.scrollNotify,
    super.key,
  });
  final dom.Document doc;
  // TODO: add active item
  final int initialIndex; // top index
  final FileProvider? provider; // top index
  final Function(double offset, int lineIndex)? scrollNotify;

  factory HtmlWidget.from(
    String html, {
    FileProvider? provider,
    int initialIndex = 0,
    Key? key,
    Function(double offset, int lineIndex)? scrollNotify,
  }) => HtmlWidget(
    dom.parse(html),
    provider: provider,
    initialIndex: initialIndex,
    key: key,
    scrollNotify: scrollNotify,
  );

  @override
  State<StatefulWidget> createState() => HtmlWidgetState();
}

class HtmlWidgetState extends State<HtmlWidget> {
  final roller = ScrollController();
  int? firstVisibleIdx;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialIndex != 0) {
        final key = topks['${widget.initialIndex}'];
        if (key != null) Scrollable.ensureVisible(key.currentContext!);
      }
    });

    roller.addListener(_onScroll);
  }

  @override
  void dispose() {
    roller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final RenderBox? scrollBox = context.findRenderObject() as RenderBox?;
    if (scrollBox == null) return;

    int? idx;
    double closestTop = double.infinity;

    for (final e in topks.entries) {
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;

      final position = box.localToGlobal(Offset.zero, ancestor: scrollBox);
      final top = position.dy;

      if (top >= -box.size.height && top < closestTop) {
        closestTop = top;
        idx = int.tryParse(e.key);
      }
    }

    if (idx != null && idx != firstVisibleIdx) {
      print(
        'onScroll ${roller.offset.toStringAsFixed(2)}, First visible block: $idx',
      );
      firstVisibleIdx = idx;
    }

    widget.scrollNotify?.call(roller.offset, firstVisibleIdx ?? 0);
  }

  /// top level WidgetSpan: 'index' => GlogalKey
  /// anchor: '#id' => GlogalKey
  final topks = <String, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final body = widget.doc.body ?? dom.Element.tag('body');
    return SingleChildScrollView(
      controller: roller,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(8),
        child: Text.rich(
          TextSpan(
            mouseCursor: SystemMouseCursors.text,
            children: topBlocks(body.children),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> topBlocks(List<dom.Element> es) {
    final rs = <InlineSpan>[];
    for (var i = 0; i < es.length; i++) {
      rs.add(
        WidgetSpan(
          child: Text.rich(
            trans(es[i]),
            key: newKey('$i'),
            style: widget.initialIndex == i
                ? TextStyle(
                    backgroundColor:
                        TextSelectionTheme.of(context).selectionColor ??
                        Colors.blue.withValues(alpha: 0.4),
                  )
                : null,
          ),
        ),
      );
      rs.add(TextSpan(text: '\n'));
    }

    rs.add(TextSpan(text: 'debug ks: ${topks.keys}'));
    return rs;
  }

  GlobalKey newKey(String name) {
    return topks.putIfAbsent(name, () => GlobalKey());
  }

  double fontSize(String tag) => switch (tag) {
    'h1' => 32,
    'h2' => 24,
    'h3' => 18,
    _ => 18,
  };

  /// Translate or transform html tag into InlineSpan
  /// force img height
  /// <p><sup><a><img></a></p>
  InlineSpan trans(dom.Element e, {double? forceInlineHeight}) {
    // 1. Recursively parse all child nodes (text and nested tags)
    List<InlineSpan>? children = [];
    String? text;
    for (var c in e.nodes) {
      if (c is dom.Element) {
        // Recursive call for nested elements
        children.add(trans(c, forceInlineHeight: forceInlineHeight));
      } else if (c.nodeType == dom.Node.TEXT_NODE) {
        final t = _removeUnnecessaryWhitespace(c.text ?? '');
        if (children.isEmpty && c.text != null) {
          text = t;
          if (t != ' ') forceInlineHeight ??= fontSize(e.localName ?? '');
        } else {
          children.add(TextSpan(text: t));
        }
      } else {
        debugPrint('ignore $c');
      }
    }
    if (children.isEmpty) {
      children = null;
    }

    // 2. Apply styling based on the local tag name
    final inside = switch (e.localName) {
      'figure' || 'div' || 'p' => TextSpan(
        text: text,
        children: children,
        style: const TextStyle(fontSize: 16.0, height: 1.55),
      ),
      'h1' => TextSpan(
        text: text,
        children: children,
        style: const TextStyle(fontSize: 32.0, height: 1.55),
      ),
      'h2' => TextSpan(
        text: text,
        children: children,
        style: const TextStyle(fontSize: 24.0, height: 1.55),
      ),
      'h3' => TextSpan(
        text: text,
        children: children,
        style: const TextStyle(fontSize: 18.0, height: 1.55),
      ),

      'b' || 'strong' => TextSpan(
        children: children,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),

      'i' || 'em' => TextSpan(
        text: text,
        children: children,
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),

      'u' => TextSpan(
        text: text,
        children: children,
        style: const TextStyle(decoration: TextDecoration.underline),
      ),

      'span' => TextSpan(text: text, children: children),

      'img' => WidgetSpan(
        child: Image.memory(
          widget.provider?.bytes(e.attributes['src'] ?? '') ?? note,
          fit: BoxFit.fitHeight,
          width: forceInlineHeight != null
              ? null
              : double.tryParse(e.attributes['width'] ?? ''),
          height:
              forceInlineHeight ??
              double.tryParse(e.attributes['height'] ?? ''),
        ),
      ),

      'a' => linkify(
        TextSpan(text: text, children: children),
        e.attributes['href'] ?? '',
      ),

      'code' => TextSpan(
        children: children,
        style: TextStyle(
          fontFamily: 'monospace',
          backgroundColor: Colors.grey[200],
          color: Colors.red[800],
        ),
      ),

      'br' => const TextSpan(text: '\n'),

      _ => TextSpan(text: text, children: children),
    };

    /// force img to inline img here
    if (inside is TextSpan && inside.text != null) {
      if (inside.children != null) {
        for (var i = 0; i < inside.children!.length; i++) {
          final c = inside.children![i];
          if (c is WidgetSpan && c.child is Image) {
            print('got you');
          }
        }
      }
    }

    final id = e.attributes['id'];
    if (id == null) {
      return inside;
    }

    return WidgetSpan(child: Text.rich(inside, key: newKey('#$id')));
  }

  /// [_removeUnnecessaryWhitespace] removes "unnecessary" white space from the given String.
  ///
  /// The steps for removing this whitespace are as follows:
  /// (1) Remove any whitespace immediately preceding or following a newline.
  /// (2) Replace all newlines with a space
  /// (3) Replace all tabs with a space
  /// (4) Replace any instances of two or more spaces with a single space.
  static String _removeUnnecessaryWhitespace(String text) {
    return text
        .replaceAll(RegExp(r" *\n *"), "\n")
        .replaceAll("\n", " ")
        .replaceAll("\t", " ")
        .replaceAll(RegExp(r" {2,}"), " ");
  }

  InlineSpan linkify(InlineSpan w, String href) {
    if (w is TextSpan) {
      w = TextSpan(
        text: w.text,
        children: w.children?.map((e) => linkify(e, href)).toList(),
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
        mouseCursor: SystemMouseCursors.click,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            print('anchor click $href');
            if (href.startsWith('#')) {
              // id => GlobalKey/context
              final key = topks[href];
              if (key != null) {
                await Scrollable.ensureVisible(key.currentContext!);
              }
            }
            final url = Uri.tryParse(href);
            if (url != null && canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
      );
    }
    return w;
  }
}

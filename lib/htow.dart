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
  const HtmlWidget(this.doc, {this.provider, this.initialIndex = 0, super.key});
  final dom.Document doc;
  final int initialIndex; // top index
  final FileProvider? provider; // top index

  factory HtmlWidget.from(
    String html, {
    FileProvider? provider,
    int initialIndex = 0,
    Key? key,
  }) => HtmlWidget(
    dom.parse(html),
    provider: provider,
    initialIndex: initialIndex,
    key: key,
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
  }

  /// top level WidgetSpan: 'index' => GlogalKey
  /// anchor: '#id' => GlogalKey
  final topks = <String, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final body = widget.doc.body ?? dom.Element.tag('body');
    return SelectionArea(
      child: SingleChildScrollView(
        controller: roller,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(8),
          child: Text.rich(
            TextSpan(
              //   mouseCursor: SystemMouseCursors.text,
              children: topBlocks(body.children),
            ),
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
          child: Container(key: newKey('$i'), child: Text.rich(trans(es[i]))),
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

  /// translate all tag into InlineSpan
  InlineSpan trans(dom.Element e) {
    // 1. Recursively parse all child nodes (text and nested tags)
    final children = <InlineSpan>[];
    String? text;
    for (var c in e.nodes) {
      if (c is dom.Element) {
        children.add(trans(c)); // Recursive call for nested elements
      } else if (c.nodeType == dom.Node.TEXT_NODE) {
        if (children.isEmpty) {
          text = c.text;
        } else {
          children.add(TextSpan(text: c.text));
        }
      } else {
        debugPrint('ignore $c');
      }
    }
    // text: '',
    // children: <InlineSpan>[],

    // 2. Apply styling based on the local tag name
    final inside = switch (e.localName) {
      'figure' || 'div' || 'p' => TextSpan(
        text: text,
        children: children.isEmpty ? null : children,
        style: const TextStyle(fontSize: 16.0, height: 1.4),
      ),
      'h1' => TextSpan(
        text: text,
        children: children.isEmpty ? null : children,
        style: const TextStyle(fontSize: 32.0, height: 1.4),
      ),
      'h2' => TextSpan(
        text: text,
        children: children.isEmpty ? null : children,
        style: const TextStyle(fontSize: 24.0, height: 1.4),
      ),
      'h3' => TextSpan(
        text: text,
        children: children.isEmpty ? null : children,
        style: const TextStyle(fontSize: 18.0, height: 1.4),
      ),

      'b' || 'strong' => TextSpan(
        children: children,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),

      'i' || 'em' => TextSpan(
        text: text,
        children: children.isEmpty ? null : children,
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),

      'u' => TextSpan(
        text: text,
        children: children.isEmpty ? null : children,
        style: const TextStyle(decoration: TextDecoration.underline),
      ),

      'span' => TextSpan(
        text: text,
        children: children.isEmpty ? null : children,
      ),

      'img' => WidgetSpan(
        child: Image.memory(
          widget.provider?.bytes(e.attributes['src'] ?? '') ?? note,
          fit: BoxFit.fill,
          width: double.tryParse(e.attributes['width'] ?? ''),
          height: double.tryParse(e.attributes['height'] ?? ''),
        ),
      ),

      'a' => TextSpan(
        text: text,
        children: children.isEmpty ? null : children,
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
        mouseCursor: SystemMouseCursors.click,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final href = e.attributes['href'] ?? '';
            print('anchor click $href');
            if (href.startsWith('#')) {
              // id => GlobalKey/context
              final key = topks[href];
              if (key != null) {
                await Scrollable.ensureVisible(key.currentContext!);
              }
            }
            final url = Uri.tryParse(e.attributes['href'] ?? '');
            if (url != null && canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
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

      _ =>
        children.isNotEmpty ? TextSpan(children: children) : const TextSpan(),
    };

    final id = e.attributes['id'];
    if (id == null) {
      return inside;
    }

    return WidgetSpan(
      child: Container(key: newKey('#$id'), child: Text.rich(inside)),
    );
  }
}

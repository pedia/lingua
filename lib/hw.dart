import 'dart:typed_data';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as dom;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lingua/settings/setting.dart';
import 'data/sample.dart';
import 'epub/lang.dart';

bool canLaunchUrl(Uri _) => false;
Future<void> launchUrl(Uri _) => Future.value();

abstract class FileProvider {
  Uint8List bytes(String path);
}

@immutable
class Block {
  const Block({
    required this.i,
    required this.e,
    this.key,
    this.selected = false,
    this.lang = Lang.all,
  });
  // clickable
  final int i; // index from Doc.blocks
  final GlobalKey? key;
  final bool selected;
  final dom.Element e;
  final Lang lang;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Block &&
          other.i == i &&
          other.key == key &&
          other.selected == selected &&
          // dom.Element hasn't ==
          other.e == e);

  @override
  int get hashCode => Object.hash(i, key, selected, e);

  Block copyWith({
    int? i,
    GlobalKey? key,
    bool? selected,
    dom.Element? e,
    Lang? lang,
  }) => Block(
    i: i ?? this.i,
    key: key ?? this.key,
    selected: selected ?? this.selected,
    e: e ?? this.e,
    lang: lang ?? this.lang,
  );
}

class BlockWidget extends ConsumerWidget {
  final Doc doc;
  final Mode mode;
  final int index;
  final FileProvider? provider;
  const BlockWidget({
    super.key,
    required this.doc,
    required this.mode,
    required this.index,
    this.provider,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = doc.blocks[index];
    // debugPrint('🟢 Building BlockWidget[$index] ${b.lang} ${b.e.innerHtml}');
    // debugPrint('${b.e.attributes}');

    return Text.rich(
      clickable(trans(b, ref), b.i, ref),
      key: b.key,
      // CASE: selection style
      // style: ref.watch(linep) == index
      //     ? TextStyle(
      //         backgroundColor:
      //             TextSelectionTheme.of(context).selectionColor ??
      //             Colors.blue.withValues(alpha: 0.4),
      //       )
      //     : null,
    );
  }

  /// add CR
  List<InlineSpan> cr(List<InlineSpan>? children) {
    if (mode != Mode.rich) {
      return children ?? [];
    }
    if (children == null) {
      return [TextSpan(text: '\n')];
    }
    return children..add(TextSpan(text: '\n'));
  }

  /// Translate or transform html tag into InlineSpan
  /// force img height
  /// <p><sup><a><img></a></p>
  InlineSpan trans(Block b, WidgetRef ref, {double? forceInlineHeight}) {
    // 1. Recursively parse all child nodes (text and nested tags)
    List<InlineSpan>? children = [];
    String? text;
    for (var c in b.e.nodes) {
      if (c is dom.Element) {
        // Recursive call for nested elements
        children.add(
          trans(
            Block(i: -1, e: c, lang: b.lang),
            ref,
            forceInlineHeight: forceInlineHeight,
          ),
        );
      } else if (c.nodeType == dom.Node.TEXT_NODE) {
        final t = _removeUnnecessaryWhitespace(c.text ?? '');
        if (children.isEmpty && c.text != null) {
          text = t;
          // TODO: space deal right?
          if (t != ' ') forceInlineHeight ??= estyle(b, ref).fontSize;
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
    final inside = switch (b.e.localName) {
      'p' || 'li' => TextSpan(
        text: text,
        children: cr(children),
        style: estyle(b, ref),
      ),
      'h1' => TextSpan(
        text: text,
        children: cr(children),
        style: estyle(b, ref),
      ),
      'h2' => TextSpan(
        text: text,
        children: cr(children),
        style: estyle(b, ref),
      ),
      'h3' => TextSpan(
        text: text,
        children: cr(children),
        style: estyle(b, ref),
      ),

      'b' || 'strong' => TextSpan(
        text: text,
        children: children,
        style: const TextStyle(
          fontFamily: '.osdefault',
          fontWeight: FontWeight.bold,
        ),
      ),

      'i' || 'em' => TextSpan(
        text: text,
        children: children,
        style: const TextStyle(
          fontFamily: '.osdefault',
          fontStyle: FontStyle.italic,
        ),
      ),

      'u' => TextSpan(
        text: text,
        children: children,
        style: const TextStyle(
          fontFamily: '.osdefault',
          decoration: TextDecoration.underline,
        ),
      ),

      'span' => TextSpan(text: text, children: children, style: estyle(b, ref)),

      'img' => WidgetSpan(
        child: Image.memory(
          provider?.bytes(b.e.attributes['src'] ?? '') ?? note,
          fit: BoxFit.fitWidth,
          width: forceInlineHeight != null
              ? null
              : double.tryParse(b.e.attributes['width'] ?? ''),
          height:
              forceInlineHeight ??
              double.tryParse(b.e.attributes['height'] ?? ''),
        ),
      ),

      // svg image, just ignore it
      'image' => const TextSpan(text: '\n', style: TextStyle(fontSize: 0)),

      'a' => linkify(
        TextSpan(text: text, children: children, style: estyle(b, ref)),
        b.e.attributes['href'] ?? '',
        ref,
      ),

      'code' => TextSpan(
        children: children,
        style: TextStyle(
          fontFamily: 'monospace',
          backgroundColor: Colors.grey[200],
          color: Colors.red[800],
        ),
      ),

      'br' => const TextSpan(text: '\n', style: TextStyle(fontSize: 0)),

      _ => TextSpan(text: text, children: children),
    };

    /// force img to inline img here
    if (inside is TextSpan && inside.text != null) {
      if (inside.children != null) {
        for (var i = 0; i < inside.children!.length; i++) {
          final c = inside.children![i];
          if (c is WidgetSpan && c.child is Image) {
            print('got inline image');
          }
        }
      }
    }

    final id = b.e.attributes['id'];
    if (id == null) {
      return inside;
    }

    return WidgetSpan(child: Text.rich(inside, key: doc.newKey('#$id')));
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

  InlineSpan linkify(InlineSpan w, String href, WidgetRef ref) {
    if (w is TextSpan) {
      w = TextSpan(
        text: w.text,
        children: w.children?.map((e) => linkify(e, href, ref)).toList(),
        style: const TextStyle(
          color: Colors.blue,
          // decoration: TextDecoration.underline,
        ),
        mouseCursor: SystemMouseCursors.click,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            if (href.startsWith('#')) {
              // id => GlobalKey/context
              final key = doc.topks[href];
              if (key != null) {
                await Scrollable.ensureVisible(key.currentContext!);
              }
            }
            final url = Uri.tryParse(href);
            if (url != null && canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
        onEnter: w.onEnter,
        onExit: w.onExit,
        semanticsLabel: w.semanticsLabel,
        semanticsIdentifier: w.semanticsIdentifier,
        locale: w.locale,
        spellOut: w.spellOut,
      );
    }
    return w;
  }

  InlineSpan clickable(InlineSpan w, int index, WidgetRef ref) {
    return w is TextSpan
        ? TextSpan(
            text: w.text,
            children: w.children?.map((e) => clickable(e, index, ref)).toList(),
            recognizer: w.recognizer ?? Tapper(index, ref),
            // (TapGestureRecognizer()
            //   ..onTap = () {
            //     debugPrint('click $index');
            //     ref.read(linep.notifier).updateActive(index);
            //   }),
            style: w.style,
            mouseCursor: w.mouseCursor,
            onEnter: w.onEnter,
            onExit: w.onExit,
            semanticsLabel: w.semanticsLabel,
            semanticsIdentifier: w.semanticsIdentifier,
            locale: w.locale,
            spellOut: w.spellOut,
          )
        : w;
  }

  /// simple Element style
  TextStyle estyle(Block b, WidgetRef ref) {
    if (b.lang == Lang.zh || b.lang == Lang.jp || b.lang == Lang.kr) {
      final bfs = ref.watch(
        settingProvider.select(
          (m) => m.doubleOf('ui.zh.font-size', defaults: 18),
        ),
      );
      // print('${b.lang} font-size: $bfs');
      return TextStyle(
        fontFamily: '.osdefault',
        fontSize: switch (b.e.localName) {
          'h1' => bfs + 6,
          'h2' => bfs + 4,
          'h3' => bfs + 2,
          _ => bfs,
        },
        height: 1.55,
      );
    } else {
      final bfs = ref.watch(
        settingProvider.select(
          (m) => m.doubleOf('ui.en.font-size', defaults: 14.0),
        ),
      );
      // print('${b.lang} font-size: $bfs');
      return TextStyle(
        fontFamily: 'sans-serif',
        fontFamilyFallback: ['.osdefault'],
        fontSize: switch (b.e.localName) {
          'h1' => bfs + 6,
          'h2' => bfs + 4,
          'h3' => bfs + 2,
          _ => bfs,
        },
        height: 1.55,
      );
    }
  }
}

class Tapper extends TapGestureRecognizer {
  Tapper(this.i, this.ref) {
    onTap = tap;
  }
  final int i;
  final WidgetRef ref;
  void tap() {
    // ref.read(linep.notifier).update(i);
    onTapCancel?.call(); // is this work?
  }
}

class Doc {
  const Doc({
    required this.blocks,
    this.activeIndex,
    this.topks = const {},
    this.offset = 0,
    this.provider,
  });

  final List<Block> blocks;
  final int? activeIndex;
  final double? offset; // scroll offset
  /// top level WidgetSpan: 'index' => GlogalKey
  /// anchor: '#id' => GlogalKey
  final Map<String, GlobalKey> topks;
  final FileProvider? provider;

  factory Doc.create({
    required String html,
    int? activeIndex,
    double? offset,
    FileProvider? provider,
    Lang lang = Lang.all,
    bool detect = false,
  }) {
    final doc = dom.parse(html);
    final body = doc.body ?? dom.Element.tag('body');
    final ks = <String, GlobalKey>{};

    final bs = <Block>[];
    for (final e in unwrap(body).children) {
      Lang el = Lang.from(e.attributes['lang']);
      if (el == Lang.unknown && detect) {
        el = detectLang(e.text);
      }
      if (el != Lang.unknown && lang != Lang.all && el != lang) {
        continue;
      }

      final i = bs.length;
      bs.add(
        Block(
          i: i,
          e: e,
          key: ks.putIfAbsent('$i', () => GlobalKey()),
          selected: false,
          lang: el,
        ),
      );
    }

    return Doc(
      provider: provider,
      activeIndex: activeIndex,
      offset: offset,
      topks: ks,
      blocks: bs,
    );
  }

  Doc copyWith({
    List<Block>? blocks,
    int? activeIndex,
    double? offset,
    Map<String, GlobalKey>? topks,
    FileProvider? provider,
  }) => Doc(
    blocks: blocks ?? this.blocks,
    activeIndex: activeIndex ?? this.activeIndex,
    offset: offset ?? this.offset,
    topks: topks ?? this.topks,
    provider: provider ?? this.provider,
  );

  GlobalKey newKey(String name) {
    return topks.putIfAbsent(name, () => GlobalKey());
  }

  @override
  bool operator ==(Object other) =>
      other is Doc && identical(blocks, other.blocks);

  @override
  int get hashCode => Object.hashAll(blocks);

  @override
  String toString() =>
      'Doc(bs:${blocks.length}, a:$activeIndex, ks:${topks.length})';
}

/// HtmlWidget render mode in ListView, RichText, SliverList
/// auto, top block count > 1000 -> list
enum Mode { auto, rich, list, sliver }

class HtmlWidget extends ConsumerStatefulWidget {
  final Doc doc;
  final Mode mode;
  final ScrollController? roller;

  HtmlWidget({
    required String html,
    required this.mode,
    FileProvider? provider,
    this.roller,
    Lang lang = Lang.all,
    bool detect = false,
    super.key,
  }) : doc = Doc.create(
         html: html,
         provider: provider,
         lang: lang,
         detect: detect,
       );

  @override
  ConsumerState<HtmlWidget> createState() => _HtmlWidgetState();
}

class _HtmlWidgetState extends ConsumerState<HtmlWidget> {
  int? firstVisibleIdx;

  @override
  void initState() {
    super.initState();

    widget.roller?.addListener(_onScroll);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onScroll() {
    final obj = context.findRenderObject();
    if (obj == null || obj is! RenderBox) {
      debugPrint('in hw scroll, ${obj.runtimeType}');

      // [RenderSliverPadding]
      return;
    }

    RenderBox scrollBox = obj;

    int? idx;
    double closestTop = double.infinity;

    for (final e in widget.doc.topks.entries) {
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
      firstVisibleIdx = idx;
      ref.read(linep.notifier).update(firstVisibleIdx!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == Mode.rich) {
      final rs = <InlineSpan>[];
      for (int i = 0; i < widget.doc.blocks.length; i++) {
        rs.add(
          WidgetSpan(
            child: BlockWidget(
              doc: widget.doc,
              mode: widget.mode,
              index: i,
              provider: widget.doc.provider,
            ),
          ),
        );
        // rs.add(TextSpan(text: '\n'));
      }

      return SingleChildScrollView(
        controller: widget.roller,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(8),
          child: Text.rich(
            TextSpan(mouseCursor: SystemMouseCursors.text, children: rs),
          ),
        ),
      );
    } else if (widget.mode == Mode.list) {
      final rs = <InlineSpan>[];
      for (int i = 0; i < widget.doc.blocks.length; i++) {
        rs.add(
          WidgetSpan(
            child: BlockWidget(
              doc: widget.doc,
              mode: widget.mode,
              index: i,
              provider: widget.doc.provider,
            ),
          ),
        );
      }
      return Scrollbar(
        controller: widget.roller,
        child: ListView.builder(
          controller: widget.roller,
          padding: EdgeInsets.all(8),
          itemCount: rs.length,
          itemBuilder: (contex, i) => Text.rich(rs[i]),
        ),
      );
    } else if (widget.mode == Mode.sliver) {
      final rs = <InlineSpan>[];
      for (int i = 0; i < widget.doc.blocks.length; i++) {
        rs.add(
          WidgetSpan(
            child: BlockWidget(
              doc: widget.doc,
              mode: widget.mode,
              index: i,
              provider: widget.doc.provider,
            ),
          ),
        );
      }
      return SliverPadding(
        padding: EdgeInsetsGeometry.all(8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (countext, i) => Text.rich(rs[i]),
            childCount: rs.length,
          ),
        ),
      );
    }
    return Center();
  }
}

class LineNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void update(int? activeIndex) {
    state = activeIndex;
  }
}

// final docp = Provider<Doc>((ref) => throw UnimplementedError('docp'));
final linep = NotifierProvider<LineNotifier, int?>(
  LineNotifier.new,
  name: 'CurrentLine',
);

const wrapperTags = {
  'section',
  'div',
  'article',
  'main',
  'header',
  'footer',
  // 'svg',
  'aside',
  'figure',
  // 'body',
};

dom.Element unwrap(dom.Element element) {
  // Recursively process children first (depth-first traversal)
  for (var child in List.from(element.children)) {
    unwrap(child);
  }

  // If the element is a container/wrapper, unwrap it by moving its children to its parent
  if (wrapperTags.contains(element.localName)) {
    var parent = element.parent;
    if (parent != null) {
      int index = parent.nodes.indexOf(element);
      for (var child in List.from(element.nodes)) {
        parent.nodes.insert(index++, child);
      }
      element.remove();
    }
  }
  return element;
}

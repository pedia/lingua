import 'dart:isolate';
import 'dart:typed_data';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as dom;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/sample.dart';

bool canLaunchUrl(Uri _) => false;
Future<void> launchUrl(Uri _) => Future.value();

abstract class FileProvider {
  Uint8List bytes(String path);
}

@immutable
class Block {
  const Block({
    required this.i,
    required this.key,
    required this.selected,
    required this.e,
  });
  // clickable
  final int i; // index from Doc.blocks
  final GlobalKey key;
  final bool selected;
  final dom.Element e;

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

  Block copyWith({int? i, GlobalKey? key, bool? selected, dom.Element? e}) =>
      Block(
        i: i ?? this.i,
        key: key ?? this.key,
        selected: selected ?? this.selected,
        e: e ?? this.e,
      );
}

class BlockWidget extends ConsumerWidget {
  final int index;
  final FileProvider? provider;
  const BlockWidget({super.key, required this.index, this.provider});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint("🟢 Building BlockWidget[$index]");
    final b = ref.watch(docp.select((doc) => doc.blocks[index]));

    return Text.rich(
      clickable(trans(b.e, ref), b.i, ref),
      key: b.key,
      // CASE: selection style
      style: b.selected
          ? TextStyle(
              backgroundColor:
                  TextSelectionTheme.of(context).selectionColor ??
                  Colors.blue.withValues(alpha: 0.4),
            )
          : null,
    );
  }

  /// Translate or transform html tag into InlineSpan
  /// force img height
  /// <p><sup><a><img></a></p>
  InlineSpan trans(dom.Element e, WidgetRef ref, {double? forceInlineHeight}) {
    // 1. Recursively parse all child nodes (text and nested tags)
    List<InlineSpan>? children = [];
    String? text;
    for (var c in e.nodes) {
      if (c is dom.Element) {
        // Recursive call for nested elements
        children.add(trans(c, ref, forceInlineHeight: forceInlineHeight));
      } else if (c.nodeType == dom.Node.TEXT_NODE) {
        final t = _removeUnnecessaryWhitespace(c.text ?? '');
        if (children.isEmpty && c.text != null) {
          text = t;
          // TODO: space deal right?
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
        style: const TextStyle(
          fontFamily: '.osdefault',
          fontSize: 16.0,
          height: 1.55,
        ),
      ),
      'h1' => TextSpan(
        text: text,
        children: children,
        style: const TextStyle(
          fontFamily: '.osdefault',
          fontSize: 32.0,
          height: 1.55,
        ),
      ),
      'h2' => TextSpan(
        text: text,
        children: children,
        style: const TextStyle(
          fontFamily: '.osdefault',
          fontSize: 24.0,
          height: 1.55,
        ),
      ),
      'h3' => TextSpan(
        text: text,
        children: children,
        style: const TextStyle(
          fontFamily: '.osdefault',
          fontSize: 18.0,
          height: 1.55,
        ),
      ),

      'b' || 'strong' => TextSpan(
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

      'span' => TextSpan(
        text: text,
        children: children,
        style: const TextStyle(
          fontFamily: '.osdefault',
          fontSize: 16.0,
          height: 1.55,
        ),
      ),

      'img' => WidgetSpan(
        child: Image.memory(
          provider?.bytes(e.attributes['src'] ?? '') ?? note,
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
        TextSpan(
          text: text,
          children: children,
          style: const TextStyle(
            fontFamily: '.osdefault',
            fontSize: 16.0,
            height: 1.55,
          ),
        ),
        e.attributes['href'] ?? '',
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

      'br' => const TextSpan(text: '\n'),

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

    final id = e.attributes['id'];
    if (id == null) {
      return inside;
    }

    return WidgetSpan(
      child: Text.rich(inside, key: ref.read(docp).newKey('#$id')),
    );
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
          decoration: TextDecoration.underline,
        ),
        mouseCursor: SystemMouseCursors.click,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            if (href.startsWith('#')) {
              // id => GlobalKey/context
              final key = ref.read(docp).topks[href];
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
            recognizer:
                w.recognizer ??
                (TapGestureRecognizer()
                  ..onTap = () {
                    // TODO: widget.clicklNotify?.call(index));
                    print('click $index');
                    ref.read(docp.notifier).updateActive(index);
                  }),
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

  double fontSize(String tag) => switch (tag) {
    'h1' => 32,
    'h2' => 24,
    'h3' => 18,
    _ => 18,
  };
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
  }) {
    final doc = dom.parse(html);
    final body = doc.body ?? dom.Element.tag('body');
    body.children.length;
    final ks = <String, GlobalKey>{};
    return Doc(
      provider: provider,
      activeIndex: activeIndex,
      offset: offset,
      topks: ks,
      blocks: [
        for (int i = 0; i < body.children.length; i++)
          Block(
            i: i,
            e: body.children[i],
            key: ks.putIfAbsent('$i', () => GlobalKey()),
            selected: false,
          ),
      ],
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
  String toString() =>
      'Doc(bs:${blocks.length}, a:$activeIndex, ks:${topks.length})';
}

class DocWidget extends ConsumerStatefulWidget {
  final Mode mode;
  const DocWidget({required this.mode, super.key});

  @override
  ConsumerState<DocWidget> createState() => _DocWidgetState();
}

class _DocWidgetState extends ConsumerState<DocWidget> {
  final roller = ScrollController();
  int? firstVisibleIdx;
  double? offset;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // if (widget.initialIndex != 0) {
      //   final key = doc?.topks['${widget.initialIndex}'];
      //   if (key != null && key.currentContext != null) {
      //     Scrollable.ensureVisible(key.currentContext!);
      //   }
      // }
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
    final doc = ref.read(docp);

    for (final e in doc.topks.entries) {
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
      // print(
      //   'onScroll ${roller.offset.toStringAsFixed(2)}, First visible block: $idx',
      // );
      firstVisibleIdx = idx;
    }

    // widget.scrollNotify?.call(roller.offset, firstVisibleIdx ?? 0);
    offset = roller.offset;
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(docp);
    debugPrint(
      "🟢 Building DocWidget provider:${doc.provider} block:${doc.blocks.length}",
    );

    if (widget.mode == Mode.rich) {
      final rs = <InlineSpan>[];
      for (int i = 0; i < doc.blocks.length; i++) {
        rs.add(
          WidgetSpan(
            child: BlockWidget(index: i, provider: doc.provider),
          ),
        );
        rs.add(TextSpan(text: '\n'));
      }

      return SingleChildScrollView(
        controller: roller,
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
      for (int i = 0; i < doc.blocks.length; i++) {
        rs.add(
          WidgetSpan(
            child: BlockWidget(index: i, provider: doc.provider),
          ),
        );
      }
      return Scrollbar(
        controller: roller,
        child: ListView.builder(
          controller: roller,
          padding: EdgeInsets.all(8),
          itemCount: rs.length,
          itemBuilder: (contex, i) => Text.rich(rs[i]),
        ),
      );
    }
    return Center();
  }
}

class DocNotifier extends Notifier<Doc> {
  // DocNotifier(this.doc);
  // final Doc doc;
  @override
  Doc build() {
    return Doc(blocks: []);
  }

  void update(String html, FileProvider provider) {
    state = Doc.create(html: html, provider: provider);
  }

  void updateActive(int activeIndex) {
    if (activeIndex > state.blocks.length - 1) {
      debugPrint('out of range: $activeIndex, current: ${state.blocks.length}');
      return;
    }

    final nl = List<Block>.from(state.blocks);
    nl[activeIndex] = nl[activeIndex].copyWith(selected: true);
    if (state.activeIndex != null) {
      nl[state.activeIndex!] = nl[state.activeIndex!].copyWith(selected: false);
    }
    state = state.copyWith(activeIndex: activeIndex, blocks: nl);
  }
}

// final docp = Provider<Doc>((ref) => throw UnimplementedError('docp'));
final docp = NotifierProvider<DocNotifier, Doc>(DocNotifier.new);

class WithDocNotifier extends DocNotifier {
  WithDocNotifier(this.doc);
  final Doc doc;

  @override
  Doc build() {
    return doc;
  }
}

/// HtmlWidget render mode in ListView, RichText, SliverList
/// auto, top block count > 1000 -> list
enum Mode { auto, rich, list, silver }

// not used now
final parsedHtmlProvider = FutureProvider.family<Doc, String>((
  ref,
  html,
) async {
  return await Isolate.run(() => Doc.create(html: html));
});

class HtmlWidget extends ConsumerWidget {
  const HtmlWidget(
    this.html, {
    this.mode = Mode.rich,
    this.provider,
    super.key,
  });
  final String html;
  final Mode mode;
  final FileProvider? provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // return DocWidget(mode: mode);
    return ProviderScope(
      overrides: [
        // for first time
        docp.overrideWith(
          () => WithDocNotifier(Doc.create(html: html, provider: provider)),
        ),
      ],
      child: DocWidget(mode: mode),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../ui/chapter_list.dart' as legacy;
import '../ui/book.dart' as legacy;
import '../tts/engine.dart' as tts;
import '../tts/voice.dart' as tts;
import '../settings/setting.dart';
import '../zh/fix.dart';
import '../imap.dart';
import '../log.dart';

import 'chunk.dart';

int min(int a, int b) {
  return a > b ? b : a;
}

class ReadScreen extends ConsumerStatefulWidget {
  const ReadScreen(this.id, this.book, {super.key});
  final int id;
  final Book book;

  @override
  ConsumerState<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends ConsumerState<ReadScreen> {
  bool _isAppBarVisible = true;
  final _roller = ScrollController();
  final double _appBarHeight = 56.0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  int initialDrawerIndex = 0;

  @override
  void initState() {
    super.initState();
    _roller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_roller.hasClients) {
        final offset = ref.read(legacy.isp(widget.id).select((o) => o.offset));
        _roller.jumpTo(offset);
      }
    });
  }

  @override
  void dispose() {
    _roller.removeListener(_onScroll);
    _roller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_roller.position.userScrollDirection == ScrollDirection.reverse) {
      // Scrolling down -> Hide AppBar
      if (_isAppBarVisible) {
        setState(() => _isAppBarVisible = false);
      }
    } else if (_roller.position.userScrollDirection ==
        ScrollDirection.forward) {
      // Scrolling up -> Show AppBar
      if (!_isAppBarVisible) {
        setState(() => _isAppBarVisible = true);
      }
    }

    ref.read(legacy.isp(widget.id).notifier).update(offset: _roller.offset);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final totalAppBarHeight = _appBarHeight + topPadding;

    final ci = ref.watch(
      legacy.isp(widget.id).select((o) => o.readChapterIndex),
    );
    final ch = widget.book.chapters[ci];
    ref.listen(legacy.isp(widget.id), (prev, next) {
      if (_roller.hasClients &&
          next.readChapterIndex != prev?.readChapterIndex) {
        _roller.jumpTo(0.0);
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        width: 280,
        child: legacy.TheDrawer(
          widget.id,
          widget.book,
          initialIndex: initialDrawerIndex,
        ),
      ),
      body: Stack(
        children: [
          // 1. Scrollable Body, force show on Android
          Scrollbar(
            controller: _roller,
            child: ContentView(
              chapter: widget.book.chapters[ci],
              controller: _roller,
              padding: EdgeInsets.fromLTRB(8, totalAppBarHeight + 8, 8, 8),
            ),
          ),

          // 2. Sliding Top AppBar / Header
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            top: _isAppBarVisible ? 0 : -totalAppBarHeight,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: topPadding),
              height: totalAppBarHeight,
              color: Theme.of(context).primaryColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    ch.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // 3. Always-showing bottom buttons panel
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(
          left: 16.0,
          right: 16,
          top: 0.0,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  setState(() => initialDrawerIndex = 0);
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  setState(() => initialDrawerIndex = 1);
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => context.push('/edit/${widget.id}'),
              ),
              ...speakButtons(),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.push('/setting'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void applyVoice(BuildContext context) {
    final m = ref.read(settingProvider);

    debugPrint('in apply got setting: $m');

    final vs = [
      if (m.has('tts.en'))
        tts.EngineSetting.from(Lang.en, m.objectOf('tts.en')),
      if (m.has('tts.zh'))
        tts.EngineSetting.from(Lang.zh, m.objectOf('tts.zh')),
    ];
    ref.read(tts.engineProvider.notifier).apply(vs);
  }

  void play() async {
    final setlang = ref.read(
      settingProvider.select((m) => m.stringOf('tts.mode')),
    );
    final state = ref.read(legacy.isp(widget.id));

    var it = widget.book.chapters[state.readChapterIndex].chunks
        .where(
          (c) =>
              (setlang == '' || c.lang == Lang.from(setlang)) && c is! Picture,
        )
        .imap((i, e) => e.copyWith(idx: i));

    if (state.speakChapterIndex == state.readChapterIndex) {
      it = it.skip(state.speakLine);
    }

    final lines = it.map((c) => c.process()).toList();

    logger.log('lines for $setlang $state');
    for (int i = 0; i < lines.length; i++) {
      logger.log('$i: ${lines[i].speak}');
      if (i > 2) {
        break;
      }
    }

    final es = ref.read(tts.engineProvider.notifier);

    applyVoice(context);
    es.play(lines);

    ref
        .read(legacy.isp(widget.id).notifier)
        .update(speakChapterIndex: state.readChapterIndex);
  }

  List<Widget> speakButtons() {
    ref.listen(tts.engineProvider, (prev, next) {
      if (next.isPlaying && next.currentIndex != null) {
        final idx = next.chunks[next.currentIndex!].idx;
        print('playback chunk $idx');
        ref.read(legacy.isp(widget.id).notifier).update(speakLine: idx);
      }
    });

    final es = ref.watch(tts.engineProvider);
    return [
      if (!es.isPlaying)
        IconButton(icon: const Icon(Icons.hearing), onPressed: play),
      if (es.isPlaying)
        IconButton(
          icon: const Icon(Icons.stop),
          tooltip: '${es.currentIndex}',
          onPressed: () async {
            ref.read(tts.engineProvider.notifier).stop();
          },
        ),

      if (es.isPlaying)
        IconButton(
          icon: const Icon(Icons.fast_forward),
          onPressed: () => ref.read(tts.engineProvider.notifier).skip(10),
        ),

      if (es.isPlaying) progress(context),
    ];
  }

  Widget progress(BuildContext context) {
    final s = ref.watch(legacy.isp(widget.id));
    // final l = ref.watch(linep);
    return Text(
      ' ${s.speakLine}/${widget.book.chapters[s.readChapterIndex].chunks.length} ',
    );
  }

  AdaptiveTextSelectionToolbar selectToolbar(
    BuildContext context,
    SelectableRegionState editableTextState,
  ) {
    // find `copy`
    final cp = editableTextState.contextMenuButtonItems
        .where((i) => i.type == ContextMenuButtonType.copy)
        .first;
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: [
        cp.copyWith(
          label: 'Hightlight',
          type: ContextMenuButtonType.custom,
          onPressed: () {
            cp.onPressed?.call();

            Clipboard.getData(Clipboard.kTextPlain).then((data) {
              final String? selectedText = data?.text;

              int ci = ref.watch(
                legacy.isp(widget.id).select((o) => o.readChapterIndex),
              );
              if (selectedText != null) {
                legacy.newNote(
                  widget.id,
                  legacy.Note(ci: ci, note: selectedText),
                );
              }
            });
          },
        ),
        ...editableTextState.contextMenuButtonItems, // Copy, Select all, …
      ],
    );
  }
}

class ContentView extends ConsumerWidget {
  const ContentView({
    required this.chapter,
    this.controller,
    this.padding,
    super.key,
  });
  final Chapter chapter;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: chapter.chunks.length,
      itemBuilder: (context, i) => tile(chapter.chunks[i], ref),
    );
  }

  /// list tile
  Widget tile(Chunk c, WidgetRef ref) {
    if (c is Picture) {
      return Image.memory(blue, fit: BoxFit.fitWidth);
    }
    return Text.rich(
      TextSpan(
        text: c.text,
        style: TextStyle(
          fontFamily: '.osdefault',
          fontSize: fontSize(c, ref),
          height: 1.5,
        ),
        children: c.spans.map(inline).toList(),
      ),
    );
  }

  double fontSize(Chunk c, WidgetRef ref) {
    final key = (c.lang == Lang.zh || c.lang == Lang.jp || c.lang == Lang.kr)
        ? 'ui.zh.font-size'
        : 'ui.en.font-size';
    return ref.watch(
          settingProvider.select((m) => m.doubleOf(key, defaults: 18)),
        ) +
        (c.strong ? 2 : 0);
  }

  InlineSpan block(Chunk c) {
    // print('${c.lang} ${c.text} ${c.spans}');
    if (c is Picture) {
      return WidgetSpan(child: Image.memory(blue));
    }

    if (c.text != null) {
      return TextSpan(
        text: '${c.text}\n',
        style: c.strong
            ? const TextStyle(
                fontFamily: '.osdefault',
                fontSize: 20.0,
                height: 1.6,
              )
            : null,
      );
    }

    final cs = c.spans.map(inline).toList()
      ..add(TextSpan(text: '\n', style: TextStyle(fontSize: 0)));
    return TextSpan(children: cs);
  }

  InlineSpan inline(Span p) {
    if (p is Anchor) {
      return TextSpan(
        text: p.text,
        style: const TextStyle(color: Colors.blue),
      );
    }
    return TextSpan(text: p.text);
  }
}

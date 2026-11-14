import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../ui/chapter_list.dart' as legacy;
import '../ui/book.dart' as legacy;
import '../imap.dart';
import '../tts/engine.dart' as tts;
import '../tts/voice.dart' as tts;
import '../settings/setting.dart';

import 'chunk.dart';

class ReadScreen extends ConsumerStatefulWidget {
  const ReadScreen(this.id, this.book, {super.key});
  final int id;
  final Book book;

  @override
  ConsumerState<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends ConsumerState<ReadScreen> {
  bool _isAppBarVisible = true;
  late final ScrollController _roller;
  final double _appBarHeight = 56.0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  int initialDrawerIndex = 0;

  @override
  void initState() {
    super.initState();
    _roller = ScrollController();
    _roller.addListener(_onScroll);
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
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final totalAppBarHeight = _appBarHeight + topPadding;

    final ci = ref.watch(
      legacy.isp(widget.id).select((o) => o.readChapterIndex),
    );
    final ch = widget.book.chapters[ci];

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
          // 1. Scrollable Body (SingleChildScrollView with top padding so content isn't hidden under AppBar)
          SingleChildScrollView(
            controller: _roller,
            padding: EdgeInsets.fromLTRB(
              16.0,
              totalAppBarHeight + 16.0,
              16.0,
              16.0,
            ),
            child: ChapterView(widget.book.chapters[ci]),
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: Colors.white,
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
    final lang = ref.read(
      settingProvider.select((m) => m.stringOf('tts.mode')),
    );

    final state = ref.read(legacy.isp(widget.id));
    var it = widget.book.chapters[state.readChapterIndex].chunks.where(
      (c) => lang == '' || c.lang == Lang.from(lang),
    );

    if (state.speakChapterIndex == state.readChapterIndex) {
      it = it.skip(state.speakLine);
    }

    final lines = it.toList();

    print('lines for $lang $state');
    print(lines.sublist(0, 2));

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
    ];
  }

  Widget progress(BuildContext context) {
    final s = ref.watch(legacy.isp(widget.id));
    // final l = ref.watch(linep);
    return Text('${s.speakLine} - 0');
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

class ChapterView extends StatelessWidget {
  const ChapterView(this.chapter, {super.key});
  final Chapter chapter;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: '.osdefault',
          fontSize: 16.0,
          color: Colors.black87,
          height: 1.5,
        ),
        children: chapter.chunks
            .imap(
              (i, c) => TextSpan(
                text: c.text != null ? '${c.text}\n' : 'TODO $c',
                style: TextStyle(
                  fontWeight: i % 5 == 0 ? FontWeight.bold : FontWeight.normal,
                  color: i % 3 == 0 ? Colors.indigo : Colors.black87,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

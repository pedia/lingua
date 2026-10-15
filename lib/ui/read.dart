import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../epub/epub.dart' as epub;
import 'book.dart';
import 'gadget.dart';
import '../hw.dart';
import '../g.dart';
import 'chapter_list.dart';
import '../tts/dualtts.dart';
import '../settings/setting.dart';
import '../epub/lang.dart';

/// Material Silver Style Reader
class ReadFrame extends ConsumerStatefulWidget {
  const ReadFrame({required this.id, super.key});
  final int id;

  @override
  ConsumerState<ReadFrame> createState() => _ReadFrameState();
}

class _ReadFrameState extends ConsumerState<ReadFrame> {
  final roller = ScrollController();

  late StreamSubscription sub;
  late epub.Book book;

  @override
  void initState() {
    super.initState();

    sub = dt.stream.listen((pp) {
      debugPrint('$pp');
      if (mounted) {
        // setState(() {
        //   playback = pp.$1;
        // });
      }
    });
  }

  @override
  void dispose() {
    dt.dispose();
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ci change, scroll to top
    ref.listen(isp(widget.id).select((s) => s.read.ci), (p, n) {
      if (n != p && roller.hasClients) {
        roller.jumpTo(0);
      }
    });

    // save current progress
    ref.listen(linep, (prev, next) {
      if (next != null && next != prev) {
        ref.read(isp(widget.id).notifier).updateRead(lineIndex: next);
      }
    });

    final ab = ref.watch(bookProvider(widget.id));
    return AsyncValueX(ab).when(
      data: (book) {
        if (book == null) {
          return ErrScreen('Unable to open item:${widget.id}');
        }
        this.book = book;
        return builds(context, book);
      },
      loading: () => const Center(), // TODO: better solution
      error: (err, stackTrace) {
        print(stackTrace);
        return ErrScreen('Unable to open it\n$err');
      },
    );
  }

  final dt = DualTts();

  List<epub.Chunk> get lines {
    final lang = ref.read(
      settingProvider.select((m) => m.stringOf('tts.mode')),
    );
    final chi = ref.read(isp(widget.id)).read.ci;
    return book.chapters[chi].chunks
        .where((line) => lang == '' || line.lang == lang)
        .toList();
  }

  Future applyVoice(BuildContext context) {
    final m = ProviderScope.containerOf(context).read(settingProvider);

    // debugPrint('in apply got setting: $m');
    // print(m.has('tts.en'));

    final vs = [
      if (m.has('tts.en')) EngineSetting.from('en', m.objectOf('tts.en')),
      if (m.has('tts.zh')) EngineSetting.from('zh', m.objectOf('tts.zh')),
    ];
    return dt.apply(vs).then((x) => debugPrint('dualtts inited ${vs.length}'));
  }

  void play() async {
    final lang = ref.read(
      settingProvider.select((m) => m.stringOf('tts.mode')),
    );
    final chi = ref.read(isp(widget.id)).read.ci;
    final lines = book.chapters[chi].chunks
        .where((c) => lang == '' || c.lang == lang)
        .toList();

    if (!dt.inited) {
      await applyVoice(context);
    }
    final start = ref.read(linep) ?? 0;
    dt.load(lines.sublist(start));
    dt.play();
  }

  int initialDrawerIndex = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Widget builds(BuildContext context, epub.Book book) {
    if (book.chapters.isEmpty) {
      return ErrScreen('Book is empty');
    }
    int ci = ref.watch(isp(widget.id).select((o) => o.read.ci));
    if (ci > book.chapters.length - 1) {
      print('Warning: ci:$ci is wrong ${book.chapters.length}');
      ci = 0;
    }
    final ch = book.chapters[ci];
    return FullScreen(
      on: false,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: Drawer(
          width: 280,
          child: TheDrawer(widget.id, book, initialIndex: initialDrawerIndex),
        ),
        body: SelectableRegion(
          focusNode: FocusNode(),
          selectionControls: materialTextSelectionHandleControls,
          contextMenuBuilder: selectToolbar,
          child: CustomScrollView(
            restorationId: 'read-${widget.id}-$ci',
            controller: roller,
            slivers: [
              SliverAppBar(
                /// CASE:
                title: SelectionContainer.disabled(child: Text(ch.title)),
                // Disappears on scroll down, reveals immediately on scroll up
                floating: true,
                // Snaps fully open with a slight upward swipe (highly recommended)
                snap: true,
                // Set to false so it completely hides when scrolling down
                pinned: false,
                elevation: 2.0,
                systemOverlayStyle: SystemUiOverlayStyle(),
              ),
              HtmlWidget(
                html: ch.content,
                mode: Mode.sliver,
                roller: roller,
                provider: ArchiveProvider(ch.href, book.files),
                lang: ref.watch(
                  settingProvider.select(
                    (m) => Lang.from(m.stringOf('ui.mode')),
                  ),
                ),
                detect: ref.watch(
                  settingProvider.select((m) => m.flag('detect')),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                ...speak(),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => context.push('/setting'),
                ),

                // ElevatedButton(onPressed: () {}, child: Text('$playback')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> speak() {
    final pb = ref.watch(spsp.select((p) => p.$1));
    return [
      if (pb == Playback.stop)
        IconButton(icon: const Icon(Icons.hearing), onPressed: play),
      if (pb != Playback.stop)
        IconButton(icon: const Icon(Icons.stop), onPressed: dt.stop),
      if (pb != Playback.stop)
        IconButton(
          icon: const Icon(Icons.forward_10),
          onPressed: () => dt.skip(10),
        ),
    ];
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

              int ci = ref.watch(isp(widget.id).select((o) => o.read.ci));
              if (selectedText != null) {
                newNote(widget.id, Note(ci: ci, note: selectedText));
              }
            });
          },
        ),
        ...editableTextState.contextMenuButtonItems, // Copy, Select all, …
      ],
    );
  }
}

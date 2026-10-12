import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../epub/epub.dart' as epub;
import 'book.dart';
import 'gadget.dart';
import '../hw.dart';
import 'chapter_list.dart';
import '../tts/dualtts.dart';
import '../settings/setting.dart';

/// Material Silver Style Reader
class ReadFrame extends ConsumerStatefulWidget {
  ReadFrame({required this.id, super.key});
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
        setState(() {
          playback = pp.$1;
        });
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
        print(stackTrace.toString().substring(0, 1000));
        return ErrScreen('Unable to open it\n$err');
      },
    );
  }

  final dt = DualTts();
  Playback playback = Playback.stop;

  List<epub.Chunk> get lines {
    final lang = ref.read(settingProvider.select((m) => m.stringOf('ui.lang')));
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
        drawer: Drawer(width: 280, child: ChapterList(widget.id, book)),
        body: SelectableRegion(
          selectionControls: materialTextSelectionHandleControls,
          contextMenuBuilder: selectToolbar,
          child: CustomScrollView(
            restorationId: 'read-${widget.id}-$ci',
            controller: roller,
            slivers: [
              SliverAppBar(
                title: Text(ch.title),
                // Disappears on scroll down, reveals immediately on scroll up
                floating: true,
                // Snaps fully open with a slight upward swipe (highly recommended)
                snap: true,
                // Set to false so it completely hides when scrolling down
                pinned: false,
                elevation: 2.0,
                systemOverlayStyle: SystemUiOverlayStyle(),
                actions: [
                  IconButton(
                    tooltip: switch (playback) {
                      Playback.stop => 'Play',
                      _ => 'Stop',
                    },
                    icon: Icon(switch (playback) {
                      Playback.stop => Icons.play_arrow_rounded,
                      _ => Icons.stop_rounded,
                    }),
                    onPressed: () async {
                      if (playback.isPlaying) {
                        dt.stop();
                      } else {
                        if (!dt.inited) {
                          await applyVoice(context);
                        }
                        final start = ref.read(linep) ?? 0;
                        dt.load(lines.sublist(start));
                        dt.play();
                      }
                    },
                  ),
                ],
              ),
              HtmlWidget(
                html: ch.content,
                mode: Mode.sliver,
                roller: roller,
                provider: ArchiveProvider(ch.href, book.files),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
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
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => context.push('/edit/${widget.id}'),
                ),
                IconButton(
                  icon: const Icon(Icons.hearing),
                  onPressed: () => context.push('/edit/${widget.id}'),
                ),
                ElevatedButton(onPressed: () {}, child: const Text('Checkout')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AdaptiveTextSelectionToolbar selectToolbar(
    BuildContext context,
    SelectableRegionState editableTextState,
  ) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: [
        ...editableTextState.contextMenuButtonItems, // Copy, Select all, …
        ContextMenuButtonItem(
          label: 'Highlight',
          onPressed: () {
            final value = editableTextState.textEditingValue;
            final sel = value.selection;
            if (!sel.isValid || sel.isCollapsed) return;
            final selected = value.text.substring(sel.start, sel.end);
            debugPrint('Highlight: $selected');
            ContextMenuController.removeAny();
          },
        ),
      ],
    );
  }
}

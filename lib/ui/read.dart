import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../epub/epub.dart' as epub;
import 'book.dart';
import 'gadget.dart';
import '../g.dart';
import '../hw.dart';
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
  late final ScrollController roller;

  StreamSubscription? sub;
  late epub.Book book;

  @override
  void initState() {
    super.initState();

    // sub = DualTts.instance().stream.listen((pp) {
    //   debugPrint('$pp');
    //   if (pp.$1 == Playback.startLine) {
    //     ref.read(isp(widget.id).notifier).update(speakLine: pp.$2);
    //   }
    // });

    roller = ScrollController(
      initialScrollOffset: ref.read(isp(widget.id)).offset,
    );
  }

  @override
  void dispose() {
    roller.dispose();
    sub?.cancel();
    DualTts.instance().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AsyncValueX(ref.watch(bookProvider(widget.id))).when(
        data: (book) {
          if (book == null) {
            return InfoScreen('Unable to open item:${widget.id}');
          }
          this.book = book;
          return builds(context, book);
        },
        loading: () => const Center(), // TODO: better solution
        error: (err, stackTrace) {
          print(stackTrace);
          return InfoScreen('Unable to open it\n$err');
        },
      );

  Future applyVoice(BuildContext context) {
    final m = ProviderScope.containerOf(context).read(settingProvider);

    debugPrint('in apply got setting: $m');

    final vs = [
      if (m.has('tts.en')) EngineSetting.from(Lang.en, m.objectOf('tts.en')),
      if (m.has('tts.zh')) EngineSetting.from(Lang.zh, m.objectOf('tts.zh')),
    ];
    return DualTts.instance()
        .apply(vs)
        .then((x) => debugPrint('dualtts inited ${vs.length}'));
  }

  void play() async {
    final lang = ref.read(
      settingProvider.select((m) => m.stringOf('tts.mode')),
    );
    final state = ref.read(isp(widget.id));
    final lines = book.chapters[state.readChapterIndex].chunks
        .where((c) => lang == '' || c.lang == Lang.from(lang))
        .skip(state.speakLine)
        .toList();
    print('lines for $lang $state');
    print(lines.sublist(0, 2));

    if (!DualTts.instance().inited) {
      await applyVoice(context);
    }

    DualTts.instance().load(lines);
    DualTts.instance().play();
  }

  int initialDrawerIndex = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Widget builds(BuildContext context, epub.Book book) {
    if (book.chapters.isEmpty) {
      return InfoScreen('Book is empty');
    }

    /// keep new chapter offset is 0
    ref.listen(isp(widget.id), (prev, next) {
      if (roller.hasClients &&
          next.readChapterIndex != prev?.readChapterIndex) {
        roller.jumpTo(0.0);
      }
    });

    final ci = ref.watch(isp(widget.id).select((o) => o.readChapterIndex));
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
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (notification) {
              if (roller.hasClients) {
                ref.read(isp(widget.id).notifier).update(offset: roller.offset);
              }
              return true;
            },
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
                  systemOverlayStyle: SystemUiOverlayStyle(), // not work
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
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 4.0,
            bottom: 8.0,
          ),
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
                ...speakButtons(),
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

  List<Widget> speakButtons() {
    final pb = ref.watch(spsp.select((p) => p.$1));
    return [
      if (pb == Playback.stop)
        IconButton(icon: const Icon(Icons.hearing), onPressed: play),
      if (pb != Playback.stop)
        IconButton(
          icon: const Icon(Icons.stop),
          onPressed: () async {
            await DualTts.instance().stop();
          },
        ),
      IconButton(
        icon: const Icon(Icons.stop),
        onPressed: () async {
          await DualTts.instance().stop();
        },
      ),
      if (pb != Playback.stop)
        IconButton(
          icon: const Icon(Icons.fast_forward),
          onPressed: () => DualTts.instance().skip(10),
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

              int ci = ref.watch(
                isp(widget.id).select((o) => o.readChapterIndex),
              );
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

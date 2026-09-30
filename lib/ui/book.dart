import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;

import '../settings/setting.dart';
import 'setting.dart';
import 'voice_setting.dart';
import 'font.dart';
import '../hw.dart';
import 'chapter_list.dart';
import '../data/model.dart';
import '../epub/epub.dart' as epub;
import '../tts/dualtts.dart';
import 'state.dart';

class ArchiveProvider extends FileProvider {
  ArchiveProvider(String base, this.files) : base = Uri(path: base);
  final Uri base;
  final Map<String, ArchiveFile> files;

  @override
  Uint8List bytes(String path) {
    debugPrint('$path => ${base.resolve(path).path}');
    final fp = base.resolve(path).path.toLowerCase();
    return files[fp]?.content ?? Uint8List.fromList([]);
  }
}

class BookFrame extends ConsumerStatefulWidget {
  const BookFrame({required this.book, required this.id, super.key});
  final epub.Book book;
  final int id;

  @override
  ConsumerState<BookFrame> createState() => _BookFrameState();
}

class _BookFrameState extends ConsumerState<BookFrame> {
  Playback playbackState = Playback.stop;
  bool get isPlaying =>
      playbackState == Playback.pause || playbackState.isPlaying;
  final dt = DualTts();
  final roller = ScrollController();
  dom.Document? doc;

  @override
  void didUpdateWidget(BookFrame oldWidget) {
    super.didUpdateWidget(oldWidget);

    // TODO: if (widget.progress != oldWidget.progress) {}
  }

  /// CASE: avoid using ref in initState
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _initialized = true;

      // ✅ Safe to use ref here
      // lang = ref.read(settingProvider.select((m) => m.stringOf('ui.lang')));
    }
  }

  /// CASES: save/restore scroll offset, include
  /// - addPostFrameCallback
  /// - ScrollController.addListener
  /// - dispose Future
  late final ItemListNotifier _itemsProvider;
  late StreamSubscription sub;

  @override
  void initState() {
    super.initState();

    // CASE:
    // Not work here(in initState). Move into didChangeDependencies
    // lang = ref.watch(settingProvider.select((m) => m.stringOf('ui.lang')));

    // setState(() => doc = dom.parse(chapter.content));

    // safe here
    _itemsProvider = ref.read(itemsProvider.notifier);

    sub = dt.stream.listen(_onTts);

    // Set drawer opened at first time frame appear
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // if (ref.read(readpp).$1 == 0) {
      //   _scaffoldKey.currentState?.openDrawer();
      // }
    });
  }

  epub.Chapter get chapter => widget.book.chapters[ref.read(readpp).$1];

  @override
  void dispose() {
    Future(() {
      /// Save progress with newest scroll offset
      // _itemsProvider.update(widget.id, progress: _progress);
      // ref.read(readpp).$1
    });

    sub.cancel();

    roller.dispose();

    super.dispose();
  }

  void _onTts((Playback, int) m) {
    if (!mounted) {
      return;
    }

    // final doc = ProviderScope.containerOf(context).read(docp);
    // debugPrint('demo $doc');
    // ref.read(docp);

    debugPrint('got dts notify $m');

    // next chapter
    if (playbackState.isPlaying &&
        m.$1 == Playback.stop &&
        m.$2 + 1 == lines.length) {
      print('speak, try next chapter ${lines.length}');
      // if (_progress.chapterIndex + 1 < widget.book.chapters.length) {
      //   setState(
      //     () => _progress = Progress(chapterIndex: _progress.chapterIndex + 1),
      //   );

      /// not set `playbackState`
      return;
    }

    if (m.$1 != playbackState) {
      setState(() => playbackState = m.$1);
    }

    // if (m.$1.isPlaying) {
    //   setState(() => _progress = _progress.copyWith(lineIndex: m.$2));
    // }
  }

  List<epub.Chunk> get lines {
    final lang = ref.read(settingProvider.select((m) => m.stringOf('ui.lang')));
    final chi = ref.read(readpp).$1;
    return widget.book.chapters[chi].chunks
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
  @override
  Widget build(BuildContext context) {
    final fs = ref.watch(
      settingProvider.select((m) => m.intOf('ui.font-size', defaults: 14)),
    );

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(chapter.title),
        actions: [
          IconButton(
            tooltip: switch (playbackState) {
              Playback.playing => 'Stop',
              _ => 'Play',
            },
            icon: Icon(switch (playbackState) {
              Playback.playing => Icons.stop_rounded,
              _ => Icons.play_arrow_rounded,
            }),
            onPressed: () async {
              if (playbackState.isPlaying) {
                dt.stop();
              } else {
                if (!dt.inited) {
                  await applyVoice(context);
                }

                dt.load(lines);
                dt.play();
              }
            },
          ),

          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (String v) async {
              final f = Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => switch (v) {
                    'font' => FontFrame(),
                    'tts-setting' => EngineSettingPage.from(context),
                    'setting' || _ => SettingFrame(),
                  },
                ),
              );

              f.then((_) {
                // CASE: get provider in context
                //   final m = ProviderScope.containerOf(
                //     context,
                //   ).read(settingProvider);
                //   debugPrint(m.toString());
                if (mounted) {
                  applyVoice(context);
                }
              });
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem(value: 'setting', child: Text('Setting')),
              PopupMenuItem(value: 'search', child: Text('Search')),
              PopupMenuItem(value: 'replace', child: Text('Replace')),
              PopupMenuItem(value: 'tts-setting', child: Text('TTS Setting')),
              PopupMenuItem(value: 'font', child: Text('Font Demo')),
            ],
            child: Icon(Icons.more_vert, size: 36),
          ),
        ],
      ),
      drawer: Drawer(
        width: 280,
        child: ChapterList(
          id: widget.id,
          book: widget.book,
          // chapterIndex: _progress.chapterIndex,
          // onChange: (i) => setState(
          // () => _progress = Progress(chapterIndex: i, lineIndex: 0),
          // ),
        ),
      ),
      body: SelectableRegion(
        selectionControls: materialTextSelectionHandleControls,
        contextMenuBuilder: selectToolbar,
        child: HtmlWidget(
          chapter.content,
          mode: Mode.list,
          provider: ArchiveProvider(chapter.href, widget.book.files),
        ),
      ),
    );
  }

  void gotoNextChapter() {
    // if (_progress.chapterIndex + 1 < widget.book.chapters.length) {
    //   setState(
    //     () => _progress = _progress.copyWith(
    //       chapterIndex: _progress.chapterIndex + 1,
    //       lineIndex: 0,
    //     ),
    //   );
    //   ref.read(itemsProvider.notifier).update(widget.id, progress: _progress);
    // } else {
    //   debugPrint('book end');
    // }
  }

  void scrollToNextPage(TapUpDetails d) {
    if (!roller.hasClients) return;

    final double viewportHeight = roller.position.viewportDimension;
    final double target = (roller.offset + viewportHeight).clamp(
      0.0,
      roller.position.maxScrollExtent,
    );

    if (roller.offset == roller.position.maxScrollExtent) {
      debugPrint('next chapter');
      gotoNextChapter();
      return;
    }

    if (ref.watch(
      settingProvider.select((m) => m.flag('ui.next-page-animation')),
    )) {
      roller.animateTo(
        target,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else {
      roller.jumpTo(target);
    }
  }

  Widget playbackPanel(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous sentence',
              onPressed: () => dt.skip(-1),
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton.filled(
              tooltip: switch (playbackState) {
                Playback.playing => 'Pause',
                Playback.pause => 'Play',
                _ => '_',
              },
              onPressed: dt.toggle,
              icon: Icon(switch (playbackState) {
                Playback.pause => Icons.play_arrow,
                Playback.stop => Icons.stop,
                _ => Icons.pause,
              }),
            ),
            IconButton(
              tooltip: 'Next sentence',
              onPressed: () => dt.skip(1),
              icon: const Icon(Icons.skip_next),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ref.read(
                          settingProvider.select((m) => m.stringOf('ui.lang')),
                        ) ==
                        'zh'
                    ? 'TTS 中文'
                    : 'TTS EN',
                textAlign: TextAlign.end,
              ),
            ),
            IconButton(
              tooltip: 'Translate chapter',
              onPressed: () {
                // _translated.remove(_chapter);
                // _translateChapter(_chapter);
              },
              icon: const Icon(Icons.translate),
            ),
          ],
        ),
      ),
    );
  }

  Widget readerPanel(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Chapters',
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            IconButton.filled(
              tooltip: switch (playbackState) {
                Playback.playing => 'Pause',
                Playback.pause => 'Play',
                _ => '_',
              },
              onPressed: dt.toggle,
              icon: Icon(switch (playbackState) {
                Playback.pause => Icons.play_arrow,
                Playback.stop => Icons.stop,
                _ => Icons.pause,
              }),
            ),
            IconButton(
              tooltip: 'Next sentence',
              onPressed: () => dt.skip(1),
              icon: const Icon(Icons.skip_next),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ref.read(
                          settingProvider.select((m) => m.stringOf('ui.lang')),
                        ) ==
                        'zh'
                    ? 'TTS 中文'
                    : 'TTS EN',
                textAlign: TextAlign.end,
              ),
            ),
            IconButton(
              tooltip: 'Translate chapter',
              onPressed: () {
                // _translated.remove(_chapter);
                // _translateChapter(_chapter);
              },
              icon: const Icon(Icons.translate),
            ),
          ],
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

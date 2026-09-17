import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/setting.dart';
import '../ui/setting.dart';
import '../ui/voice.dart';
import '../data/model.dart';
import '../epub/book.dart';
import '../tts/dualtts.dart';
import 'font.dart';

class BookFrame extends ConsumerStatefulWidget {
  const BookFrame({
    required this.book,
    required this.progress,
    required this.path,
    super.key,
  });
  final Book book;
  final Progress progress;
  final String path;

  @override
  ConsumerState<BookFrame> createState() => _BookFrameState();
}

class _BookFrameState extends ConsumerState<BookFrame> {
  /// best font style
  TextStyle textStyle(String lang, double fontSize) => switch (lang) {
    'zh' => TextStyle(
      fontFamily: '.osdefault', // let platform decide
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      height: 1.55,
      fontWeight: FontWeight.w400,
    ),
    'en' || _ => TextStyle(
      fontFamily: '.osdefault', // let platform decide
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      height: 1.55,
      fontWeight: FontWeight.w200,
    ),
  };

  String lang = ''; // TODO: current lang
  late Progress progress;
  Playback playbackState = Playback.stop;
  final dt = DualTts();
  final roller = ScrollController();

  /// CASE: avoid using ref in initState
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _initialized = true;

      // ✅ Safe to use ref here
      lang = ref.watch(settingProvider.select((m) => m.stringOf('ui.lang')));
    }
  }

  /// CASES: save/restore scroll offset, include
  /// - addPostFrameCallback
  /// - ScrollController.addListener
  /// - dispose Future
  late final ItemListNotifier _itemsProvider;
  double offset = 0;

  @override
  void initState() {
    super.initState();
    progress = widget.progress;

    // CASE:
    // Not work here(in initState). Move into didChangeDependencies
    // lang = ref.watch(settingProvider.select((m) => m.stringOf('ui.lang')));

    // safe here
    _itemsProvider = ref.read(itemsProvider.notifier);

    dt.addListener(_onTts);

    // Set drawer opened at first time frame appear
    WidgetsBinding.instance.addPostFrameCallback((_) {
      roller.jumpTo(progress.offset);
      _scaffoldKey.currentState?.openDrawer();
    });

    roller.addListener(() {
      offset = roller.offset;
    });
  }

  @override
  void dispose() {
    // _settings.removeListener(_onSettings);

    /// save progress
    /// `updateProgress` only worked in Future
    Future(
      () => _itemsProvider.updateProgress(
        widget.path,
        progress.copyWith(offset: offset),
      ),
    );

    roller.dispose();
    dt
      ..removeListener(_onTts)
      ..dispose();
    super.dispose();
  }

  void _onTts() {
    if (!mounted) {
      return;
    }

    debugPrint('got dts notify ${dt.state} ${dt.index}');

    if (dt.state != playbackState ||
        (dt.state != Playback.stop && dt.index != progress.lineIndex)) {
      setState(() {
        progress = progress.copyWith(lineIndex: dt.index);
        playbackState = dt.state;
      });
    }

    // next chapter
    if (dt.state == Playback.playing && dt.index + 1 == lines.length) {
      print('TODO: speak, next chapter');
      if (progress.chapterIndex + 1 < widget.book.chapters.length) {
        progress = progress.copyWith(
          chapterIndex: progress.chapterIndex + 1,
          lineIndex: 0,
        );
      }

      // TODO: How to play next
    }
  }

  List<Line> get lines {
    return widget.book.chapters[progress.chapterIndex].lines
        .where((line) => lang == '' || line.lang == lang)
        .toList();
  }

  Future applyVoice(BuildContext context) {
    final m = ProviderScope.containerOf(context).read(settingProvider);

    debugPrint('in apply got setting: $m');
    print(m.has('tts.en'));

    final vs = [
      if (m.has('tts.en')) Voice.from('en', m.objectOf('tts.en')),
      if (m.has('tts.zh')) Voice.from('zh', m.objectOf('tts.zh')),
    ];
    return dt.apply(vs).then((x) => debugPrint('dualtts inited $vs'));
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: Scrollbar(
          child: ListView.builder(
            primary: true,
            key: PageStorageKey<String>(widget.book.title),
            itemCount: widget.book.chapters.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                  ),
                  child: ListTile(
                    title: Text(widget.book.title),
                    subtitle: Text(widget.book.author),
                  ),
                );
              }
              final i = index - 1;
              return ListTile(
                selected: i == progress.chapterIndex,
                title: Text(widget.book.chapters[i].title),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => progress = Progress(chapterIndex: i));
                },
              );
            },
          ),
        ),
      ),

      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(widget.book.chapters[progress.chapterIndex].title),
        actions: [
          // PopupMenuButton<String>(
          //   tooltip: 'Display language',
          //   initialValue: lang,
          //   onSelected: (String val) {
          //     ref.watch(settingProvider.notifier).put('ui.lang', val);
          //     setState(() => lang = val);
          //     // TODO: reset index
          //     // roller.ensureVisible
          //   },
          //   itemBuilder: (BuildContext context) => const [
          //     PopupMenuItem(value: 'en', child: Text('Only English')),
          //     PopupMenuItem(value: 'zh', child: Text('Only Chinese')),
          //     PopupMenuItem(value: '', child: Text('All')),
          //   ],
          //   child: Text(switch (lang) {
          //     'en' => 'EN',
          //     'zh' => 'ZH',
          //     '' || _ => 'ALL',
          //   }),
          // ),
          // SizedBox(width: 20),
          IconButton(
            tooltip: switch (dt.state) {
              Playback.playing => 'Stop',
              _ => 'Play',
            },
            icon: Icon(switch (dt.state) {
              Playback.playing => Icons.stop,
              _ => Icons.play_arrow,
            }),
            onPressed: () async {
              if (dt.state == Playback.playing) {
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
            onSelected: (String value) async {
              if (value == 'font') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (context) => FontFrame()),
                );
                return;
              } else if (value == 'setting') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (context) => SettingFrame()),
                );
                return;
              }
              final f = Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) {
                    return VoiceSettingPage.from(context);
                  },
                ),
              );

              f.then((_) {
                //   // CASE: get provider in context
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
      body: Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: roller,
              thumbVisibility: true,
              child: SafeArea(
                child: GestureDetector(
                  behavior: HitTestBehavior
                      .opaque, // 👈 Crucial: Captures taps on empty space
                  onTap: toNextChapter,
                  child: ListView.builder(
                    key: PageStorageKey<String>(
                      '${widget.book.title} ${progress.chapterIndex}',
                    ),
                    controller: roller,
                    padding: EdgeInsets.all(8),
                    itemCount: lines.length,
                    itemBuilder: (context, i) {
                      final fontSize = ref.watch(
                        settingProvider.select(
                          (m) => m.intOf('ui.zh-font-size', defaults: 18),
                        ),
                      );
                      return GestureDetector(
                        onTapUp: scrollToNextPage,
                        onDoubleTap: () {
                          if (dt.state == Playback.playing) {
                            dt.jumpTo(max(0, i - 1)); // dutts.play bug?
                          }
                        },
                        child: dt.state == Playback.playing && i == dt.index
                            ? Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.red),
                                ),
                                child: Text(
                                  lines[i].text,
                                  style: textStyle(lines[i].lang, fontSize.toDouble()),
                                ),
                              )
                            : Text(
                                lines[i].text,
                                style: textStyle(lines[i].lang, fontSize.toDouble()),
                              ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (dt.state != Playback.stop) panel(context),
        ],
      ),
    );
  }

  void toNextChapter() {
    if (progress.chapterIndex + 1 < widget.book.chapters.length) {
      setState(
        () => progress = progress.copyWith(
          chapterIndex: progress.chapterIndex + 1,
          lineIndex: 0,
        ),
      );
    } else {
      debugPrint('book end');
    }
  }

  void scrollToNextPage(TapUpDetails d) {
    if (!roller.hasClients) return;

    final double viewportHeight = roller.position.viewportDimension;
    final double target = (roller.offset + viewportHeight).clamp(
      0.0,
      roller.position.maxScrollExtent,
    );

    // debugPrint(
    //   'offset: ${roller.offset} h: $viewportHeight max: ${roller.position.maxScrollExtent}',
    // );

    if (roller.offset == roller.position.maxScrollExtent) {
      debugPrint('next chapter');
      toNextChapter();
      return;
    }

    roller.animateTo(
      target,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  Widget panel(BuildContext context) {
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
              tooltip: switch (dt.state) {
                Playback.playing => 'Pause',
                Playback.pause => 'Play',
                _ => '_',
              },
              onPressed: dt.toggle,
              icon: Icon(switch (dt.state) {
                Playback.playing => Icons.pause,
                Playback.pause => Icons.play_arrow,
                Playback.stop => Icons.stop,
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
                lang == 'zh' ? 'TTS 中文' : 'TTS EN',
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
}

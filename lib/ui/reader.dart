import 'package:flutter/material.dart';
import 'package:lingua/settings/setting.dart';
import 'package:lingua/ui/voice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../epub/book.dart';
import '../tts/dualtts.dart';

/// current index of chapter and line
class Progress {
  Progress({this.chapter = 0, this.line = 0});
  int chapter;
  int line;
}

class BookFrame extends ConsumerStatefulWidget {
  const BookFrame(this.book, this.progress, {super.key});
  final Book book;
  final Progress progress;

  @override
  ConsumerState<BookFrame> createState() => _BookFrameState();
}

class _BookFrameState extends ConsumerState<BookFrame> {
  /// best font style
  final bf = const TextStyle(
    fontFamily: null, // let platform decide
    fontFamilyFallback: [
      'PingFang TC', // iOS / macOS
      'Microsoft JhengHei', // Windows
      'Noto Sans CJK TC',
      'Source Han Sans TC',
      'sans-serif',
    ],
    fontSize: 16,
    height: 1.55,
    fontWeight: FontWeight.w400,
  );

  String lang = ''; // TODO: current lang
  final dt = DualTts();

  late Progress progress;

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

  @override
  void initState() {
    super.initState();
    progress = widget.progress;

    // CASE:
    // move into didChangeDependencies
    // lang = ref.watch(settingProvider.select((m) => m.stringOf('ui.lang')));

    dt.addListener(_onTts);
  }

  @override
  void dispose() {
    // _settings.removeListener(_onSettings);
    dt
      ..removeListener(_onTts)
      ..dispose();
    super.dispose();
  }

  void _onTts() {
    if (!mounted) {
      return;
    }

    progress.line = dt.index;

    debugPrint('got dts notify ${dt.playing} ${dt.index}');

    // next chapter
    if (!dt.playing && dt.index == lines.length) {
      if (progress.chapter + 1 < widget.book.chapters.length) {
        progress = Progress(chapter: progress.chapter + 1);
      }

      // TODO: How to play next
    }
    setState(() {});
  }

  List<Line> get lines {
    return widget.book.chapters[progress.chapter].lines
        .where((line) => lang == '' || line.lang == lang)
        .toList();
  }

  Future applyVoice(BuildContext context) {
    final m = ProviderScope.containerOf(context).read(settingProvider);

    final vs = [
      if (m.has('tts.en')) Voice.from('en', m.objectOf('tts.en')),
      if (m.has('tts.zh')) Voice.from('zh', m.objectOf('tts.zh')),
    ];
    return dt.apply(vs).then((x) => debugPrint('dualtts inited'));
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: Column(
          children: [
            SafeArea(
              // TODO: vertically center
              child: SizedBox(
                height: 50,
                child: Center(child: Text(widget.book.title)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.book.chapters.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    selected: index == progress.chapter,
                    title: Text(widget.book.chapters[index].title),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => progress = Progress(chapter: index));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(widget.book.chapters[progress.chapter].title),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Display language',
            initialValue: lang,
            onSelected: (String val) {
              ref.watch(settingProvider.notifier).put('ui.lang', val);
              setState(() => lang = val);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('You selected: $val')));
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem(value: 'en', child: Text('en only')),
              PopupMenuItem(value: 'zh', child: Text('zh only')),
              PopupMenuItem(value: '', child: Text('all')),
            ],
            child: TextButton.icon(
              icon: Icon(Icons.language_rounded, size: 36),
              onPressed:
                  null, // disabled because PopupMenuButton handles the tap
              label: Text(lang),
            ),
          ),
          // SizedBox(width: 20),
          IconButton(
            tooltip: dt.playing ? 'Pause' : 'Play',
            icon: dt.playing
                ? Icon(Icons.pause_circle, size: 36)
                : Icon(Icons.play_circle, size: 36),
            onPressed: () async {
              dt.load(lines);

              if (!dt.inited) {
                await applyVoice(context);
              }

              dt.toggle();
            },
          ),

          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (String value) async {
              final f = Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) {
                    final m = ProviderScope.containerOf(
                      context,
                    ).read(settingProvider);
                    return VoiceSettingPage([
                      Voice.from('en', m.of('tts.en')),
                      Voice.from('zh', m.of('tts.zh')),
                    ]);
                  },
                ),
              );

              f.then((_) {
                //   // CASE: get provider in context
                //   final m = ProviderScope.containerOf(
                //     context,
                //   ).read(settingProvider);
                //   debugPrint(m.toString());
                applyVoice(context);
              });
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem(value: 'search', child: Text('Search')),
              PopupMenuItem(value: 'replace', child: Text('Replace')),
              PopupMenuItem(value: 'tts-setting', child: Text('TTS Setting')),
            ],
            child: Icon(Icons.more_horiz, size: 36),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: lines.length,
              itemBuilder: (context, i) {
                return GestureDetector(
                  onTapDown: (details) {
                    // TODO: not work
                    debugPrint('click $i');
                    if (dt.playing) {
                      dt.jumpTo(i);
                    }
                  },
                  child: dt.playing && i == dt.index
                      ? Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red),
                          ),
                          child: Text(lines[i].text, style: bf),
                        )
                      : Text(lines[i].text, style: bf),
                );
              },
            ),
          ),
          if (dt.playing) panel(context),
        ],
      ),
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
              tooltip: dt.playing ? 'Pause' : 'Listen',
              onPressed: dt.toggle,
              icon: Icon(dt.playing ? Icons.pause : Icons.play_arrow),
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

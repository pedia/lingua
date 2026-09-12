import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lingua/settings/setting.dart';
import 'package:lingua/ui/voice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/library_store.dart';
import '../epub/book.dart';
import '../epub/parser.dart';
import '../epub/writer.dart';
import '../settings/app_settings.dart';
import '../translate/translation_service.dart';
import '../tts/tts_controller.dart';
import '../data/sample.dart';
import '../tts/dualtts.dart';
import '../settings/setting.dart';

class ChapterFrame extends ConsumerStatefulWidget {
  const ChapterFrame(this.chapter, {super.key});
  final Chapter chapter;

  @override
  ConsumerState<ChapterFrame> createState() => _ChapterFrameState();
}

class _ChapterFrameState extends ConsumerState<ChapterFrame> {
  String lang = ''; // TODO: current lang
  final dt = DualTts();
  @override
  void initState() {
    super.initState();
    dt.addListener(_onTts);

    lang = ref.watch(settingProvider.select((m) => m.stringOf('ui.lang')));
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
    debugPrint('got dts notify ${dt.playing} ${dt.index}');
    setState(() {});
  }

  List<Line> get lines {
    return widget.chapter.lines
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
    final ts = TextStyle(
      // fontFamily: 'Roboto', // Or 'SF Pro', 'Inter', etc.
      fontSize: 18.0, // Standard body size (14.0 - 18.0)
      fontWeight: FontWeight.w400, // Regular weight is easiest to read
      // color: Colors
      //     .white70, // Soft black reduces eye strain compared to pure black
      height: 1.5, // Line height (1.4 to 1.6 is ideal for body text)
      letterSpacing: 0.5, // Subtle letter spacing helps character recognition
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: ListView.builder(
          itemCount: 3,
          itemBuilder: (context, index) {
            return ListTile(
              selected: index == 3,
              title: Text('epub.chapters[$index].title'),
              onTap: () {
                Navigator.pop(context);
                // _goToChapter(index);
              },
            );
          },
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(widget.chapter.title),
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
                          child: Text(lines[i].text, style: ts),
                        )
                      : Text(lines[i].text, style: ts),
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

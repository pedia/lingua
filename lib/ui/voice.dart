import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../settings/setting.dart';
import '../tts/dualtts.dart';

class VoiceSettingPage extends StatefulWidget {
  const VoiceSettingPage(this.vs, {super.key});
  final List<Voice> vs;

  @override
  State<VoiceSettingPage> createState() => _VoiceSettingPageState();
}

class _VoiceSettingPageState extends State<VoiceSettingPage> {
  final tts = FlutterTts();
  late List ves; // list of {"name": "Karen", "locale": "en-AU"}
  List<Voice> vs = [];

  @override
  void initState() {
    super.initState();
    setState(() => vs = widget.vs);

    tts.getVoices.then((x) {
      setState(() => ves = x);
      // debugPrint('$ves');
    });
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  Widget choose(BuildContext context, int i) {
    return PopupMenuButton<Object>(
      // TODO: Map<String, String>
      tooltip: 'Choose voice',
      initialValue: vs[i].voice,
      onSelected: (v) {
        setState(
          () =>
              vs[i] = vs[i].copyWith(voice: (v as Map).cast<String, String>()),
        );
      },
      itemBuilder: (BuildContext context) {
        debugPrint('${ves.length}');
        return ves
            .where((e) {
              if (e['locale'] != vs[i].language) {
                return false;
              }
              // exclude gender: unspecified
              final String gender = e['gender'] ?? '';
              if (gender == 'unspecified') {
                return false;
              }

              // com.apple.speech.synthesis.voice.Fred
              return true;
            })
            .map(
              (e) => PopupMenuItem<Object>(
                value: e,
                child: Text(Voice.displayVoice(e.cast<String,String>())),
              ),
            )
            .toList();
      },
      child: TextButton(
        onPressed: null, // disabled because PopupMenuButton handles the tap
        child: Text(vs[i].name, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        debugPrint('pop invoked, put settings');

        // CASE: read(settingProvider.notifier)
        final m = ProviderScope.containerOf(
          context,
        ).read(settingProvider.notifier);
        for (final v in vs) {
          m.put('tts.${v.lang}', v.toSetting());
          debugPrint('$v');
        }
      },
      child: Scaffold(
        appBar: AppBar(leading: BackButton(), title: Text('Speech Setting')),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: ListView(
            children: List.generate(vs.length, (i) => card(context, i)),
          ),
        ),
      ),
    );
  }

  Widget card(BuildContext context, int i) {
    return Card(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(vs[i].title, style: Theme.of(context).textTheme.headlineSmall),
              // Expanded(),
              TextButton(
                onPressed: () async {
                  await tts.stop();
                  await tts.awaitSpeakCompletion(true);
                  await tts.setSpeechRate(vs[i].rate);
                  await tts.setPitch(vs[i].pitch);
                  if (vs[i].volume != null) await tts.setVolume(vs[i].volume!);

                  // setLanguage must before setVoice
                  try {
                    await tts.setLanguage(vs[i].language);
                  } catch (e) {
                    debugPrint('setLanguage failed: $e');
                  }

                  if (vs[i].voice != null) {
                    final v = await tts.setVoice(vs[i].voice!);
                    debugPrint('setVoice: ${vs[i].voice} -> $v');
                  }

                  final m = {
                    'zh': '你好,这是一个中文语音合成引擎',
                    'en': 'Hello, I am focus on bilingualism',
                  };
                  final s = m[vs[i].lang] ?? m['en']!;

                  tts.speak(s);
                },
                child: Text('Play Sample'),
              ),
            ],
          ),

          // voice
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Voice'), choose(context, i)],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: Text('Rate ${vs[i].rate.toStringAsFixed(2)}'),
              ),
              Flexible(
                flex: 3,
                child: Slider(
                  value: vs[i].rate,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) {
                    setState(() => vs[i] = vs[i].copyWith(rate: val));
                  },
                ),
              ),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: Text('Volume ${vs[i].volume?.toStringAsFixed(2)}'),
              ),
              Flexible(
                flex: 3,
                child: Slider(
                  divisions: 5,
                  value: vs[i].volume ?? 1.0,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) {
                    setState(() => vs[i] = vs[i].copyWith(volume: val));
                  },
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: Text('Pitch ${vs[i].pitch.toStringAsFixed(2)}'),
              ),
              Flexible(
                flex: 3,
                child: Slider(
                  divisions: 10,
                  value: vs[i].pitch,
                  min: 0.5,
                  max: 2.0,
                  onChanged: (val) {
                    setState(() => vs[i] = vs[i].copyWith(pitch: val));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

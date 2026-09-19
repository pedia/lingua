import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../settings/setting.dart';
import '../tts/dualtts.dart';

class VoiceSettingPage extends StatefulWidget {
  const VoiceSettingPage(this.vs, {super.key});
  final List<Voice> vs;

  factory VoiceSettingPage.from(BuildContext context) {
    final m = ProviderScope.containerOf(context).read(settingProvider);
    return VoiceSettingPage([
      Voice.from(
        'en',
        m.of('tts.en') ??
            {
              'rate': 0.44,
              'pitch': 1.0,
              'language': 'en-US',
              'voice': {'locale': 'en-US', 'name': 'Samantha'},
            },
      ),
      Voice.from(
        'zh',
        m.of('tts.zh') ??
            {
              'rate': 0.62,
              'pitch': 1.0,
              'language': 'zh-TW',
              'voice': {'locale': 'zh-TW', 'name': 'Meijia'},
            },
      ),
    ]);
  }

  @override
  State<VoiceSettingPage> createState() => _VoiceSettingPageState();
}

class _VoiceSettingPageState extends State<VoiceSettingPage> {
  final tts = FlutterTts();
  final List<Map<String, String>> allves =
      []; // engine support voices, item like: {"name": "Karen", "locale": "en-AU"}
  List<Voice> vs = [];

  @override
  void initState() {
    super.initState();
    setState(() => vs = widget.vs);

    tts.getVoices.then((x) {
      final list = (x as List).cast<Map>();
      final typed = list.map((e) => Map<String, String>.from(e)).where((e) {
        return e['locale'] == 'en-US' ||
            e['locale'] == 'zh-TW' ||
            // exclude gender: unspecified
            e['gender'] != 'unspecified';
      });

      setState(() => allves.addAll(typed));
      debugPrint('engine voices: $typed');
    });
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  Widget chooseVoice(BuildContext context, int i) {
    return PopupMenuButton<Map<String, String>>(
      tooltip: 'Choose voice',
      initialValue: vs[i].voice,
      onSelected: (v) {
        setState(() => vs[i] = vs[i].copyWith(voice: v));
      },
      itemBuilder: (BuildContext context) {
        return allves
            .where((e) {
              if (e['locale'] != vs[i].language) {
                return false;
              }
              // exclude gender: unspecified
              if (e['gender'] == 'unspecified') {
                return false;
              }

              // com.apple.speech.synthesis.voice.Fred
              return true;
            })
            .map(
              (e) => PopupMenuItem<Map<String, String>>(
                value: e,
                child: Text(Voice.displayVoice(e)),
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

  Widget chooseVoiceDropdown(BuildContext context, int i) {
    return DropdownButton<WrapKey>(
      key: Key(vs[i].lang),
      value: WrapKey(vs[i].voice).containedIn(allves)
          ? WrapKey(vs[i].voice)
          : null,
      underline: null,
      onChanged: (v) {
        setState(() => vs[i] = vs[i].copyWith(voice: v!.m));
      },
      items: allves
          .where((e) {
            if (e['locale'] != vs[i].language) {
              return false;
            }
            // exclude gender: unspecified
            if (e['gender'] == 'unspecified') {
              return false;
            }

            // com.apple.speech.synthesis.voice.Fred
            return true;
          })
          .map(
            (e) => DropdownMenuItem<WrapKey>(
              value: WrapKey(e),
              child: Text(Voice.displayVoice(e)),
            ),
          )
          .toList(),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  vs[i].title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                // Expanded(),
                TextButton(
                  onPressed: () async {
                    await tts.stop();
                    await tts.awaitSpeakCompletion(true);
                    await tts.setSpeechRate(vs[i].rate);
                    await tts.setPitch(vs[i].pitch);
                    if (vs[i].volume != null) {
                      await tts.setVolume(vs[i].volume!);
                    }

                    // setLanguage must before setVoice
                    try {
                      await tts.setLanguage(vs[i].language);
                    } catch (e) {
                      debugPrint('setLanguage failed: $e');
                    }

                    if (vs[i].voice != null) {
                      await tts.setVoice(vs[i].voice!);
                      // debugPrint('setVoice: ${vs[i].voice} -> $v');
                    }

                    final m = {
                      'zh': '你好,选择体验更好的语音合成引擎 say something in English',
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
              children: [
                Flexible(flex: 1, child: Text('Voice')),
                Flexible(flex: 1, child: chooseVoiceDropdown(context, i)),
              ],
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
      ),
    );
  }
}

/// Map<String, String> cannot be compared?
class WrapKey {
  WrapKey(this.m);
  final Map<String, String>? m;

  @override
  bool operator ==(Object other) => other is WrapKey && mapEquals(m, other.m);

  @override
  int get hashCode => Object.hashAll(m?.entries ?? []);

  bool containedIn(List<Map> list) {
    for (final o in list) {
      if (mapEquals(m, o)) {
        return true;
      }
    }
    return false;
  }
}

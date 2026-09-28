import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../settings/setting.dart';
import '../tts/dualtts.dart';

class EngineSettingPage extends StatefulWidget {
  const EngineSettingPage(this.ess, {super.key});
  final List<EngineSetting> ess;

  factory EngineSettingPage.from(BuildContext context) {
    final m = ProviderScope.containerOf(context).read(settingProvider);
    return EngineSettingPage([
      EngineSetting.from(
        'en',
        m.of('tts.en') ??
            {
              'rate': 0.44,
              'pitch': 1.0,
              'language': 'en-US',
              'voice': {'locale': 'en-US', 'name': 'Samantha'},
            },
      ),
      EngineSetting.from(
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
  State<EngineSettingPage> createState() => _EngineSettingPageState();
}

class _EngineSettingPageState extends State<EngineSettingPage> {
  final tts = FlutterTts();

  /// engine support voices, item like: {"name": "Karen", "locale": "en-AU"}
  final List<Voice> allvoices = [];
  List<EngineSetting> ess = [];

  @override
  void initState() {
    super.initState();
    setState(() => ess = widget.ess);

    tts.getVoices.then((x) {
      final list = (x as List).cast<Map>();
      final typed = list
          .map((e) => Voice(Map<String, String>.from(e)))
          .where((e) => e.valid)
          .toList();

      setState(() => allvoices.addAll(typed));
      debugPrint('engine voices:');
      for (final v in typed) {
        print(v);
      }
    });
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  Widget chooseVoice(BuildContext context, int i) {
    return PopupMenuButton<Voice>(
      tooltip: 'Choose voice',
      // TODO: initialValue: vs[i].voice,
      onSelected: (v) {
        setState(() => ess[i] = ess[i].copyWith(voice: v));
      },
      itemBuilder: (BuildContext context) {
        return allvoices
            .where((e) {
              if (e['locale'] != ess[i].language) {
                return false;
              }
              // exclude gender: unspecified
              if (e['gender'] == 'unspecified') {
                return false;
              }

              // com.apple.speech.synthesis.voice.Fred
              return true;
            })
            .map((e) => PopupMenuItem<Voice>(value: e, child: Text(e.title)))
            .toList();
      },
      child: TextButton(
        onPressed: null, // disabled because PopupMenuButton handles the tap
        child: Text(
          ess[i].title,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }

  Widget chooseVoiceDropdown(BuildContext context, int i) {
    return DropdownButton<Voice>(
      key: Key(ess[i].lang),
      value: ess[i].voice,
      underline: null,
      onChanged: (v) {
        setState(() => ess[i] = ess[i].copyWith(voice: v));
      },
      items: allvoices
          .where((e) => e.match(ess[i].lang) && e.valid)
          .map((e) => DropdownMenuItem<Voice>(value: e, child: Text(e.title)))
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
        for (final v in ess) {
          m.put('tts.${v.lang}', v.toSetting());
          debugPrint('$v');
        }
      },
      child: Scaffold(
        appBar: AppBar(leading: BackButton(), title: Text('Speech Setting')),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: ListView(
            children: List.generate(ess.length, (i) => card(context, i)),
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
                  ess[i].title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                // Expanded(),
                TextButton(
                  onPressed: () async {
                    await tts.stop();
                    await tts.awaitSpeakCompletion(true);
                    await tts.setSpeechRate(ess[i].rate);
                    await tts.setPitch(ess[i].pitch);
                    if (ess[i].volume != null) {
                      await tts.setVolume(ess[i].volume!);
                    }

                    // setLanguage must before setVoice
                    try {
                      await tts.setLanguage(ess[i].language);
                    } catch (e) {
                      debugPrint('setLanguage failed: $e');
                    }

                    if (ess[i].voice != null) {
                      await tts.setVoice(ess[i].voice!);
                      // debugPrint('setVoice: ${vs[i].voice} -> $v');
                    }

                    final m = {
                      'zh': '你好,选择体验更好的语音合成引擎 say something in English',
                      'en': 'Hello, I am focus on english speaking',
                    };
                    final s = m[ess[i].lang] ?? m['en']!;

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
                Flexible(flex: 2, child: chooseVoiceDropdown(context, i)),
              ],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  flex: 1,
                  child: Text('Rate ${ess[i].rate.toStringAsFixed(2)}'),
                ),
                Flexible(
                  flex: 3,
                  child: Slider(
                    value: ess[i].rate,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) {
                      setState(() => ess[i] = ess[i].copyWith(rate: val));
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
                  child: Text('Volume ${ess[i].volume?.toStringAsFixed(2)}'),
                ),
                Flexible(
                  flex: 3,
                  child: Slider(
                    divisions: 10,
                    value: ess[i].volume ?? 1.0,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) {
                      setState(() => ess[i] = ess[i].copyWith(volume: val));
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
                  child: Text('Pitch ${ess[i].pitch.toStringAsFixed(2)}'),
                ),
                Flexible(
                  flex: 3,
                  child: Slider(
                    divisions: 10,
                    value: ess[i].pitch,
                    min: 0.5,
                    max: 2.0,
                    onChanged: (val) {
                      setState(() => ess[i] = ess[i].copyWith(pitch: val));
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

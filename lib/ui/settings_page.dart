import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../translate/translation_service.dart';
import '../tts/tts_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.translation,
  });

  final AppSettings settings;
  final TranslationService translation;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _tts = TtsController();
  List<TtsVoice> _enVoices = const [];
  List<TtsVoice> _zhVoices = const [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettings);
    _loadVoices();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    _tts.dispose();
    super.dispose();
  }

  void _onSettings() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadVoices() async {
    await _tts.init();
    final en = await _tts.voicesFor('en');
    final zh = await _tts.voicesFor('zh');
    if (mounted) {
      setState(() {
        _enVoices = en;
        _zhVoices = zh;
      });
    }
  }

  Future<void> _togglePack() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.settings.onDeviceReady) {
        await widget.translation.deleteOnDevice();
      } else {
        await widget.translation.downloadOnDevice();
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(title: Text('Translation'), dense: true),
          /*
          RadioGroup<TranslateEngine>(
            groupValue: settings.engine,
            onChanged: (value) {
              if (value != null) {
                settings.setEngine(value);
              }
            },
            child: Column(
              children: const [
                RadioListTile<TranslateEngine>(
                  title: Text('On-device'),
                  subtitle: Text('Android: ML Kit · macOS: bundled lexicon'),
                  value: TranslateEngine.onDevice,
                ),
              ],
            ),
          ),*/
          const ListTile(
            title: Text('Language pair'),
            subtitle: Text('English – Chinese'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<PairDirection>(
              segments: const [
                ButtonSegment(value: PairDirection.enToZh, label: Text('EN → 中文')),
                ButtonSegment(value: PairDirection.zhToEn, label: Text('中文 → EN')),
              ],
              selected: {settings.direction},
              onSelectionChanged: (value) => settings.setDirection(value.first),
            ),
          ),
          if (settings.engine == TranslateEngine.onDevice)
            ListTile(
              title: Text(settings.onDeviceReady ? 'On-device pack ready' : 'Download EN–中文 pack'),
              subtitle: const Text('Needed once for offline translation'),
              trailing: _busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _togglePack,
                      child: Text(settings.onDeviceReady ? 'Remove' : 'Download'),
                    ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const Divider(),
          const ListTile(title: Text('Text to speech'), dense: true),
          const ListTile(
            title: Text('TTS language'),
            subtitle: Text('Which line is spoken in Lingua view'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<TtsLanguageMode>(
              segments: const [
                ButtonSegment(value: TtsLanguageMode.follow, label: Text('Follow')),
                ButtonSegment(value: TtsLanguageMode.english, label: Text('EN')),
                ButtonSegment(value: TtsLanguageMode.chinese, label: Text('中文')),
              ],
              selected: {settings.ttsLanguage},
              onSelectionChanged: (value) => settings.setTtsLanguage(value.first),
            ),
          ),
          _TtsLangBlock(
            title: 'English voice',
            lang: 'en',
            settings: settings,
            voices: _enVoices,
          ),
          _TtsLangBlock(
            title: 'Chinese voice',
            lang: 'zh',
            settings: settings,
            voices: _zhVoices,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TtsLangBlock extends StatelessWidget {
  const _TtsLangBlock({
    required this.title,
    required this.lang,
    required this.settings,
    required this.voices,
  });

  final String title;
  final String lang;
  final AppSettings settings;
  final List<TtsVoice> voices;

  @override
  Widget build(BuildContext context) {
    final voiceId = settings.ttsVoice(lang);
    final selected = voices.any((voice) => voice.id == voiceId) ? voiceId : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(selected),
            // initialValue: selected,
            hint: const Text('System default'),
            isExpanded: true,
            items: [
              for (final voice in voices)
                DropdownMenuItem(
                  value: voice.id,
                  child: Text('${voice.name} (${voice.locale})', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => settings.setTtsVoice(lang, value),
          ),
          Text('Rate ${settings.ttsRate(lang).toStringAsFixed(2)}'),
          Slider(
            value: settings.ttsRate(lang),
            min: 0.2,
            max: 0.8,
            onChanged: (value) => settings.setTtsRate(lang, value),
          ),
          Text('Pitch ${settings.ttsPitch(lang).toStringAsFixed(2)}'),
          Slider(
            value: settings.ttsPitch(lang),
            min: 0.5,
            max: 2,
            onChanged: (value) => settings.setTtsPitch(lang, value),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsVoice {
  const TtsVoice({required this.name, required this.locale});

  final String name;
  final String locale;

  String get id => '$name|$locale';

  factory TtsVoice.parse(String id) {
    final parts = id.split('|');
    return TtsVoice(name: parts.first, locale: parts.length > 1 ? parts[1] : parts.first);
  }
}

class TtsController extends ChangeNotifier {
  TtsController({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  List<String> sentences = const [];
  int index = 0;
  bool playing = false;
  String language = 'en-US';
  double rate = 0.45;
  double pitch = 1;

  Future<void> init() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    try {
      await _tts.setLanguage(language);
    } catch (_) {}
  }

  Future<List<TtsVoice>> voicesFor(String lang) async {
    final raw = await _tts.getVoices;
    if (raw is! List) {
      return const [];
    }
    final prefix = lang == 'zh' ? 'zh' : 'en';
    final voices = <TtsVoice>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final name = item['name']?.toString();
      final locale = item['locale']?.toString();
      if (name == null || locale == null) {
        continue;
      }
      if (locale.toLowerCase().startsWith(prefix)) {
        voices.add(TtsVoice(name: name, locale: locale));
      }
    }
    voices.sort((a, b) => a.locale.compareTo(b.locale));
    return voices;
  }

  Future<void> applyLanguage({
    required String lang,
    required double rate,
    required double pitch,
    String? voiceId,
  }) async {
    this.rate = rate;
    this.pitch = pitch;
    language = lang.startsWith('zh') ? 'zh-CN' : 'en-US';
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    try {
      await _tts.setLanguage(language);
    } catch (_) {}
    if (voiceId != null && voiceId.isNotEmpty) {
      final voice = TtsVoice.parse(voiceId);
      try {
        await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
      } catch (_) {}
    }
    notifyListeners();
  }

  void load(List<String> next, {int startAt = 0}) {
    sentences = next;
    index = startAt.clamp(0, next.isEmpty ? 0 : next.length - 1);
    notifyListeners();
  }

  void jumpTo(int nextIndex) {
    if (sentences.isEmpty) {
      return;
    }
    index = nextIndex.clamp(0, sentences.length - 1);
    notifyListeners();
  }

  Future<void> play() async {
    if (sentences.isEmpty || playing) {
      return;
    }
    playing = true;
    notifyListeners();
    while (playing && index < sentences.length) {
      notifyListeners();
      await _tts.speak(sentences[index]);
      if (!playing) {
        break;
      }
      if (index < sentences.length - 1) {
        index += 1;
      } else {
        playing = false;
      }
      notifyListeners();
    }
  }

  Future<void> pause() async {
    playing = false;
    await _tts.stop();
    notifyListeners();
  }

  Future<void> toggle() async {
    if (playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> skip(int delta) async {
    if (sentences.isEmpty) {
      return;
    }
    final wasPlaying = playing;
    await pause();
    index = (index + delta).clamp(0, sentences.length - 1);
    notifyListeners();
    if (wasPlaying) {
      await play();
    }
  }

  @override
  void dispose() {
    playing = false;
    _tts.stop();
    super.dispose();
  }
}

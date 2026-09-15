import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../epub/book.dart';

class Voice {
  Voice({
    required this.lang,
    required this.language,
    this.rate = 0.5,
    this.pitch = 1,
    this.volume,
    this.voice,
  });
  final String lang; // hardcode: en, zh, es
  final String language; // in engine en-US
  final double rate;
  final double pitch;
  final double? volume;
  final Map<String, String>? voice; // {"name": "Samantha", "locale": "en-US"}

  Voice copyWith({
    String? lang,
    String? language,
    double? rate,
    double? pitch,
    double? volume,
    Map<String, String>? voice,
  }) {
    return Voice(
      lang: lang ?? this.lang,
      language: language ?? this.language,
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      voice: voice ?? this.voice,
    );
  }

  static Voice from(String lang, Map m) {
    return Voice(
      lang: lang,
      language: m['language'] ?? '',
      rate: m['rate'],
      pitch: m['pitch'],
      volume: m['volume'],
      voice: m['voice'] != null
          ? (m['voice'] as Map).cast<String, String>()
          : null,
    );
  }

  Map<String, Object> toSetting() => {
    'lang': lang,
    'language': language,
    'rate': rate,
    'pitch': pitch,
    'volume': ?volume,
    'voice': ?voice,
  };

  String get title =>
      <String, String>{'en': 'English', 'zh': 'Chinese'}[lang] ?? '';

  // quality: premium
  String get name => displayVoice(voice ?? {});

  static String displayVoice(Map<String, String> m) {
    final n = m['name'] ?? '';
    final q = m['quality'] ?? '';
    if (q == 'premium') {
      return '$n(Premium)';
    }
    return n;
  }

  @override
  String toString() =>
      '$lang/$language vol:${volume?.toStringAsFixed(2)} rate:${rate.toStringAsFixed(2)} pitch:${pitch.toStringAsFixed(2)} $voice';
}

class DualTts extends ChangeNotifier {
  DualTts();

  final tts = FlutterTts();
  final Map<String, Voice> ss = {};
  List<Line> lines = const [];
  int index = 0;
  bool playing = false;

  bool get inited => ss.isNotEmpty;

  void load(List<Line> next, {int startAt = 0}) {
    lines = next;
    index = startAt.clamp(0, next.isEmpty ? 0 : next.length - 1);
    notifyListeners();
  }

  // apply voice setting
  Future<void> apply(List<Voice> vs) async {
    for (var v in vs) {
      ss[v.lang] = v;
    }

    // important, broadcast changing playing
    await tts.awaitSpeakCompletion(true);
  }

  void jumpTo(int nextIndex) async {
    if (lines.isEmpty) {
      return;
    }
    await tts.stop();
    index = nextIndex.clamp(0, lines.length - 1);
    debugPrint('$nextIndex $index');
    notifyListeners();
  }

  Future<void> play() async {
    if (lines.isEmpty || playing) {
      return;
    }
    playing = true;
    notifyListeners();
    while (playing && index < lines.length) {
      notifyListeners();
      final line = lines[index];
      final v = ss[line.lang];
      if (v != null) {
        // debugPrint('set tts $v');
        await tts.setSpeechRate(v.rate);
        await tts.setPitch(v.pitch);
        if (v.volume != null) await tts.setVolume(v.volume!);

        try {
          await tts.setLanguage(v.language);
        } catch (e) {
          debugPrint('setLanguage failed: $e, %v');
        }
        if (v.voice != null) await tts.setVoice(v.voice!);
      }

      await tts.speak(lines[index].text);
      if (!playing) {
        break;
      }
      if (index < lines.length - 1) {
        index += 1;
      } else {
        playing = false;
      }
      notifyListeners();
    }
  }

  Future<void> pause() async {
    playing = false;
    await tts.pause();
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
    if (lines.isEmpty) {
      return;
    }
    final wasPlaying = playing;
    await pause();
    index = (index + delta).clamp(0, lines.length - 1);
    notifyListeners();
    if (wasPlaying) {
      await play();
    }
  }

  @override
  void dispose() {
    playing = false;
    tts.stop();

    super.dispose();
  }
}

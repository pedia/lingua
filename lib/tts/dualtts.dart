import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../epub/epub.dart';

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

/// Triple state for tts engine
enum Playback { playing, pause, stop }

class DualTts extends ChangeNotifier {
  DualTts();

  final tts = FlutterTts();
  final Map<String, Voice> ss = {};
  List<Chunk> lines = const [];
  int index = 0;
  Playback state = Playback.stop;

  bool get inited => ss.isNotEmpty;

  void load(List<Chunk> next, {int startAt = 0}) {
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
    if (lines.isEmpty || nextIndex > lines.length - 1 || nextIndex < 0) {
      return;
    }

    await tts.stop();
    index = nextIndex;
    notifyListeners();
  }

  Future<void> play() async {
    if (lines.isEmpty || state == Playback.playing) {
      return;
    }
    state = Playback.playing;
    notifyListeners();
    while (state == Playback.playing && index < lines.length) {
      notifyListeners();
      final line = lines[index];
      final v = ss[line.lang];
      if (v != null) {
        await tts.setSpeechRate(v.rate);
        debugPrint('rate: ${v.rate}');
        await tts.setPitch(v.pitch);
        if (v.volume != null) await tts.setVolume(v.volume!);

        try {
          await tts.setLanguage(v.language);
        } catch (e) {
          debugPrint('setLanguage failed: $e, %v');
        }
        if (v.voice != null) await tts.setVoice(v.voice!);
      } else {
        debugPrint('voices mess ${ss.length} ${line.lang}');
      }

      await tts.speak(line.text);
      if (state == Playback.stop) {
        break;
      }
      if (index < lines.length - 1) {
        index += 1;
      } else {
        state = Playback.stop;
      }
      notifyListeners();
    } // end while
  }

  Future<void> pause() async {
    state == Playback.pause;
    await tts.pause();
    notifyListeners();
  }

  Future<void> stop() async {
    state == Playback.stop;
    await tts.stop();
    lines.clear();
    notifyListeners();
  }

  Future<void> toggle() async {
    if (state == Playback.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> skip(int delta) async {
    if (lines.isEmpty) {
      return;
    }
    final wasPlaying = state;
    await pause();
    index = (index + delta).clamp(0, lines.length - 1);
    notifyListeners();
    if (wasPlaying == Playback.playing) {
      await play();
    }
  }

  @override
  void dispose() {
    state = Playback.stop;
    tts.stop();

    super.dispose();
  }
}

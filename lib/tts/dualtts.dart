import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'dart:math';
import '../epub/epub.dart';

extension StringMidExtension on String {
  String mid(String startDelimiter, [String? endDelimiter]) {
    int startIndex = 0;

    // Only search if the start delimiter is not empty
    if (startDelimiter.isNotEmpty) {
      int foundIndex = indexOf(startDelimiter);
      if (foundIndex == -1) return "";
      startIndex = foundIndex + startDelimiter.length;
    }

    if (endDelimiter == null) {
      return substring(startIndex);
    }

    int endIndex = indexOf(endDelimiter, startIndex);
    if (endIndex == -1) return "";

    return substring(startIndex, endIndex);
  }
}

/// {name: Arthur, quality: default, locale: en-GB, gender: male, identifier: com.apple.ttsbundle.siri_Arthur_en-GB_compact}
class Voice extends UnmodifiableMapView<String, String> {
  Voice(super.map);

  bool get valid =>
      this['gender'] != 'unspecified' && !this['name']!.contains('network');

  /// is match en, zh, es, jp, kr?
  bool match(String lang) {
    return this['locale']?.mid('', '-') == lang;
    // return switch (lang) {
    //   'en' => <String>{'en-US', 'en-AU', 'en-GB'}.contains(this['locale']),
    //   'zh' => <String>{'zh-TW', 'zh-CN', 'zh-HK'}.contains(this['locale']),
    //   _ => false,
    // };
  }

  // Karen(Premium),F,TW
  String get title => [
    // fr-ca-x-caa-local => caa
    this['name']!.split('-').length == 5
        ? this['name']!.split('-')[3]
        : this['name'],
    if (this['quality'] != null)
      switch (this['quality']) {
        'premium' => '(Premium)',
        'enhanced' => '(Enhanced)',
        'high' => '(High)',
        _ => '',
      },

    ',',
    this['locale']?.mid('-'),

    if (this['gender'] != null) ',',
    if (this['gender'] != null)
      switch (this['gender']) {
        'female' => 'F',
        'male' => 'M',
        _ => '',
      },
  ].join('');

  @override
  bool operator ==(Object other) =>
      other is Voice &&
      this['name'] == other['name'] &&
      this['locale'] == other['locale'] &&
      this['identifier'] == other['identifier'];

  @override
  int get hashCode =>
      Object.hash(this['name'], this['locale'], this['identifier']);
}

class EngineSetting {
  EngineSetting({
    required this.lang,
    required this.language,
    this.rate = 0.5,
    this.pitch = 1,
    this.volume,
    this.voice,
  });
  final String lang; // hardcode: en, zh, es, jp, kr
  final String language; // in engine en-US
  final double rate;
  final double pitch;
  final double? volume;
  final Voice? voice;

  EngineSetting copyWith({
    String? lang,
    String? language,
    double? rate,
    double? pitch,
    double? volume,
    Voice? voice,
  }) {
    return EngineSetting(
      lang: lang ?? this.lang,
      language: language ?? this.language,
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      voice: voice ?? this.voice,
    );
  }

  static EngineSetting from(String lang, Map m) {
    return EngineSetting(
      lang: lang,
      language: m['language'] ?? '',
      rate: m['rate'],
      pitch: m['pitch'],
      volume: m['volume'],
      voice: m['voice'] != null
          ? Voice((m['voice'] as Map).cast<String, String>())
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

  @override
  String toString() =>
      '$lang/$language vol:${volume?.toStringAsFixed(2)} rate:${rate.toStringAsFixed(2)} pitch:${pitch.toStringAsFixed(2)} $voice';
}

/// Triple state for tts engine
enum Playback {
  playing,
  startLine,
  endLine,
  pause,
  stop;

  bool get isPlaying => this == playing || this == startLine || this == endLine;
}

class DualTts extends ChangeNotifier {
  DualTts();

  final tts = FlutterTts();
  final Map<String, EngineSetting> ss = {};
  List<Chunk> chunks = const [];
  int index = 0;
  Playback state = Playback.stop;

  /// TODO: brand specif tts engine or google
  Future<void> setEngine() async {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().deviceInfo;

      //  {physicalRamSize: 7462, type: user, manufacturer: samsung, freeDiskSize: 193618276352, bootloader: A1760ZHS7CZH2, fingerprint: samsung/a17xzh/a17x:16/BP4A.251205.006/A1760ZHS7CZH2_OZS7CZH2:user/release-keys, host: SWDK3912, isLowRamDevice: false, model: SM-A1760, id: BP4A.251205.006, brand: samsung, hardware: s5e8535, product: a17xzh, totalDiskSize: 239475884032, supportedAbis: [arm64-v8a, armeabi-v7a, armeabi], supported32BitAbis: [armeabi-v7a, armeabi], display: BP4A.251205.006.A1760ZHS7CZH2, isPhysicalDevice: true, version: {baseOS: samsung/a17xzh/a17x:16/BP4A.251205.006/A1760ZHU5CZE9_OZS5CZE9:user/release-keys, securityPatch: 2026-08-05, sdkInt: 36, release: 16, codename: REL, previewSdkInt: 0, incremental: A1760ZHS7CZH2}, systemFeatures: [android.hardware.sensor.proximity, com.google.android.feature.CONTEXTUAL_SEARCH, com.samsung.android.sdk.camera.processor, com.google.android.feature.GEMINI_EXPERIENCE, com.sec.feature.motionrecognition_service, android.hardware.telephony.ims.s
      if (info.data['brand'] == 'samsung') {
        await tts.setEngine("com.samsung.SMT");
      } else {
        await tts.setEngine("com.google.android.tts");
      }
    }
  }

  bool get inited => ss.isNotEmpty;

  void load(List<Chunk> next, {int startAt = 0}) {
    chunks = next;
    index = max(0, startAt);
    notifyListeners();
  }

  // apply voice setting
  Future<void> apply(List<EngineSetting> vs) async {
    for (var v in vs) {
      ss[v.lang] = v;
    }

    // important, broadcast changing playing
    await tts.awaitSpeakCompletion(true);
  }

  void jumpTo(int nextIndex) async {
    if (chunks.isEmpty || nextIndex > chunks.length - 1 || nextIndex < 0) {
      return;
    }

    await tts.stop();
    index = nextIndex;
    notifyListeners();
  }

  Future<void> play() async {
    if (chunks.isEmpty || state.isPlaying) {
      return;
    }
    state = Playback.playing;
    notifyListeners();
    while (state.isPlaying && index < chunks.length) {
      state = Playback.startLine;
      notifyListeners();
      final line = chunks[index];
      final v = ss[line.lang == '' ? 'zh' : line.lang];
      if (v != null) {
        await tts.setSpeechRate(v.rate);
        // debugPrint('rate: ${v.rate}');
        await tts.setPitch(v.pitch);
        if (v.volume != null) await tts.setVolume(v.volume!);

        try {
          await tts.setLanguage(v.language);
        } catch (e) {
          debugPrint('setLanguage failed: $e, %v');
        }
        if (v.voice != null) await tts.setVoice(v.voice!);
      } else {
        debugPrint('voices[${line.lang}] not found, total:${ss.length}');
      }

      debugPrint('$index, $line');
      await tts.speak(line.text);
      if (state == Playback.stop) {
        break;
      }
      if (index < chunks.length - 1) {
        state = Playback.endLine;
        notifyListeners();

        index += 1;
      } else {
        state = Playback.endLine;
        notifyListeners();
        state = Playback.stop;
      }
    }
    notifyListeners(); // end while
  }

  Future<void> pause() async {
    state == Playback.pause;
    await tts.pause();
    notifyListeners();
  }

  Future<void> stop() async {
    state == Playback.stop;
    await tts.stop();
    chunks.clear();
    notifyListeners();
  }

  Future<void> toggle() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> skip(int delta) async {
    if (chunks.isEmpty) {
      return;
    }
    final wasPlaying = state;
    await pause();
    index = (index + delta).clamp(0, chunks.length - 1);
    notifyListeners();
    if (wasPlaying.isPlaying) {
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

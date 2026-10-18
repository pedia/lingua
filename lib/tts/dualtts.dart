import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'dart:math';
import '../epub/epub.dart';
import '../epub/lang.dart';

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
  bool match(Lang lang) {
    // 'en-US' => en
    return this['locale']?.mid('', '-') == lang.name;
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
      this['locale'] == other['locale'];

  @override
  int get hashCode => Object.hashAll(entries);
  // Object.hash(this['name'], this['locale'], this['identifier']);
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

  /// hardcode: en, zh, es, jp, kr
  final Lang lang;
  final String language; // in engine en-US
  final double rate;
  final double pitch;
  final double? volume;
  final Voice? voice;

  EngineSetting copyWith({
    Lang? lang,
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

  static EngineSetting from(Lang lang, Map m) {
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
    'lang': lang.name,
    'language': language,
    'rate': rate,
    'pitch': pitch,
    'volume': ?volume,
    'voice': ?voice,
  };

  String get title =>
      <Lang, String>{Lang.en: 'English', Lang.zh: 'Chinese'}[lang] ?? '';

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

typedef SpeakProgress = (Playback, int);

class DualTts {
  DualTts();

  final tts = FlutterTts();
  final Map<Lang, EngineSetting> ss = {};
  List<Chunk> chunks = const [];
  int index = 0;
  Playback state = Playback.stop;
  static final streamController = StreamController<SpeakProgress>.broadcast();

  Stream<SpeakProgress> get stream => streamController.stream;

  void notify() {
    streamController.add((state, index));
  }

  /// TODO: remove this, someone said google tts is better
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
    notify();
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
    notify();
  }

  Future<void> play() async {
    if (chunks.isEmpty || state.isPlaying) {
      return;
    }
    state = Playback.playing;
    notify();
    while (state.isPlaying && index < chunks.length) {
      state = Playback.startLine;
      notify();
      final line = chunks[index];
      final v = ss[line.lang];
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
        notify();

        index += 1;
      } else {
        state = Playback.endLine;
        notify();
        state = Playback.stop;
      }
    }
    notify(); // end while
  }

  Future<void> pause() async {
    state == Playback.pause;
    await tts.pause();
    notify();
  }

  Future<void> stop() async {
    state == Playback.stop;
    await tts.stop();
    chunks.clear();
    notify();
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
    notify();
    if (wasPlaying.isPlaying) {
      await play();
    }
  }

  void dispose() {
    // never close? streamController.close();
    state = Playback.stop;
    tts.stop();
  }
}

// Map the stream directly into Riverpod
final spap = StreamProvider<SpeakProgress>((ref) {
  // is right?
  ref.onDispose(DualTts.streamController.close);
  return DualTts.streamController.stream;
});

/// Transform async StreamProvider to fully synchronous provider
class SpeakNotifier extends Notifier<SpeakProgress> {
  @override
  SpeakProgress build() {
    // Listen to the async StreamProvider
    ref.listen<AsyncValue<SpeakProgress>>(spap, (previous, next) {
      // Update state whenever new data arrives
      next.whenData((v) {
        state = v;
      });
    });

    // Initial default value before stream emits anything
    return (Playback.stop, 0);
  }
}

// Synchronous Provider
final spsp = NotifierProvider<SpeakNotifier, SpeakProgress>(SpeakNotifier.new);

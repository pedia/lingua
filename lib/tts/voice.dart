import 'dart:collection';

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

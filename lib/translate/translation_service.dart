import 'dart:io';

import 'package:flutter/services.dart';

import '../settings/app_settings.dart';

import 'bundled_lexicon.dart';

class LanguagePair {
  const LanguagePair(this.source, this.target);

  final String source;
  final String target;

  String get id => '$source-$target';

  String get label => '${languageName(source)} → ${languageName(target)}';

  static String languageName(String code) => names[code] ?? code;

  static const names = {'en': 'English', 'zh': 'Chinese'};
}

class TranslationService {
  TranslationService(this.settings);

  static const _channel = MethodChannel('lingua/translate');

  final AppSettings settings;

  LanguagePair get pair =>
      LanguagePair(settings.sourceLang, settings.targetLang);

  String get engineLabel => switch (settings.engine) {
    TranslateEngine.onDevice =>
      Platform.isAndroid ? 'On-device (ML Kit)' : 'On-device (lexicon)',
  };

  Future<void> downloadOnDevice() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('downloadModel', {
        'source': 'en',
        'target': 'zh',
      });
      await _channel.invokeMethod<void>('downloadModel', {
        'source': 'zh',
        'target': 'en',
      });
    }
    await settings.setOnDeviceReady(true);
  }

  Future<void> deleteOnDevice() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('deleteModel', {
        'source': 'en',
        'target': 'zh',
      });
      await _channel.invokeMethod<void>('deleteModel', {
        'source': 'zh',
        'target': 'en',
      });
    }
    await settings.setOnDeviceReady(false);
  }

  Future<String> translate({
    required String text,
    required String source,
    required String target,
  }) async {
    final batch = await translateAll([text], source: source, target: target);
    return batch.single;
  }

  Future<List<String>> translateAll(
    List<String> texts, {
    required String source,
    required String target,
  }) async {
    if (texts.isEmpty) {
      return const [];
    }
    if (source == target) {
      return List<String>.from(texts);
    }
    switch (settings.engine) {
      case TranslateEngine.onDevice:
        if (!settings.onDeviceReady) {
          throw StateError(
            'Download the on-device English–Chinese pack in Settings.',
          );
        }
        if (Platform.isAndroid) {
          final out = <String>[];
          for (final text in texts) {
            final result = await _channel.invokeMethod<String>('translate', {
              'text': text,
              'source': source,
              'target': target,
            });
            out.add(result ?? text);
          }
          return out;
        }
        return [
          for (final text in texts) _lexiconTranslate(text, '$source-$target'),
        ];
    }
  }

  String _lexiconTranslate(String text, String pairId) {
    final table = bundledLexicons[pairId];
    if (table == null) {
      return text;
    }
    final keys = table.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    var remaining = text;
    final buffer = StringBuffer();
    while (remaining.isNotEmpty) {
      var matched = false;
      for (final key in keys) {
        if (remaining.toLowerCase().startsWith(key.toLowerCase())) {
          final after = remaining.substring(key.length);
          final boundary =
              after.isEmpty ||
              !RegExp(r'[A-Za-z]').hasMatch(after.substring(0, 1));
          if (boundary || _isCjk(key)) {
            final value = table[key] ?? '';
            if (value.isNotEmpty) {
              if (buffer.isNotEmpty && !_isCjk(value)) {
                buffer.write(' ');
              }
              buffer.write(value);
            }
            remaining = after.trimLeft();
            matched = true;
            break;
          }
        }
      }
      if (matched) {
        continue;
      }
      buffer.write(remaining[0]);
      remaining = remaining.substring(1);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isCjk(String value) =>
      RegExp(r'[\u3040-\u30ff\u3400-\u9fff]').hasMatch(value);
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TranslateEngine { onDevice }

enum PairDirection { enToZh, zhToEn }

enum ReaderViewMode { lingua, english, chinese }

enum TtsLanguageMode { english, chinese, follow }

class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs);

  final SharedPreferences _prefs;

  TranslateEngine get engine {
    final raw = _prefs.getString('translateEngine') ?? '';
    return TranslateEngine.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => TranslateEngine.onDevice,
    );
  }

  PairDirection get direction {
    final raw = _prefs.getString('pairDirection') ?? 'enToZh';
    return PairDirection.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => PairDirection.enToZh,
    );
  }

  ReaderViewMode get viewMode {
    final raw = _prefs.getString('viewMode') ?? 'lingua';
    return ReaderViewMode.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => ReaderViewMode.lingua,
    );
  }

  TtsLanguageMode get ttsLanguage {
    final raw = _prefs.getString('ttsLanguage') ?? 'follow';
    return TtsLanguageMode.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => TtsLanguageMode.follow,
    );
  }

  String get sourceLang => direction == PairDirection.enToZh ? 'en' : 'zh';
  String get targetLang => direction == PairDirection.enToZh ? 'zh' : 'en';

  double ttsRate(String lang) => _prefs.getDouble('ttsRate_$lang') ?? 0.45;

  double ttsPitch(String lang) => _prefs.getDouble('ttsPitch_$lang') ?? 1.0;

  String? ttsVoice(String lang) => _prefs.getString('ttsVoice_$lang');

  bool get onDeviceReady => _prefs.getBool('onDeviceReady') ?? false;

  Future<void> setEngine(TranslateEngine value) async {
    await _prefs.setString('translateEngine', value.name);
    notifyListeners();
  }

  Future<void> setDirection(PairDirection value) async {
    await _prefs.setString('pairDirection', value.name);
    notifyListeners();
  }

  Future<void> setViewMode(ReaderViewMode value) async {
    await _prefs.setString('viewMode', value.name);
    notifyListeners();
  }

  Future<void> setTtsLanguage(TtsLanguageMode value) async {
    await _prefs.setString('ttsLanguage', value.name);
    notifyListeners();
  }

  Future<void> setTtsRate(String lang, double value) async {
    await _prefs.setDouble('ttsRate_$lang', value);
    notifyListeners();
  }

  Future<void> setTtsPitch(String lang, double value) async {
    await _prefs.setDouble('ttsPitch_$lang', value);
    notifyListeners();
  }

  Future<void> setTtsVoice(String lang, String? value) async {
    if (value == null) {
      await _prefs.remove('ttsVoice_$lang');
    } else {
      await _prefs.setString('ttsVoice_$lang', value);
    }
    notifyListeners();
  }

  Future<void> setOnDeviceReady(bool value) async {
    await _prefs.setBool('onDeviceReady', value);
    notifyListeners();
  }
}

final recjk = RegExp(r'[\u3040-\u30ff\u3400-\u9fff]');

String detectLang(String sample) {
  final cjk = recjk.allMatches(sample).length;
  if (sample.isEmpty) {
    return 'en';
  }
  if (cjk / sample.length > 0.5) {
    return 'zh';
  }
  return 'en';
}

String detectLang(String sample) {
  final cjk = RegExp(r'[\u3040-\u30ff\u3400-\u9fff]').allMatches(sample).length;
  if (sample.isEmpty) {
    return 'en';
  }
  if (cjk / sample.length > 0.15) {
    return 'zh';
  }
  return 'en';
}

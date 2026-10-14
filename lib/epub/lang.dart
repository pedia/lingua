final recjk = RegExp(
  r'[\u4E00-\u9FFF\u3400-\u4DBF\u3040-\u309F\u30A0-\u30FF\uAC00-\uD7AF]',
);
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

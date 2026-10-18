final recjk = RegExp(
  r'[\u4E00-\u9FFF\u3400-\u4DBF\u3040-\u309F\u30A0-\u30FF\uAC00-\uD7AF]',
);

// TODO: c, j, k
Lang detectLang(String sample) {
  final cjk = recjk.allMatches(sample).length;
  if (sample.isEmpty) {
    return Lang.en;
  }
  // print('$cjk/${sample.length}=${(cjk / sample.length) > 0.5} $sample');
  if ((cjk / sample.length) > 0.5) {
    return Lang.zh;
  }
  return Lang.en;
}

enum Lang {
  unknown,
  all,
  en,
  es,
  jp,
  kr,
  zh;

  static Lang from(String? s) => switch (s) {
    'en' => en,
    'es' => es,
    'jp' => jp,
    'kr' => kr,
    'zh' => zh,
    '' => all,
    _ => unknown, // null
  };
}

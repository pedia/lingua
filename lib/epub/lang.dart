final recjk = RegExp(
  r'[\u4E00-\u9FFF\u3400-\u4DBF\u3040-\u309F\u30A0-\u30FF\uAC00-\uD7AF]',
);

Lang detectLang(String sample) {
  /// \p{P} 是 Unicode 标点符号属性（Punctuation），它不仅能精准匹配英文标点
  /// （如 ,, !, ., :, -, [] 等），还能完美匹配各种中文全角/半角标点
  /// （如 ，, ！, ：, ——, 《》, （） 等）。
  final clean = sample.replaceAll(RegExp(r'[\p{P}0-9]', unicode: true), '');
  final m = recjk.allMatches(clean).length;
  if (clean.isEmpty) {
    return Lang.en;
  }
  // print('$m/${sample.length}=${(m / sample.length) > 0.5} $sample');
  if ((m / clean.length) > 0.5) {
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

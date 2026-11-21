import '../chunk/chunk.dart';

/// replace [src] to [dest]
class Fixit {
  const Fixit(this.src, this.dest);
  final String src;
  final String dest;
}

const speakFixit = [
  Fixit('您', '你'),
  Fixit('&nbsp;', ' '),
];

const allFixit = [Fixit('您', '你'), Fixit('&nbsp;', ' ')];

extension ChunkFix on Chunk {
  /// pre-process for tts
  Chunk process() => clean().copyWith(
    text: _fix(text, lang),
    spans: spans.map((span) => span.fix(lang)).toList(),
  );

  /// clean for read
  Chunk clean() => copyWith(
    text: text != null ? applyFixits(text!, allFixit) : null,
    spans: spans.map((span) => span.clean()).toList(),
  );
}

String? _fix(String? s, Lang lang) {
  if (s == null) {
    return s;
  }
  if (lang == Lang.en) {
    return enfix(s);
  } else if (lang == Lang.zh) {
    return zhfix(s);
  }
  return s;
}

extension SpanFix on Span {
  Span fix(Lang lang) => Span(_fix(text, lang)!);
  Span clean() => Span(applyFixits(text, allFixit)!);
}

extension AnchorFix on Anchor {
  Anchor fix(Lang lang) => Anchor(_fix(text, lang)!, note: _fix(note, lang));
  Anchor clean() =>
      Anchor(applyFixits(text, allFixit)!, note: applyFixits(note!, allFixit));
}

final enc = Chunk(
  text: '''I spent \$45.50 on 3 items on 10/12/2026.
I spent forty-five dollars and fifty cents on three items on October twelfth, two thousand twenty-six.

Dr. Smith went to the U.N.
Doctor Smith went to the U. N.

https://gemini.google.com/app/c004c65a1cd1f1b6

##
**
[hello]
''',
  lang: Lang.en,
);

final zhc = Chunk(
  text: '''他递给她一本书，她笑着对他说谢谢
〇○◯ＯｏO''',
  lang: Lang.zh,
);

/// Helper function to apply a list of Fixit rules to a string
String? applyFixits(String? text, List<Fixit> fixits) {
  if (text == null) {
    return text;
  }
  var result = text;
  for (var fix in fixits) {
    result = result.replaceAll(fix.src, fix.dest);
  }
  return result;
}

String collapseSpace(String text) {
  return text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
}

String enfix(String text) {
  text = processNumbersAndCurrencies(text);
  text = processSymbols(text);
  text = removeUrl(text);
  text = processPunctuationClutter(text);
  return collapseSpace(text);
}

// ---------------------------------------------------------
// 1. Expand Numbers, Dates, and Currencies
// ---------------------------------------------------------
String processNumbersAndCurrencies(String text) {
  // Example fixits for common currency/symbol abbreviations
  const fixits = [
    Fixit(r'$', 'dollars '),
    Fixit(r'€', 'euros '),
    Fixit(r'£', 'pounds '),
  ];

  var result = applyFixits(text, fixits);

  // Custom regex logic for numbers/dates can be added here
  // e.g., converting "10/12/2026" to spoken words if needed
  return result!;
}

// ---------------------------------------------------------
// 2. Handle Abbreviations and Acronyms
// ---------------------------------------------------------
String processAbbreviations(String text) {
  const fixits = [
    Fixit('Dr.', 'Doctor'),
    Fixit('Mr.', 'Mister'),
    Fixit('Mrs.', 'Mistress'),
    Fixit('U.N.', 'U. N.'), // Spacing helps TTS pronounce letters individually
    Fixit('U.S.', 'U. S.'),
  ];

  return applyFixits(text, fixits)!;
}

// ---------------------------------------------------------
// 3. Strip or Convert Symbols and Code Snippets
// ---------------------------------------------------------
String processSymbols(String text) {
  const fixits = [
    Fixit('&', ' and '),
    Fixit('%', ' percent '),
    Fixit('@', ' at '),
    Fixit('#', ' hashtag '),
  ];

  var result = applyFixits(text, fixits)!;

  // Strip markdown code blocks or leftover tags if necessary
  result = result.replaceAll(
    RegExp(r'```[\s\S]*?```'),
    '',
  ); // remove code blocks

  return result;
}

// ---------------------------------------------------------
// 4. Clean Up Unwanted Punctuation Clutter
// ---------------------------------------------------------
String processPunctuationClutter(String text) {
  const fixits = [
    Fixit('!?', '!'),
    Fixit('?!', '?'),
    Fixit('...', ','), // Reduce excessive ellipsis to a standard pause/comma
  ];

  var result = applyFixits(text, fixits)!;

  // Clean up duplicated punctuation marks (e.g., "what!?!!?" -> "what?!")
  return result.replaceAllMapped(
    RegExp(r'([!?]){2,}'),
    (match) => match.group(1)!,
  );
}

String removeUrl(String text) {
  // Regular expression to match http/https URLs, www. domains, or standard web links
  final urlRegExp = RegExp(
    r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
    caseSensitive: false,
  );

  // Replace matches with a single space to preserve word separation
  return text.replaceAll(urlRegExp, ' ');
}

String zhfix(String text, {bool useEnglishS = false}) {
  text = normalizeChineseZeroInYears(text);
  text = normalizeChineseCenturyDecade(text, useEnglishS: useEnglishS);
  text = processZhPunctuationClutter(text);
  return collapseSpace(removeUrl(text));
}

/// Clean Chinese & mixed punctuation clutter
String processZhPunctuationClutter(String text) {
  const fixits = [
    Fixit('！？', '！'),
    Fixit('？！', '？'),
    Fixit('……', '，'),
    Fixit('...', '，'),
  ];

  var result = applyFixits(text, fixits)!;
  result = result.replaceAllMapped(
    RegExp(r'([！？!?]){2,}'),
    (match) => match.group(1)!,
  );

  return collapseSpace(result);
}

/// Normalizes all circle/O variants into '零' ONLY when used inside Chinese numbers or years
String normalizeChineseZeroInYears(String text) {
  // Matches any of: ○ (U+25CB), 〇 (U+3007), ◯ (U+25EF), Ｏ (U+FF2F), ｏ (U+FF4F), O, o, 0
  // when preceded or followed by Chinese numerals or '年'
  const zeroVariants = r'[○〇◯ＯｏOo0]';
  const chineseDigits = r'[一二三四五六七八九十零]';

  // Case 1: Between or next to Chinese digits (e.g., 二○○八, 一九○五, 二0二六)
  var result = text.replaceAllMapped(
    RegExp(
      '(?<=$chineseDigits)$zeroVariants+|$zeroVariants+(?=$chineseDigits)',
    ),
    (match) => '零' * match.group(0)!.length,
  );

  // Case 2: Followed directly by '年' after a Chinese digit (e.g., 二〇一○年 -> 二〇一零年)
  result = result.replaceAllMapped(
    RegExp('(?<=$chineseDigits)$zeroVariants+(?=年)'),
    (match) => '零' * match.group(0)!.length,
  );

  return result;
}

/// Converts Chinese century+decade phrases like '二十世紀三十年代' or '20世纪30年代'
/// into clean numeric form: '1930年代' (or '1930s' if [useEnglishS] is true).
String normalizeChineseCenturyDecade(String text, {bool useEnglishS = false}) {
  final suffix = useEnglishS ? 's' : '年代';

  // Helper to parse Chinese numerals (1-99) or Arabic digits into an int
  int? parseNum(String raw) {
    final trimmed = raw.trim();
    final arabic = int.tryParse(trimmed);
    if (arabic != null) return arabic;

    const digits = {
      '零': 0,
      '〇': 0,
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };

    if (trimmed == '十') return 10;
    if (trimmed == '廿') return 20;
    if (trimmed == '卅') return 30;

    if (trimmed.contains('十')) {
      final parts = trimmed.split('十');
      final tens = parts[0].isEmpty ? 1 : (digits[parts[0]] ?? 0);
      final ones = parts.length > 1 && parts[1].isNotEmpty
          ? (digits[parts[1]] ?? 0)
          : 0;
      return tens * 10 + ones;
    }

    return digits[trimmed];
  }

  // Matches: (not preceded by 公元前) + [Century] + 世纪/世紀 + [Decade] + 年代
  // Supports Arabic (1-25) and Chinese numerals (一 to 二十五, 廿, 卅)
  final pattern = RegExp(
    r'(?<!公元前)([一二三四五六七八九十廿卅\d]{1,3})世[纪紀]([一二三四五六七八九十廿卅\d]{1,3})年代',
  );

  var result = text.replaceAllMapped(pattern, (match) {
    final century = parseNum(match.group(1)!);
    final decade = parseNum(match.group(2)!);

    // Validate reasonable century (1..25) and decade (0, 10, 20..90)
    if (century == null || decade == null || century < 1 || century > 25) {
      return match.group(0)!;
    }

    // Standardize single-digit decade typos if any (e.g., "3年代" -> 30)
    final normalizedDecade = decade < 10 ? decade * 10 : decade;
    final startYear = (century - 1) * 100 + normalizedDecade;

    return '$startYear$suffix';
  });

  // Also handle relative centuries: 上世纪八十年代 -> 1980年代, 本世纪二十年代 -> 2020年代
  final relativePattern = RegExp(r'(上|本)世[纪紀]([一二三四五六七八九十廿卅\d]{1,3})年代');
  result = result.replaceAllMapped(relativePattern, (match) {
    final baseYear = match.group(1) == '上' ? 1900 : 2000;
    final decade = parseNum(match.group(2)!);
    if (decade == null) return match.group(0)!;
    final normalizedDecade = decade < 10 ? decade * 10 : decade;
    return '${baseYear + normalizedDecade}$suffix';
  });

  return result;
}

import 'chunk.dart';

/// Replace [src] with [dest].
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

final _ttsFixits = <Fixit>[
  ...allFixit,
  for (final f in speakFixit)
    if (!allFixit.any((a) => a.src == f.src && a.dest == f.dest)) f,
];

extension ChunkFix on Chunk {
  /// Pre-process chunk for TTS optimization while preserving [spans] and [Anchor]s.
  Chunk process() {
    if (this is Picture) return this;
    return copyWith(
      text: text != null ? _forTts(text!, lang) : null,
      spans: spans.isEmpty
          ? spans
          : [
              for (int i = 0; i < spans.length; i++)
                _fixSpan(
                  spans[i],
                  lang,
                  trimLeading: i == 0,
                  trimTrailing: i == spans.length - 1,
                ),
            ],
    );
  }

  /// Clean chunk for reading.
  Chunk clean() {
    if (this is Picture) return this;
    return copyWith(
      text: applyFixits(text, allFixit),
      spans: spans.isEmpty ? spans : [for (final s in spans) _cleanSpan(s)],
    );
  }

  /// Speakable TTS-ready plain text for this chunk (omitting footnote marker anchors).
  String get speak {
    if (this is Picture) return '';
    final String raw;
    if (text != null) {
      raw = text!;
    } else {
      if (spans.isEmpty) return '';
      final buf = StringBuffer();
      for (final s in spans) {
        if (s is Anchor && s.note != null) continue;
        buf.write(s.text);
      }
      raw = buf.toString();
    }
    if (raw.isEmpty) return '';
    return _forTts(raw, lang);
  }
}

extension ChapterFix on Chapter {
  /// Prepare all chunks for reading (cleaning text and resolving/constraining
  /// [Picture] dimensions via [Picture.updateSize] up to [maxWidth]).
  ///
  /// Caches the prepared chunks (including updated [Picture.w] and [Picture.h])
  /// on the [Chapter] so subsequent [forRead] and [LazyChapter.chunks] accesses
  /// reuse them without re-cleaning or reloading.
  List<Chunk> forRead({double? maxWidth}) {
    return cleanWith(
      (c) {
        if (c is Picture) {
          c.updateSize(maxWidth: maxWidth);
          return c;
        }
        return c.clean();
      },
      maxWidth: maxWidth,
    );
  }

  /// Pre-process all chunks for TTS playback.
  List<Chunk> process() => [for (final c in chunks) c.process()];
}

extension BookFix on Book {
  /// Prepare all chapters in this book for reading (cleaning text and
  /// updating/caching [Picture.w] and [Picture.h] up to [maxWidth] on each
  /// [Chapter]), invalidating any previously built search index only if at
  /// least one chapter was newly cleaned.
  void forRead({double? maxWidth}) {
    bool anyNewlyCleaned = false;
    for (final ch in chapters) {
      if (!ch.isCleaned) anyNewlyCleaned = true;
      ch.forRead(maxWidth: maxWidth);
    }
    if (anyNewlyCleaned) {
      invalidateIndex();
    }
  }
}

Span _cleanSpan(Span s) {
  if (s is Anchor) {
    return Anchor(
      applyFixits(s.text, allFixit)!,
      note: applyFixits(s.note, allFixit),
      link: s.link,
    );
  }
  return Span(applyFixits(s.text, allFixit)!);
}

Span _fixSpan(
  Span s,
  Lang lang, {
  bool trimLeading = true,
  bool trimTrailing = true,
}) {
  if (s is Anchor) {
    return Anchor(
      _forTts(
        s.text,
        lang,
        trimLeading: trimLeading,
        trimTrailing: trimTrailing,
      ),
      note: s.note != null ? _forTts(s.note!, lang) : null,
      link: s.link,
    );
  }
  return Span(
    _forTts(
      s.text,
      lang,
      trimLeading: trimLeading,
      trimTrailing: trimTrailing,
    ),
  );
}

String _forTts(
  String s,
  Lang lang, {
  bool trimLeading = true,
  bool trimTrailing = true,
}) =>
    _fix(
      applyFixits(s, _ttsFixits)!,
      lang,
      trimLeading: trimLeading,
      trimTrailing: trimTrailing,
    )!;

String? _fix(
  String? s,
  Lang lang, {
  bool trimLeading = true,
  bool trimTrailing = true,
}) {
  if (s == null) return null;
  if (lang == Lang.en) {
    return _enfix(s, trimLeading: trimLeading, trimTrailing: trimTrailing);
  } else if (lang == Lang.zh) {
    return _zhfix(s, trimLeading: trimLeading, trimTrailing: trimTrailing);
  } else if (lang == Lang.all) {
    var result = normalizeChineseZeroInYears(s);
    result = normalizeChineseCenturyDecade(result);
    result = _enfix(
      result,
      trimLeading: trimLeading,
      trimTrailing: trimTrailing,
    );
    return _collapseSpace(
      _processZhPunctuationClutter(result),
      trimLeading: trimLeading,
      trimTrailing: trimTrailing,
    );
  }
  var result = stripMarkdownAndCode(s);
  result = removeUrl(result);
  return _collapseSpace(
    result,
    trimLeading: trimLeading,
    trimTrailing: trimTrailing,
  );
}

extension SpanFix on Span {
  Span fix(Lang lang) => _fixSpan(this, lang);
  Span clean() => _cleanSpan(this);
}

extension AnchorFix on Anchor {
  Anchor fix(Lang lang) => Anchor(
    _fix(applyFixits(text, speakFixit), lang)!,
    note: note != null ? _fix(applyFixits(note!, speakFixit), lang) : null,
    link: link,
  );

  Anchor clean() => Anchor(
    applyFixits(text, allFixit)!,
    note: applyFixits(note, allFixit),
    link: link,
  );
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

/// Helper function to apply a list of Fixit rules to a string.
String? applyFixits(String? text, List<Fixit> fixits) {
  if (text == null) return null;
  var result = text;
  for (final fix in fixits) {
    result = result.replaceAll(fix.src, fix.dest);
  }
  return result;
}

final _multiHorizontalSpaceRegExp = RegExp(r'[ \t\u00A0]+');
final _newlineSpaceRegExp = RegExp(r' *\n+ *');
final _fencedCodeRegExp = RegExp(r'```[\s\S]*?```');
final _inlineCodeRegExp = RegExp(r'`([^`]+)`');
final _markdownLinkRegExp = RegExp(
  r'\[([^\]]*)\]\((https?:\/\/[^\s)]+)\)',
  caseSensitive: false,
);
final _markdownHeadingRegExp = RegExp(r'(^|\n)[ \t]*#{1,6}(?=[ \t]|$)\s*');
final _markdownEmphasisRegExp = RegExp(r'\*\*|__');
final _urlRegExp = RegExp(
  r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
  caseSensitive: false,
);

String _collapseSpace(
  String text, {
  bool trimLeading = true,
  bool trimTrailing = true,
}) {
  var result = text
      .replaceAll(_multiHorizontalSpaceRegExp, ' ')
      .replaceAll(_newlineSpaceRegExp, '\n');
  if (trimLeading) result = result.trimLeft();
  if (trimTrailing) result = result.trimRight();
  return result;
}

String collapseSpace(String text) => _collapseSpace(text);

/// Strip fenced code blocks, inline backticks, markdown headings, emphasis markers,
/// and unwrap markdown links while preserving visible link text.
String stripMarkdownAndCode(String text) {
  var result = text.replaceAll(_fencedCodeRegExp, ' ');
  result = result.replaceAllMapped(_inlineCodeRegExp, (m) => m.group(1)!);
  result = result.replaceAllMapped(
    _markdownLinkRegExp,
    (m) => (m.group(1) ?? '').trim().isNotEmpty ? m.group(1)! : ' ',
  );
  result = result.replaceAllMapped(_markdownHeadingRegExp, (m) => m.group(1)!);
  result = result.replaceAll(_markdownEmphasisRegExp, '');
  return result;
}

String enfix(String text) => _enfix(text);

String _enfix(
  String text, {
  bool trimLeading = true,
  bool trimTrailing = true,
}) {
  text = stripMarkdownAndCode(text);
  text = removeUrl(text);
  text = processAbbreviations(text);
  text = processNumbersAndCurrencies(text);
  text = processSymbols(text);
  text = processPunctuationClutter(text);
  return _collapseSpace(
    text,
    trimLeading: trimLeading,
    trimTrailing: trimTrailing,
  );
}

// ---------------------------------------------------------
// 1. Expand Numbers, Dates, and Currencies
// ---------------------------------------------------------
String processNumbersAndCurrencies(String text) {
  const fixits = [
    Fixit(r'$', 'dollars '),
    Fixit(r'€', 'euros '),
    Fixit(r'£', 'pounds '),
  ];
  return applyFixits(text, fixits)!;
}

// ---------------------------------------------------------
// 2. Handle Abbreviations and Acronyms
// ---------------------------------------------------------
final _abbrevPatterns = <(RegExp, String)>[
  (RegExp(r'(?<![A-Za-z])Mrs\.'), 'Mistress'),
  (RegExp(r'(?<![A-Za-z])Mr\.'), 'Mister'),
  (RegExp(r'(?<![A-Za-z])Dr\.'), 'Doctor'),
  (RegExp(r'(?<![A-Za-z])Prof\.'), 'Professor'),
  (RegExp(r'(?<![A-Za-z])U\.S\.A\.'), 'U. S. A.'),
  (RegExp(r'(?<![A-Za-z])U\.S\.'), 'U. S.'),
  (RegExp(r'(?<![A-Za-z])U\.N\.'), 'U. N.'),
  (RegExp(r'(?<![A-Za-z])U\.K\.'), 'U. K.'),
];

String processAbbreviations(String text) {
  var result = text;
  for (final (pattern, replacement) in _abbrevPatterns) {
    result = result.replaceAll(pattern, replacement);
  }
  return result;
}

// ---------------------------------------------------------
// 3. Convert Symbols and Strip Leftover Code Snippets
// ---------------------------------------------------------
String processSymbols(String text) {
  const fixits = [
    Fixit('&', ' and '),
    Fixit('%', ' percent '),
    Fixit('@', ' at '),
    Fixit('#', ' hashtag '),
  ];

  var result = text.replaceAll(_fencedCodeRegExp, ' ');
  result = applyFixits(result, fixits)!;
  return result;
}

// ---------------------------------------------------------
// 4. Clean Up Unwanted Punctuation Clutter
// ---------------------------------------------------------
String processPunctuationClutter(String text) {
  const fixits = [
    Fixit('!?', '!'),
    Fixit('?!', '?'),
    Fixit('...', ','),
    Fixit('…', ','),
  ];

  var result = applyFixits(text, fixits)!;
  return result.replaceAllMapped(
    RegExp(r'([!?]){2,}'),
    (match) => match.group(1)!,
  );
}

String removeUrl(String text) => text.replaceAll(_urlRegExp, ' ');

String zhfix(String text, {bool useEnglishS = false}) =>
    _zhfix(text, useEnglishS: useEnglishS);

String _zhfix(
  String text, {
  bool useEnglishS = false,
  bool trimLeading = true,
  bool trimTrailing = true,
}) {
  text = stripMarkdownAndCode(text);
  text = removeUrl(text);
  text = normalizeChineseZeroInYears(text);
  text = normalizeChineseCenturyDecade(text, useEnglishS: useEnglishS);
  text = _processZhPunctuationClutter(text);
  return _collapseSpace(
    text,
    trimLeading: trimLeading,
    trimTrailing: trimTrailing,
  );
}

String _processZhPunctuationClutter(String text) {
  const fixits = [
    Fixit('！？', '！'),
    Fixit('？！', '？'),
    Fixit('……', '，'),
    Fixit('...', '，'),
    Fixit('…', '，'),
  ];

  var result = applyFixits(text, fixits)!;
  return result.replaceAllMapped(
    RegExp(r'([！？!?]){2,}'),
    (match) => match.group(1)!,
  );
}

/// Clean Chinese & mixed punctuation clutter.
String processZhPunctuationClutter(String text) =>
    collapseSpace(_processZhPunctuationClutter(text));

/// Normalizes all circle/O variants into '零' ONLY when used inside Chinese numbers or years.
String normalizeChineseZeroInYears(String text) {
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

  final pattern = RegExp(
    r'(?<!公元前)([一二三四五六七八九十廿卅\d]{1,3})世[纪紀]([一二三四五六七八九十廿卅\d]{1,3})年代',
  );

  var result = text.replaceAllMapped(pattern, (match) {
    final century = parseNum(match.group(1)!);
    final decade = parseNum(match.group(2)!);

    if (century == null || decade == null || century < 1 || century > 25) {
      return match.group(0)!;
    }

    final normalizedDecade = decade < 10 ? decade * 10 : decade;
    final startYear = (century - 1) * 100 + normalizedDecade;

    return '$startYear$suffix';
  });

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

import 'book.dart';

List<Line> splitSentences(String text) {
  final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) {
    return const [];
  }

  final parts = cleaned.split(RegExp(r'(?<=[.!?…])\s+|(?<=[。！？])'));
  return [
    for (final part in parts)
      if (part.trim().isNotEmpty) Line(part.trim(), detectLang(part)),
  ];
}

String collapseWhitespace(String text) {
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

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

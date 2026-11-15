import '../chunk/chunk.dart';

class Fixit {
  const Fixit(this.src, this.dest);
  final String src;
  final String dest;
}

const speakFixit = [
  Fixit('○', '零'), // tts: 空心圆
  Fixit('您', '你'),
  Fixit('他', '男他'),
  Fixit('她', '女她'),
];

const allFixit = [Fixit('您', '你')];

final punctuation = RegExp(r'[\p{P}]', unicode: true);

extension ChunkFix on Chunk {
  Chunk fix(List<Fixit> ps) => copyWith(
    text: text?.fix(ps),
    spans: spans.map((span) => span.fix(ps)).toList(),
  );

  Chunk clean() => copyWith(
    text: text?.replaceAll(punctuation, ' '),
    // spans: spans.map(clean) =>
  );
}

extension SpanFix on Span {
  Span fix(List<Fixit> ps) => Span(text.fix(ps)!);
  Span clean(List<Fixit> ps) => Span(text.fix(ps)!);
}

extension AnchorFix on Anchor {
  Anchor fix(List<Fixit> ps) => Anchor(text.fix(ps)!, note: note.fix(ps));
}

extension StringFix on String? {
  String? fix(List<Fixit> ps) {
    if (this == null) return null;
    String s = this!;
    for (final e in ps) {
      s = s.replaceAll(e.src, e.dest);
    }
    return s;
  }
}

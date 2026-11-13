import 'lang.dart';

class Chunk {
  const Chunk({
    this.text = '',
    this.lang = Lang.unknown,
    this.idx,
    this.anchor,
    this.linkto,
  });
  final String text;
  final int? idx;

  /// anchor name
  final String? anchor;

  /// <a href="{linkto}" ...>
  final String? linkto;

  final Lang lang;
  @override
  String toString() => '#$idx:$lang: $text';
}

class Image extends Chunk {
  Image({required this.src, this.width, this.height});
  final double? width, height;
  final String src;
}

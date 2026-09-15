import 'package:archive/archive.dart';
import 'package:flutter/cupertino.dart';
import 'package:lingua/epub/parser.dart';

@immutable
class Line {
  const Line(this.text, [this.lang = '']);
  final String text;
  final String lang;

  @override
  String toString() => 'Line($text)$lang';

  @override
  bool operator ==(Object other) =>
      other is Line && text == other.text && lang == other.lang;

  @override
  int get hashCode => Object.hash(text, lang);
}

abstract class Chapter {
  String get title;
  List<Line> get lines;
  String get text;

  factory Chapter.from(String href, ArchiveFile file) {
    return ChapterStub._(href: href, file: file);
  }

  factory Chapter.cache({
    required String title,
    required String href,
    required List<Line> lines,
  }) {
    return ChapterStub.cache(href: href, title: title, lines: lines);
  }
}

class ChapterStub implements Chapter {
  ChapterStub._({required this.href, required this.file});
  // ChapterStub.fromArchive({required this.href, this.file});

  ChapterStub.cache({
    required this.href,
    required String title,
    required List<Line> lines,
  }) : _title = title,
       _lines = lines,
       file = ArchiveFile.noData('stub');

  final String href;

  @override
  String get title {
    if (_title == null) {
      _parse();
    }
    return _title!;
  }

  @override
  List<Line> get lines {
    if (_lines == null) {
      _parse();
    }
    return _lines!;
  }

  String? _title;
  List<Line>? _lines;

  void _parse() {
    final ch = EpubParser.decode(href, file);
    _title = ch.title;
    _lines = ch.lines;
  }

  final ArchiveFile file;

  @override
  String get text => lines.join('\n');

  // List<String> get texts => lines.map((l) => l.text).toList();

  Chapter copyWith(String? title, String? href, List<Line>? lines) {
    return ChapterStub.cache(
      href: href ?? this.href,
      title: title ?? this.title,
      lines: lines ?? this.lines,
    );
  }
}

class Book {
  const Book({
    required this.title,
    required this.author,
    this.language,
    required this.chapters,
  });

  final String title;
  final String author;
  final String? language;
  final List<Chapter> chapters;

  int get sentenceCount =>
      chapters.fold(0, (sum, chapter) => sum + chapter.lines.length);
}

class DrmEpubException implements Exception {
  const DrmEpubException();

  @override
  String toString() =>
      'EPUB is encrypted or DRM-protected and cannot be opened.';
}

class EpubParseException implements Exception {
  const EpubParseException(this.message);
  final String message;

  @override
  String toString() => message;
}

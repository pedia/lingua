import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:lingua/epub/epub.dart';
import 'package:lingua/epub/lang.dart';
import 'package:lingua/epub/parser.dart';

void main(List<String> args) {
  final book = EpubParser().parseBytes(File(args[0]).readAsBytesSync());
  print(book.title);
  print(book.author);
  print(book.description);
  for (int i = 0; i < book.chapters.length; i++) {
    final ch = book.chapters[i];
    print('# ${ch.title}');
    for (var c in ch.chunks) {
      print(c);
    }
    if (ch.chunks.length > 10) {
      break;
    }
  }
}

import 'package:lingua/chunk/chunk.dart';

void main(List<String> args) async {
  for (String a in args) {
    await dump(a);
  }
}

Future<void> dump(String fn) async {
  final book = await ChunkParser.parseFile(fn);
  print(book.title);
  print(book.author);
  // print(book.description);
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

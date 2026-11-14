import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saf/saf.dart';
import 'package:path/path.dart' as p;

import '../g.dart';
import '../ui/gadget.dart';
import '../ui/book.dart';
import 'chunk.dart';
import 'read.dart';
import '../data/model.dart';

class BookScreen extends StatelessWidget {
  const BookScreen(this.id, {super.key});
  final int id;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: open(Item.fromBox(id)),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return InfoScreen('Unable to open it\n${snapshot.error}');
      }
      if (snapshot.hasData) {
        return ReadScreen(id, snapshot.data!);
      }
      return const Center();
    },
  );
}

Future<Book?> open(Item item) async {
  Book? book;
  if (item.id == 5) {
    //   book = freya;
  } else if (item.id == 6) {
    //   book = sample();
  } else if (item.type == ItemType.file) {
    String fp = item.path;
    if (item.path.startsWith('content://')) {
      await requestStoragePermission();

      book = ChunkParser.parseBytes(await Saf().readFileBytes(fp));
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      fp = p.join(appDir.path, 'books', item.path);

      final file = File(fp);
      if (!file.existsSync()) {
        throw Exception('book:$item not exist');
      }
      book = await ChunkParser.parseFile(fp);
    }
  } else if (item.type == ItemType.assets) {
    final bd = await rootBundle.load(item.path);
    book = ChunkParser.parseBytes(bd.buffer.asInt8List());
  }

  return book;
}

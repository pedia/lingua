import 'package:flutter/material.dart';

import '../ui/gadget.dart';
import '../ui/book.dart';
import '../data/model.dart';
import 'chunk.dart';
import 'read.dart';

class BookScreen extends StatelessWidget {
  const BookScreen(this.id, {super.key});
  final int id;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: Item.fromBox(id).open(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return InfoScreen('Unable to open it\n${snapshot.error}');
      }
      if (snapshot.hasData) {
        return ReadScreen(id, snapshot.data!);
      }
      return InfoScreen('''Empty, 
error: ${snapshot.hasError}
data: ${snapshot.hasData}
''');
    },
  );
}

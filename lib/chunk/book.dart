import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/gadget.dart';
import '../ui/book.dart';
import '../data/model.dart';
import 'read.dart';

class BookScreen extends StatelessWidget {
  const BookScreen(this.id, {super.key});
  final int id;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) return;
      context.go('/shelf');
    },
    child: FutureBuilder(
      future: Item.fromBox(id).open(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InfoScreen('Unable to open it\n${snapshot.error}');
        }
        if (snapshot.hasData) {
          return ReadScreen(id, snapshot.data!);
        }
        return Material(child: Center(child: Text('Loading...')));
      },
    ),
  );
}

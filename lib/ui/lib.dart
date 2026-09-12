
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'reader_page.dart';
import '../epub/book.dart';
import '../epub/parser.dart';
import '../data/sample.dart';

/// Globally pump OpenFile event to Widgets
class OpenFile {
  static final _controller = StreamController<String>.broadcast();
  static Stream<String> get stream => _controller.stream;

  static void send(String fn) {
    _controller.add(fn);
  }

  static void dispose() {
    _controller.close();
  }
}

///

/// android
StreamSubscription? _intentSub;

class LibraryFrame extends ConsumerStatefulWidget {
  const LibraryFrame({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _LibraryFrameState();
}

class _LibraryFrameState extends ConsumerState<LibraryFrame> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();

    _subscription = OpenFile.stream.listen((fn) {
      debugPrint('Lib got[macos] $fn');
      setState(() => events.add(fn));
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    // android
    _intentSub?.cancel();
    super.dispose();
  }

  final events = <String>[];

  void openEpub(String path) {
    // Your logic to open the .epub file
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          ListTile(
            title: Text('sample'),
            leading: Icon(Icons.book_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => ChapterFrame(sample)),
              );
            },
          ),
          ListTile(
            title: Text('Paranoid Mage'),
            leading: Icon(Icons.book_rounded),
            onTap: () async {
              final d = await rootBundle.load('assets/paranoid-mage-dual.epub');
              final book = EpubParser().parseBytes(d.buffer.asInt8List());
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChapterFrame(book.chapters.first),
                  ),
                );
              }
            },
          ),
          ...events.map((e) => ListTile(title: Text(e))),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'reader.dart';
import '../epub/parser.dart';
import '../epub/book.dart';
import '../data/sample.dart';

/// Globally pump `OpenFile` event to Widgets
class OpenFile {
  static final _controller = StreamController<String>.broadcast();
  static Stream<String> get stream => _controller.stream;

  static void send(String fp) {
    cp(fp).then((nf) {
      _controller.add(nf);
    });
  }

  static void dispose() {
    _controller.close();
  }

  /// iOS/Android Must copy
  /// macOS → Better, but still safer to copy
  /// Always copy the file to a permanent location
  static Future<String> cp(String fp) async {
    final src = File(fp);

    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/books');

    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final fileName = p.basename(fp);
    final newPath = '${booksDir.path}/$fileName';

    await src.copy(newPath);
    return newPath;
  }
}

enum ItemType { assets, file, demo, debug }

class Item {
  Item({
    required this.name,
    required this.path,
    required this.type,
    this.progress = const Progress(),
  });
  final ItemType type;
  final String path;
  final String name;
  Progress progress;
}

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
      debugPrint('lib got $fn');
      setState(
        () => items.add(Item(type: ItemType.file, path: fn, name: p.basename(fn))),
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();

    super.dispose();
  }

  Future<Book?> openEpub(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }

    return const EpubParser().parseBytes(await file.readAsBytes());
  }

  final items = <Item>[
    Item(
      name: 'Paranoid Mage',
      path: 'assets/paranoid-mage-dual.epub',
      type: ItemType.assets,
    ),
    Item(
      name: 'Mother of Learning',
      path: 'assets/mother-of-learning-dual.epub',
      type: ItemType.assets,
    ),
    Item(name: 'Sample', path: '', type: ItemType.demo),
    Item(
      name: 'Debug, 中文',
      path: '事實上，我想我並不記得這個月之前噴泉是什麼樣子',
      type: ItemType.debug,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final fontName = DefaultTextStyle.of(context).style.fontFamily;

    return Scaffold(
      appBar: AppBar(
        title: Text('Lingua Reader'),
        actions: [
          IconButton(
            icon: Icon(Icons.add, size: 36),
            onPressed: () async {
              final result = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: const ['epub'],
              );
              if (result?.files != null) {
                for (final file in result!.files) {
                  OpenFile.send(file.path!);
                }
              }
            },
          ),
        ],
      ),
      body: Scrollbar(
        child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final e = items[index];
            return ListTile(
              title: e.type == ItemType.debug
                  ? Text('${e.name} $fontName')
                  : Text(e.name),
              subtitle: e.type == ItemType.debug ? Text(e.path) : null,
              leading: Icon(Icons.book_rounded),
              onTap: () async {
                Book? book;
                if (e.type == ItemType.assets) {
                  final d = await rootBundle.load(e.path);
                  book = EpubParser().parseBytes(d.buffer.asInt8List());
                } else if (e.type == ItemType.file) {
                  book = await openEpub(e.path);
                } else if (e.type == ItemType.demo) {
                  book = sample;
                }

                if (context.mounted && book != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BookFrame(book!, Progress()),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}

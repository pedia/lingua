import 'dart:async';
import 'package:lingua/g.dart';
import 'package:universal_io/universal_io.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'book.dart';
import 'font.dart';
import 'setting.dart';
import 'voice_setting.dart';
import '../silver.dart';
import '../page.dart';
import '../demo.dart';
import '../hive.dart';

import '../data/model.dart';
import '../data/sample.dart';
import '../epub/parser.dart';
import '../epub/epub.dart';

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
    final booksDir = Directory(p.join(appDir.path, 'books'));

    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final fileName = p.basename(fp);
    final newPath = '${booksDir.path}/$fileName';

    await src.copy(newPath);
    return newPath;
  }
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
      ref
          .read(itemsProvider.notifier)
          .add(
            Item(
              id: nextId(),
              type: ItemType.file,
              path: fn,
              name: p.basename(fn).replaceAll('.epub', ''),
            ),
          );

      // setState(
      //   () => items.add(
      //     Item(type: ItemType.file, path: fn, name: p.basename(fn)),
      //   ),
      // );
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

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsProvider);

    return Scaffold(
      appBar: AppBar(
        // title: Text('📘 Bilingualism'), // 📖📕📚📘📙
        actions: [
          IconButton(
            icon: Icon(
              Icons.developer_mode,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () async {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (context) => PageFrame()),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (String cv) async {
              if (cv == 'scan') {
                scan();
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => switch (cv) {
                    'font' => FontFrame(),
                    'setting' => SettingFrame(),
                    'search' => SilverFrame(),
                    'page' => PageFrame(),
                    'demo' => DemoFrame(),
                    'hive' => HiveFrame(),
                    'voice' => EngineSettingPage.from(context),
                    _ => FontFrame(),
                  },
                ),
              );
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem(value: 'search', child: Text('debug:Silver')),
              PopupMenuItem(value: 'page', child: Text('debug:Page')),
              PopupMenuItem(value: 'demo', child: Text('debug:Demo')),
              PopupMenuItem(value: 'font', child: Text('debug:Font')),
              PopupMenuItem(value: 'setting', child: Text('Setting')),
              PopupMenuItem(value: 'replace', child: Text('Replace')),
              PopupMenuItem(
                value: 'voice',
                child: Text('Voice Setting'),
              ),
              PopupMenuItem(value: 'hive', child: Text('Hive Console')),
              PopupMenuItem(value: 'scan', child: Text('Scan')),
            ],
            child: Icon(Icons.more_vert, size: 36),
          ),
        ],
      ),
      body: Scrollbar(
        child: ListView.builder(
          primary: true,
          key: PageStorageKey<String>('lib'),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final e = items[index];
            // print('lib build $index author: ${e.author}');
            return ListTile(
              title: Text(e.name!),
              subtitle: Text(e.subtitle),
              leading: boxImage('icon-${e.id}'),
              onTap: () async {
                Book? book;
                if (e.type == ItemType.assets) {
                  final d = await rootBundle.load(e.path);
                  book = EpubParser().parseBytes(d.buffer.asInt8List());
                } else if (e.type == ItemType.file) {
                  book = await openEpub(e.path);
                } else if (e.type == ItemType.demo) {
                  book = sample();
                }

                // book cover image thumbnail
                if (book != null && gbox.get('icon-${e.id}') == null) {
                  final cb = book.coverBytes;
                  if (cb != null) {
                    gbox.put('icon-${e.id}', iconify(cb));
                  }
                }

                print("${e.id}: ${book?.author}");

                if (book != null &&
                    book.author.isNotEmpty &&
                    e.author == null) {
                  ref
                      .read(itemsProvider.notifier)
                      .update(e.id, author: book.author, name: book.title);
                }

                if (context.mounted && book != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BookFrame(
                        id: e.id,
                        book: book!,
                        progress:
                            e.progress ??
                            Progress(chapterIndex: 0, lineIndex: 0),
                      ),
                    ),
                  );
                }

                ref.read(itemsProvider.notifier).touch(e.id);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.library_add),
        onPressed: () async {
          final result = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: const ['epub'],
            allowMultiple: true,
          );
          if (result?.files != null) {
            for (final file in result!.files) {
              OpenFile.send(file.path!);
            }
          }
        },
      ),
    );
  }

  void scan() async {
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'books'));

    final items = ref.read(itemsProvider);

    int c = 0;

    await for (final e in booksDir.list()) {
      if (e.path.endsWith('.epub')) {
        if (!items.any((i) => i.path == e.path)) {
          ref
              .read(itemsProvider.notifier)
              .add(
                Item(
                  id: nextId(),
                  type: ItemType.file,
                  path: e.path,
                  name: p.basename(e.path).replaceAll('.epub', ''),
                ),
              );
          c += 1;
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$c added')));
    }
  }
}

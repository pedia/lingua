import 'dart:async';
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
import 'voice.dart';
import 'demo.dart';

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
          .add(Item(type: ItemType.file, path: fn, name: p.basename(fn)));

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
    final items = ref.watch(itemsProvider).items;
    final fontName = DefaultTextStyle.of(context).style.fontFamily;

    return Scaffold(
      appBar: AppBar(
        title: Text('bilingualism 📘'), // 📖📕📚📘📙
        actions: [
          IconButton(
            icon: Icon(Icons.library_add, size: 36),
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
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (String cv) async {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => switch (cv) {
                    'font' => FontFrame(),
                    'setting' => SettingFrame(),
                    'tts-setting' => VoiceSettingPage.from(context),
                    'demo' => DemoFrame(),
                    _ => FontFrame(),
                  },
                ),
              );
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem(value: 'setting', child: Text('Setting')),
              PopupMenuItem(value: 'search', child: Text('Search')),
              PopupMenuItem(value: 'replace', child: Text('Replace')),
              PopupMenuItem(value: 'tts-setting', child: Text('TTS Setting')),
              PopupMenuItem(value: 'font', child: Text('Font Demo')),
              PopupMenuItem(value: 'demo', child: Text('Rich Text')),
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
            return ListTile(
              title: e.type == ItemType.debug
                  ? Text('${e.name} $fontName')
                  : Text(e.name),
              subtitle: e.type != ItemType.debug ? Text(e.path) : null,
              leading: Icon(
                Icons.library_books,
                color: Theme.of(context).focusColor,
              ),
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

                if (context.mounted && book != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BookFrame(
                        book: book!,
                        path: e.path,
                        progress: e.progress,
                      ),
                    ),
                  );
                }

                ref.read(itemsProvider.notifier).touch(e);
              },
            );
          },
        ),
      ),
    );
  }
}

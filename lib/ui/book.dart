import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:saf/saf.dart';
import 'package:permission_handler/permission_handler.dart';

import '../settings/setting.dart';
import 'setting.dart';
import 'voice_setting.dart';
import 'font.dart';
import '../hw.dart';
import '../g.dart';
import 'chapter_list.dart';
import '../data/model.dart';
import '../epub/epub.dart' as epub;
import '../epub/parser.dart' as epub;
import '../demo/freya.dart';
import '../data/sample.dart';
import 'gadget.dart';

class ArchiveProvider extends FileProvider {
  ArchiveProvider(String base, this.files) : base = Uri(path: base);
  final Uri base;
  final Map<String, ArchiveFile> files;

  @override
  Uint8List bytes(String path) {
    String fp = base.resolve(path).path.toLowerCase();

    // Uri decode
    if (fp.contains('%')) {
      fp = Uri.decodeComponent(fp);
    }
    debugPrint('$path => $fp');
    return files[fp]?.content ?? Uint8List.fromList([]);
  }
}

final bookProvider = FutureProvider.autoDispose.family<epub.Book?, int>((
  ref,
  id,
) async {
  final m = box.get('item2:$id');
  if (m == null) throw Exception('item:$id not exist');

  final item = m as Item;
  final book = await item.open();
  if (book != null) {
    item.apply(book);
  }
  return book;
});

class Progress {
  const Progress({this.ci = 0, this.li = 0, this.offset});
  final int ci;
  final int li;
  final double? offset;

  factory Progress.fromJson(Map<String, dynamic> json) => Progress(
    ci: json['ci'] ?? 0,
    li: json['li'] ?? 0,
    offset: json['offset'],
  );

  Map<String, dynamic> toJson() => {"ci": ci, "li": li, "offset": ?offset};

  Progress copyWith({int? ci, int? li, double? offset}) => Progress(
    ci: ci ?? this.ci,
    li: li ?? this.li,
    offset: offset ?? this.offset,
  );
}

//
class ItemState {
  ItemState({
    required this.id,
    this.read = const Progress(),
    this.speak = const Progress(),
    this.readChapterIndex = 0,
    this.offset = 0,
    this.speakChapterIndex = 0,
    this.speakLine = 0,
  });
  final int id;
  final Progress read;
  final Progress speak;
  final int readChapterIndex;
  final double offset;
  final int speakChapterIndex;
  final int speakLine;

  ItemState copyWith({
    int? id,
    Progress? read,
    Progress? speak,
    int? readChapterIndex,
    double? offset,
    int? speakChapterIndex,
    int? speakLine,
  }) => ItemState(
    id: id ?? this.id,
    read: read ?? this.read,
    speak: speak ?? this.speak,
    readChapterIndex: readChapterIndex ?? this.readChapterIndex,
    offset: offset ?? this.offset,
    speakChapterIndex: speakChapterIndex ?? this.speakChapterIndex,
    speakLine: speakLine ?? this.speakLine,
  );

  factory ItemState.fromJson(Map<String, dynamic> json) => ItemState(
    id: json['id'],
    read: Progress.fromJson(json['read'].cast<String, dynamic>()),
    speak: Progress.fromJson(json['speak'].cast<String, dynamic>()),
    readChapterIndex: json['readChapterIndex'] ?? 0,
    offset: json['offset'] ?? 0.0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'read': read.toJson(),
    'speak': speak.toJson(),
    'readChapterIndex': readChapterIndex,
    'offset': offset,
    'speakChapterIndex': speakChapterIndex,
    'speakLine': speakLine,
  };

  // static ItemState fromBox(int id) => box.get('is:$id') ?? ItemState(id: id);
}

// AsyncNotifier family tracking just progress for a book ID
class ItemStateNotifier extends AutoDisposeFamilyNotifier<ItemState, int> {
  @override
  ItemState build(int id) {
    final ItemState? m = box.get('is:$id');
    return m ?? ItemState(id: id);
  }

  void update({
    int? readChapterIndex,
    double? offset,
    int? speakChapterIndex,
    int? speakLine,
  }) {
    state = state.copyWith(
      readChapterIndex: readChapterIndex,
      offset: offset,
      speakChapterIndex: speakChapterIndex,
      speakLine: speakLine,
    );
    box.put('is:${state.id}', state);
  }

  void updateDelta(int speakLineDelta) {
    state = state.copyWith(speakLine: state.speakLine + speakLineDelta);
    box.put('is:${state.id}', state);
  }
}

/// short for ItemStateProvider
final isp =
    AutoDisposeNotifierProvider.family<ItemStateNotifier, ItemState, int>(
      ItemStateNotifier.new,
      name: 'ItemState',
    );

extension ItemExt on Item {
  Item apply(epub.Book book) {
    if (book.coverBytes != null) {
      sbox.get('icon:$id').then((ib) {
        if (ib == null) {
          sbox.put('icon:$id', iconify(book.coverBytes!));
        }
      });
    }

    if ((book.author.isNotEmpty && author == null) ||
        (book.description.isNotEmpty && description == null)) {
      print('$this apply $book');
      return copyWith(
        // make sure apply once
        name: book.title.isEmpty ? null : book.title,
        author: author != null ? null : book.author,
        description: description != null ? null : book.description,
      );
    }
    return this;
  }

  Future<epub.Book?> open() async {
    epub.Book? book;
    if (id == 5) {
      book = freya;
    } else if (id == 6) {
      book = sample();
    } else if (type == ItemType.file) {
      String fp = path;
      if (path.startsWith('content://')) {
        await requestStoragePermission();

        book = const epub.EpubParser().parseBytes(
          await Saf().readFileBytes(fp),
        );
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        fp = p.join(appDir.path, 'books', path);

        final file = File(fp);
        if (!file.existsSync()) {
          throw Exception('book:$type/$path not exist');
        }
        book = const epub.EpubParser().parseBytes(await file.readAsBytes());
      }
    } else if (type == ItemType.assets) {
      final d = await rootBundle.load(path);
      book = epub.EpubParser().parseBytes(d.buffer.asInt8List());
    }

    return book;
  }

  Future<void> remove() async {
    if (type == ItemType.file && !path.startsWith('content://')) {
      final docs = await getApplicationDocumentsDirectory();
      final fp = p.join(docs.path, 'books', path);
      await File(fp).delete();
    }

    box.delete('item:$id');
    box.delete('item-state:$id');
    box.delete('is:$id');
    box.delete('icon:$id');
    box.delete('note:$id');
  }

  ItemState get state => box.get('is:$id') ?? ItemState(id: id);
  void saveState(ItemState state) => box.put('is:$id', state);
}

Future<bool> requestStoragePermission() async {
  // For Android 13+ (API 33+), specific granular media permissions are used,
  // but for general folder access/documents use storage status:
  var status = await Permission.storage.request();

  if (status.isGranted) {
    print('Storage permission granted.');
    return true;
  } else if (status.isPermanentlyDenied) {
    // Open app settings if the user permanently denied
    openAppSettings();
  }

  print('Storage permission denied.');
  return false;
}

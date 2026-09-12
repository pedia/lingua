import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../epub/book.dart';

class BookNotifier extends Notifier<Book> {
  @override
  Book build() {
    return Book(title: '', author: '', language: '', chapters: <Chapter>[]);
  }
}

// final currentChapterProvider = NotifierProvider<BookNotifier, Book>(Book.empty);

final store = FutureProvider<Store>((ref) async {
  return await Store.open();
});

class Item {
  Item({
    required this.id,
    required this.title,
    required this.author,
    required this.fileName,
    this.lastChapter = 0,
    this.lastSentence = 0,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  final String title;
  final String fileName;
  final String id;
  final String author;
  int lastChapter;
  int lastSentence;
  final DateTime addedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'fileName': fileName,
    'lastChapter': lastChapter,
    'lastSentence': lastSentence,
    'addedAt': addedAt.toIso8601String(),
  };

  factory Item.fromJson(Map<String, Object?> json) {
    return Item(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      fileName: json['fileName'] as String,
      lastChapter: json['lastChapter'] as int? ?? 0,
      lastSentence: json['lastSentence'] as int? ?? 0,
      addedAt:
          DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class Store {
  Store._(this._root);

  factory Store.memory(Directory root) => Store._(root);

  final Directory _root;
  final List<Item> items = [];

  Directory get booksDir => Directory(p.join(_root.path, 'books'));
  File get _indexFile => File(p.join(_root.path, 'library.json'));

  static Future<Store> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, 'lingua'));
    final store = Store._(root);
    try {
      await store._load();
    } catch (e) {
      print('store load failed $e');
    }
    return store;
  }

  Future<void> _load() async {
    await _root.create(recursive: true);
    await booksDir.create(recursive: true);
    if (!_indexFile.existsSync()) {
      return;
    }
    final decoded = jsonDecode(await _indexFile.readAsString());
    if (decoded is! List) {
      return;
    }
    items
      ..clear()
      ..addAll(
        decoded.map(
          (item) => Item.fromJson(Map<String, Object?>.from(item as Map)),
        ),
      );
  }

  Future<void> _save() async {
    await _indexFile.writeAsString(
      jsonEncode(items.map((book) => book.toJson()).toList()),
    );
  }

  File bookFile(Item book) => File(p.join(booksDir.path, book.fileName));

  Future<Item> importEpub({
    required String sourcePath,
    required String title,
    required String author,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final fileName = '$id.epub';
    await File(sourcePath).copy(p.join(booksDir.path, fileName));
    final record = Item(
      id: id,
      title: title,
      author: author,
      fileName: fileName,
    );
    items.insert(0, record);
    await _save();
    return record;
  }

  Future<void> saveProgress(Item book) => _save();

  Future<void> remove(Item book) async {
    items.removeWhere((item) => item.id == book.id);
    final file = bookFile(book);
    if (file.existsSync()) {
      await file.delete();
    }
    await _save();
  }
}

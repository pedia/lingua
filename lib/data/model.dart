import 'package:meta/meta.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../g.dart';

part 'model.g.dart';

/// current index of chapter and line
@JsonSerializable(createJsonSchema: false)
class Progress {
  const Progress({this.chapterIndex = 0, this.lineIndex = 0, this.offset = 0});
  final int chapterIndex;
  final int lineIndex;
  final double offset; // ScrollController offset

  Progress copyWith({int? chapter, int? line, double? offset}) => Progress(
    chapterIndex: chapter ?? chapterIndex,
    lineIndex: line ?? lineIndex,
    offset: offset ?? this.offset,
  );

  @override
  String toString() =>
      'Progress{$chapterIndex,$lineIndex,${offset.toStringAsFixed(2)}}';

  factory Progress.fromJson(Map<String, Object?> json) =>
      _$ProgressFromJson(json);
  Map<String, dynamic> toJson() => _$ProgressToJson(this);
}

enum ItemType { assets, file, demo, debug }

@immutable
class Item {
  const Item({
    required this.name,
    required this.path,
    required this.type,
    this.progress = const Progress(),
  });
  final ItemType type;
  final String path;
  final String name;
  final Progress progress;

  Item copyWith({
    ItemType? type,
    String? path,
    String? name,
    Progress? progress,
  }) {
    return Item(
      type: type ?? this.type,
      path: path ?? this.path,
      name: name ?? this.name,
      progress: progress ?? this.progress,
    );
  }
}

class ItemList extends Notifier<List<Item>> {
  @override
  List<Item> build() => [
    Item(
      name: 'The Little Prince',
      path: 'assets/the-little-prince-dual.epub',
      type: ItemType.assets,
    ),
    Item(
      name: 'Super Supportive',
      path: 'assets/super-supportive-dual.epub',
      type: ItemType.assets,
    ),
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
    if (!bool.fromEnvironment('dart.vm.product'))
      Item(name: 'Sample', path: '', type: ItemType.demo),
    if (!bool.fromEnvironment('dart.vm.product'))
      Item(
        name: 'Debug, 中文',
        path: '事實上，我想"我"並不記得“這個”月之前噴泉是什麼樣子',
        type: ItemType.debug,
      ),
  ];
  void add(Item target) {
    state = [target, ...state];
  }

  void updateProgress(String path, Progress progress) {
    print('update $path $progress');
    state = [
      for (final e in state)
        if (e.path == path) e.copyWith(progress: progress) else e,
    ];
  }

  /// move `target` to the first place
  void touch(Item target) {
    state = [target, ...state.where((e) => e.path != target.path)];
  }

  void remove(Item target) {
    state = state.where((e) => e.path != target.path).toList();
  }
}

final itemsProvider = NotifierProvider<ItemList, List<Item>>(
  ItemList.new,
  name: 'itemsProvider',
);

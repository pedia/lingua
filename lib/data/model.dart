import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

import '../g.dart';

part 'model.freezed.dart';
part 'model.g.dart';

/// current index of chapter and line
@freezed
abstract class Progress with _$Progress {
  const factory Progress({
    @Default(0) int chapterIndex,
    @Default(0) int lineIndex,
    @Default(0.0) double offset,
  }) = _Progress;

  const Progress._();

  factory Progress.fromJson(Map<String, Object?> json) =>
      _$ProgressFromJson(json);

  @override
  Map<String, Object?> toJson() => _$ProgressToJson(this as _Progress);

  @override
  String toString() =>
      'Progress{$chapterIndex,$lineIndex,${offset.toStringAsFixed(2)}}';
}

enum ItemType { assets, file, demo, debug }

@freezed
abstract class Item with _$Item {
  @JsonSerializable(explicitToJson: true)
  const factory Item({
    required ItemType type,
    required String path,
    required String name,
    @Default(Progress()) Progress progress,
  }) = _Item;

  factory Item.fromJson(Map json) =>
      _$ItemFromJson(json.cast<String, dynamic>());

  @override
  Map<String, dynamic> toJson() => _$ItemToJson(this as _Item);
}

@freezed
abstract class ItemList with _$ItemList {
  const factory ItemList({@Default([]) List<Item> items}) = _ItemList;

  const ItemList._();

  ItemList addItem(Item target) => copyWith(items: [target, ...items]);

  ItemList updateItemProgress(String path, Progress progress) => copyWith(
    items: [
      for (final e in items)
        if (e.path == path) e.copyWith(progress: progress) else e,
    ],
  );

  /// move `target` to the first place
  ItemList touchItem(Item target) =>
      copyWith(items: [target, ...items.where((e) => e.path != target.path)]);

  ItemList removeItem(Item target) =>
      copyWith(items: items.where((e) => e.path != target.path).toList());

  factory ItemList.fromJson(List<Map> json) => ItemList(
    items: json.map((e) => Item.fromJson(e.cast<String, dynamic>())).toList(),
  );

  List<Map> toJson() => items.map((e) => e.toJson()).toList();
}

class ItemListNotifier extends Notifier<ItemList> {
  @override
  ItemList build() {
    Future.microtask(() => load());

    return ItemList();
  }

  void add(Item target) {
    state = state.addItem(target);
  }

  void updateProgress(String path, Progress progress) {
    print('update $path $progress');
    state = state.updateItemProgress(path, progress);
    save();
  }

  /// move `target` to the first place
  void touch(Item target) {
    state = state.touchItem(target);
    save();
  }

  void remove(Item target) {
    state = state.removeItem(target);
    save();
  }

  Future load() async {
    final jl = gbox.get('items');
    state = jl is List && jl.isNotEmpty
        ? ItemList.fromJson(jl.cast<Map>())
        : ItemList(
            items: [
              const Item(
                name: 'The Little Prince',
                path: 'assets/the-little-prince-dual.epub',
                type: ItemType.assets,
              ),
              const Item(
                name: 'Super Supportive',
                path: 'assets/super-supportive-dual.epub',
                type: ItemType.assets,
              ),
              const Item(
                name: 'Paranoid Mage',
                path: 'assets/paranoid-mage-dual.epub',
                type: ItemType.assets,
              ),
              const Item(
                name: 'Mother of Learning',
                path: 'assets/mother-of-learning-dual.epub',
                type: ItemType.assets,
              ),
              if (!bool.fromEnvironment('dart.vm.product'))
                const Item(name: 'Sample', path: '', type: ItemType.demo),
              if (!bool.fromEnvironment('dart.vm.product'))
                const Item(
                  name: 'Debug, 中文',
                  path: '事實上，我想"我"並不記得“這個”月之前噴泉是什麼樣子',
                  type: ItemType.debug,
                ),
            ],
          );
  }

  void save() {
    gbox.put('items', state.toJson());
  }
}

final itemsProvider = NotifierProvider<ItemListNotifier, ItemList>(
  ItemListNotifier.new,
  name: 'itemsProvider',
);

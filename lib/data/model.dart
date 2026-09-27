import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

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

  factory Progress.fromJson(Map<String, dynamic> json) =>
      _$ProgressFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$ProgressToJson(this as _Progress);

  @override
  String toString() =>
      'Progress{$chapterIndex,$lineIndex,${offset.toStringAsFixed(2)}}';
}

enum ItemType { assets, file, demo, debug }

class Item {
  const Item({
    required this.id,
    required this.type,
    required this.path,
    this.name,
    this.author,
    this.progress,
    this.percent = 0,
  });

  final int id;
  final ItemType type;
  final String path;
  final String? name;
  final String? author;
  final Progress? progress;
  final double percent;

  String get subtitle => [
    if (author != null) author,
    if (percent > 0) '${percent.toStringAsFixed(0)}%',
  ].join(' ');

  factory Item.fromJson(Map<String, dynamic> json) => Item(
    id: (json['id'] as num).toInt(),
    type: json['type'] is int
        ? ItemType.values[json['type'] as int]
        : ItemType.values[[
            'assets',
            'file',
            'demo',
            'debug',
          ].indexOf(json['type'] as String)],
    path: json['path'] as String,
    name: json['name'] as String?,
    author: json['author'] as String?,
    progress: json['progress'] == null
        ? null
        : Progress.fromJson((json['progress'] as Map).cast<String, dynamic>()),
    percent: (json['percent'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type.index,
    'path': path,
    'name': name,
    'author': author,
    'progress': progress?.toJson(),
    'percent': percent,
  };

  Item copyWith({
    int? id,
    ItemType? type,
    String? path,
    String? name,
    String? author,
    Progress? progress,
    double? percent,
  }) => Item(
    id: id ?? this.id,
    type: type ?? this.type,
    path: path ?? this.path,
    name: name ?? this.name,
    author: author ?? this.author,
    progress: progress ?? this.progress,
    percent: percent ?? this.percent,
  );
}

class ItemListNotifier extends Notifier<List<Item>> {
  @override
  List<Item> build() {
    Future.microtask(() => load());

    return [];
  }

  /// add means, put it at 1st place
  void add(Item target) {
    state = [target, ...state];
  }

  void update(int id, {Progress? progress, String? author, String? name}) {
    print('item($id) update $progress $author');
    state = [
      for (final e in state)
        if (e.id == id)
          e.copyWith(progress: progress, author: author, name: name)
        else
          e,
    ];
    save();
  }

  /// Move target to 1st place
  void touch(int id) {
    state = [
      state.where((e) => e.id == id).first,
      ...state.where((e) => e.id != id),
    ];
    save();
  }

  void remove(int id) {
    state = state.where((e) => e.id != id).toList();
    save();
  }

  final builtin = [
    const Item(
      id: 1,
      name: 'The Little Prince',
      path: 'assets/the-little-prince-dual.epub',
      type: ItemType.assets,
    ),
    const Item(
      id: 2,
      name: 'Super Supportive',
      path: 'assets/super-supportive-dual.epub',
      type: ItemType.assets,
    ),
    const Item(
      id: 3,
      name: 'Paranoid Mage',
      path: 'assets/paranoid-mage-dual.epub',
      type: ItemType.assets,
    ),
    const Item(
      id: 4,
      name: 'Mother of Learning',
      path: 'assets/mother-of-learning-dual.epub',
      type: ItemType.assets,
    ),
    if (!bool.fromEnvironment('dart.vm.product'))
      const Item(id: 5, name: 'Sample', path: '', type: ItemType.demo),
    if (!bool.fromEnvironment('dart.vm.product'))
      const Item(
        id: 6,
        name: 'Debug, 中文',
        path: '事實上，我想"我"並不記得“這個”月之前噴泉是什麼樣子',
        type: ItemType.debug,
      ),
  ];

  Future load() async {
    final jl = gbox.get('items2');
    state = (jl is List && jl.isNotEmpty)
        ? [
            for (final i in jl)
              Item.fromJson((i as Map).cast<String, dynamic>()),
          ]
        : builtin;

    for (final i in builtin) {
      if (!state.contains(i)) add(i);
    }
  }

  void save() {
    final js = state.map((i) => i.toJson()).toList();
    gbox.put('items2', js);
    // print('saved ${js[0]}');
  }
}

final itemsProvider = NotifierProvider<ItemListNotifier, List<Item>>(
  ItemListNotifier.new,
  name: 'itemsProvider',
);

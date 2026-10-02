import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../g.dart';

enum ItemType { assets, file, demo, net, debug }

class Item {
  const Item({
    required this.id,
    required this.type,
    required this.path,
    this.name,
    this.author,
    this.percent = 0,
  });

  final int id;
  final ItemType type;
  final String path;
  final String? name;
  final String? author;
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
    percent: (json['percent'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type.index,
    'path': path,
    'name': name,
    'author': author,
    'percent': percent,
  };

  Item copyWith({
    int? id,
    ItemType? type,
    String? path,
    String? name,
    String? author,
    double? percent,
  }) => Item(
    id: id ?? this.id,
    type: type ?? this.type,
    path: path ?? this.path,
    name: name ?? this.name,
    author: author ?? this.author,
    percent: percent ?? this.percent,
  );

  @override
  bool operator ==(Object other) => other is Item && id == other.id;
  @override
  int get hashCode => Object.hash(runtimeType, id, name, path);
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

  void update(int id, {String? author, String? name}) {
    state = [
      for (final e in state)
        if (e.id == id) e.copyWith(author: author, name: name) else e,
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

  Future load() async {
    final jl = gbox.get('items2');
    state = (jl is List && jl.isNotEmpty)
        ? [
            for (final i in jl)
              Item.fromJson((i as Map).cast<String, dynamic>()),
          ]
        : ShopNotifier.builtin;

    for (final i in ShopNotifier.builtin) {
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

class Shelf {
  Shelf({required this.id, required this.name, required this.items});
  final int id;
  final String name;
  final List<Item> items;

  static List<Item> loadItems(List<int> iids) {
    final items = <Item>[];
    for (int iid in iids) {
      final m = gbox.get('item:$iid');
      if (m != null) {
        items.add(Item.fromJson(m));
      }
    }
    return items;
  }

  factory Shelf.fromJson(Map<String, dynamic> json) => Shelf(
    id: json['id'] as int,
    name: json['name'] as String,
    items: loadItems(json['items'] as List<int>),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((e) => e.id).toList(),
  };
}

/// Short for Shelves, mean bookshop
class Shop {
  Shop({required this.shelves, this.current = 0});
  final List<Shelf> shelves;
  final int current;

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
    shelves: (json['shelves'] as List).map((m) => Shelf.fromJson(m)).toList(),
    current: (json['id'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'shelves': shelves.map((e) => e.toJson()).toList(),
    'current': current,
  };
}

class ShopNotifier extends Notifier<Shop> {
  @override
  Shop build() {
    final m = gbox.get('shop');
    if (m == null) {
      return Shop(
        shelves: [Shelf(id: nextId(), name: 'all', items: builtin)],
      );
    }
    final current = Shop.fromJson((m as Map).cast<String, dynamic>());
    final all = <Item>[];
    for (var s in current.shelves) {
      all.addAll(s.items);
    }
    for (final bi in builtin) {
      if (!all.contains(bi)) {
        current.shelves.first.items.add(bi);
      }
    }
    return current;
  }

  /// add means, put it at 1st place
  int add(String name) {
    state = Shop(
      shelves: [
        Shelf(id: nextId(), name: name, items: []),
        ...state.shelves,
      ],
      current: state.current,
    );
    return state.shelves.length;
  }

  void addItem(int shelfidx, Item target) {
    final ns = state.shelves[shelfidx];
    ns.items.insert(0, target);

    state = Shop(
      shelves: [
        for (int i = 0; i < state.shelves.length; i++)
          i == shelfidx ? ns : state.shelves[i],
      ],
      current: state.current,
    );
  }

  void updateItem(int shelfidx, Item target) {
    final ns = state.shelves[shelfidx];
    final ii = ns.items.indexWhere((item) => item.id == target.id);
    if (ii != -1) ns.items[ii] = target;

    state = Shop(
      shelves: [
        for (int i = 0; i < state.shelves.length; i++)
          i == shelfidx ? ns : state.shelves[i],
      ],
      current: state.current,
    );
  }

  static final builtin = [
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

    const Item(id: 5, name: 'Freya Cycle', path: '', type: ItemType.demo),
    if (!bool.fromEnvironment('dart.vm.product'))
      const Item(
        id: 6,
        name: 'Debug, 中文',
        path: '事實上，我想"我"並不記得“這個”月之前噴泉是什麼樣子',
        type: ItemType.debug,
      ),
  ];

  void save() {
    final js = state.toJson();
    gbox.put('shop', js);
  }
}

final shopProvider = NotifierProvider<ShopNotifier, Shop>(
  ShopNotifier.new,
  name: 'shopProvider',
);

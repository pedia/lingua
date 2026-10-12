import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinyin_pro_flutter/pinyin_pro_flutter.dart';

import '../g.dart';

enum ItemType { assets, file, demo, net, debug }

class Item {
  const Item({
    required this.id,
    required this.type,
    required this.path,
    this.name,
    this.author,
    this.description,
    this.percent = 0,
  });

  final int id;
  final ItemType type;
  final String path;
  final String? name;
  final String? author;
  final String? description;
  final double percent;

  String get subtitle => [
    if (author != null) author,
    if (percent > 0) '${(percent * 100).toInt()}%',
  ].join(' ');

  factory Item.fromBox(int id) =>
      Item.fromJson(gbox.get('item:$id').cast<String, dynamic>());

  factory Item.fromJson(Map<String, dynamic> json) => Item(
    id: json['id'],
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
    description: json['description'] as String?,
    percent: (json['percent'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type.index,
    'path': path,
    'name': name,
    'author': author,
    'description': description,
    'percent': percent,
  };

  Item copyWith({
    int? id,
    ItemType? type,
    String? path,
    String? name,
    String? author,
    String? description,
    double? percent,
  }) => Item(
    id: id ?? this.id,
    type: type ?? this.type,
    path: path ?? this.path,
    name: name ?? this.name,
    author: author ?? this.author,
    description: description ?? this.description,
    percent: percent ?? this.percent,
  );

  @override
  bool operator ==(Object other) => other is Item && id == other.id;
  @override
  int get hashCode => Object.hash(runtimeType, id, name, path);

  bool match(String q) {
    q = q.toLowerCase();
    if (author != null) {
      if (author!.toLowerCase().contains(q)) {
        return true;
      }
      final m = matchPinyin(author!, q);
      if (m != null && m.isNotEmpty) {
        return true;
      }
    }

    if (name != null) {
      if (name!.toLowerCase().contains(q)) {
        return true;
      }
      final m = matchPinyin(name!, q);
      if (m != null && m.isNotEmpty) {
        return true;
      }
    }

    if (description != null) {
      if (description!.toLowerCase().contains(q)) {
        return true;
      }
    }
    return false;
  }
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
  name: 'Items',
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
        items.add(Item.fromJson((m as Map).cast<String, dynamic>()));
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

  Shelf copyWith({List<Item>? items, int? id, String? name}) => Shelf(
    id: id ?? this.id,
    name: name ?? this.name,
    items: items ?? this.items,
  );

  List<Item> search(String q) {
    final rs = <Item>[];
    for (final i in items) {
      if (i.match(q)) rs.add(i);
    }
    return rs;
  }
}

/// Short for Shelves, mean bookshop
class Shop {
  Shop({required this.shelves, this.current = 0});
  final List<Shelf> shelves;
  final int current;

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
    shelves: ((json['shelves'] as List).cast<Map>())
        .map((m) => Shelf.fromJson(m.cast<String, dynamic>()))
        .toList(),
    current: (json['id'] as int?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'shelves': shelves.map((e) => e.toJson()).toList(),
    'current': current,
  };

  List<Item> search(String q) {
    return [for (final s in shelves) ...s.search(q)];
  }
}

class ShopNotifier extends Notifier<Shop> {
  @override
  Shop build() {
    final m = gbox.get('shop');
    if (m == null) {
      return init();
    }
    try {
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
    } catch (e, stackTrace) {
      print('load shop failed $e\n$stackTrace');
      return init();
    }
  }

  void update({List<Shelf>? shelves, int? current}) {
    state = Shop(
      shelves: shelves ?? state.shelves,
      current: current ?? state.current,
    );
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
    save(state);
    return state.shelves.length;
  }

  void addItemTo(int shelfidx, Item target) {
    saveItem(target);
    final ns = state.shelves[shelfidx];
    ns.items.insert(0, target);

    state = Shop(
      shelves: [
        for (int i = 0; i < state.shelves.length; i++)
          i == shelfidx ? ns : state.shelves[i],
      ],
      current: state.current,
    );
    save(state);
  }

  void removeItemFrom(int shelfidx, Item target) {
    final ns = state.shelves[shelfidx];
    ns.items.insert(0, target);

    state = Shop(
      shelves: [
        for (int i = 0; i < state.shelves.length; i++)
          i == shelfidx ? ns : state.shelves[i],
      ],
      current: state.current,
    );
    save(state);
  }

  void touch(int shelfidx, int itemId) {
    print('touch $shelfidx/$itemId');
    final old = state.shelves[shelfidx];
    final ns = old.copyWith(
      items: <Item>[
        ...old.items.where((i) => i.id == itemId),
        ...old.items.where((i) => i.id != itemId),
      ],
    );
    state = Shop(
      shelves: [
        for (int i = 0; i < state.shelves.length; i++)
          i == shelfidx ? ns : state.shelves[i],
      ],
      current: state.current,
    );
    save(state);
  }

  void save(Shop shop) {
    gbox.put('shop', shop.toJson());
  }

  void saveItem(Item target) {
    gbox.put('item:${target.id}', target.toJson());
  }

  Shop init() {
    for (final bi in builtin) {
      gbox.put('item:${bi.id}', bi.toJson());
    }
    return Shop(
      shelves: [Shelf(id: nextId(), name: 'all', items: builtin)],
    );
  }

  static final builtin = [
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
}

final shopProvider = NotifierProvider<ShopNotifier, Shop>(
  ShopNotifier.new,
  name: 'Shop',
);

class CurrentItemId extends Notifier<int?> {
  @override
  int? build() => 1; // Initial value

  void update(int id) {
    state = id;
  }
}

final ciip = NotifierProvider<CurrentItemId, int?>(
  CurrentItemId.new,
  name: 'CurrentItemId:ciip',
);

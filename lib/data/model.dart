import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lingua/imap.dart';
import 'package:pinyin_pro_flutter/pinyin_pro_flutter.dart';

import '../g.dart';

enum ItemType { assets, file, demo, net, debug }

class Item {
  const Item({
    required this.id,
    required this.type,
    required this.path,
    required this.ctime,
    this.name,
    this.author,
    this.description,
    this.review,
    this.percent = 0,
  });

  final int id;
  final DateTime ctime;
  final ItemType type;
  final String path;
  final String? name;
  final String? author;
  final String? description;
  final String? review;
  final double percent;

  String get subtitle => [
    if (author != null) author,
    if (percent > 0) '${(percent * 100).toInt()}%',
    if (review != null) review,
  ].join(' ');

  factory Item.stub(int id) =>
      Item(id: id, type: ItemType.debug, path: '', ctime: DateTime(2026));

  factory Item.fromBox(int id) => box.get('item2:$id') as Item;

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
    ctime: json['ctime'] != null
        ? ((json['ctime'] is DateTime)
              ? (json['ctime'] as DateTime)
              : DateTime.parse(json['ctime']))
        : DateTime(2026), // fix, old items
    name: json['name'] as String?,
    author: json['author'] as String?,
    description: json['description'] as String?,
    review: json['review'] as String?,
    percent: (json['percent'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type.index,
    'ctime': ctime.toString(),
    'path': path,
    'name': name,
    'author': author,
    'description': description,
    'review': review,
    'percent': percent,
  };

  Item copyWith({
    int? id,
    DateTime? ctime,
    ItemType? type,
    String? path,
    String? name,
    String? author,
    String? description,
    String? review,
    double? percent,
  }) => Item(
    id: id ?? this.id,
    ctime: ctime ?? this.ctime,
    type: type ?? this.type,
    path: path ?? this.path,
    name: name ?? this.name,
    author: author ?? this.author,
    description: description ?? this.description,
    review: review ?? this.review,
    percent: percent ?? this.percent,
  );

  @override
  String toString() => 'Item($id, $name, $author)';

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
    if (review != null) {
      if (review!.toLowerCase().contains(q)) {
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
    final jl = box.get('items2');
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
    box.put('items2', js);
    // print('saved ${js[0]}');
  }
}

final itemsProvider = NotifierProvider<ItemListNotifier, List<Item>>(
  ItemListNotifier.new,
  name: 'Items',
);

class Shelf {
  Shelf({required this.id, required this.name, required this.iids});
  final int id;
  final String name;
  final List<int> iids;
  List<Item> get items =>
      iids.map((i) => box.get('item2:$i') as Item).toList();

  static List<Item> loadItems(List<int> iids) =>
      iids.map((i) => box.get('item2:$i') as Item).toList();

  Item item(int i) {
    final o = box.get('item2:${iids[i]}');
    return o == null ? Item.stub(iids[i]) : o as Item;
  }

  factory Shelf.fromJson(Map<String, dynamic> json) => Shelf(
    id: json['id'] as int,
    name: json['name'] as String,
    iids: json['iids'] as List<int>,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'items': iids};

  Shelf copyWith({List<int>? iids, int? id, String? name}) => Shelf(
    id: id ?? this.id,
    name: name ?? this.name,
    iids: iids ?? this.iids,
  );

  List<Item> search(String q) {
    final rs = <Item>[];
    for (final id in iids) {
      final item = box.get('item2:$id');
      if (item != null && item.match(q)) rs.add(item);
    }
    return rs;
  }

  List<Item> findByPath(String path) {
    final rs = <Item>[];
    for (final i in iids) {
      final item = box.get('item2:$i');
      if (item.path == path) rs.add(item);
    }
    return rs;
  }

  Shelf touch(int itemId) {
    if (iids.remove(itemId)) {
      iids.insert(0, itemId);
    }
    return this;
  }

  Shelf remove(int itemId) {
    iids.remove(itemId);
    return this;
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

  int find(String path) {
    for (int i = 0; i < shelves.length; ++i) {
      final found = shelves[i].findByPath(path);
      if (found.isNotEmpty) {
        return i;
      }
    }
    return -1;
  }

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
    final m = box.get('2shop');
    if (m == null) {
      return init();
    }
    try {
      return m is Map ? Shop.fromJson(m.cast<String, dynamic>()) : m as Shop;
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
    save(state);
  }

  /// add means, put it at 1st place
  int add(String name) {
    state = Shop(
      shelves: [
        Shelf(id: nextId(), name: name, iids: []),
        ...state.shelves,
      ],
      current: state.current,
    );
    save(state);
    return state.shelves.length;
  }

  void addItemTo(int shelfidx, Item target) {
    if (state.find(target.path) != -1) {
      return;
    }

    saveItem(target);
    final ns = state.shelves[shelfidx];
    ns.iids.insert(0, target.id);

    state = Shop(
      shelves: [
        for (int i = 0; i < state.shelves.length; i++)
          i == shelfidx ? ns : state.shelves[i],
      ],
      current: state.current,
    );
    save(state);
  }

  void moveItemTo(int itemId, int shelfidx) {
    final ns = state.shelves[shelfidx];
    // avoid duplicated
    if (!ns.iids.contains(itemId)) {
      ns.iids.insert(0, itemId);
    }

    state = Shop(
      shelves: [
        for (int i = 0; i < state.shelves.length; i++)
          i == shelfidx ? state.shelves[i] : state.shelves[i].remove(itemId),
      ],
      current: state.current,
    );
    save(state);
  }

  /// find item, move it to top
  void touch(int itemId) {
    state = Shop(
      shelves: [
        for (int i = 0; i < state.shelves.length; i++)
          state.shelves[i].touch(itemId),
      ],
      current: state.current,
    );
    save(state);
  }

  void remove(int itemId) {
    state = Shop(
      shelves: [
        for (int i = 0; i < state.shelves.length; i++)
          state.shelves[i].remove(itemId),
      ],
      current: state.current,
    );
    save(state);
  }

  void save(Shop shop) {
    box.put('2shop', shop);
  }

  void saveItem(Item target) {
    box.put('item2:${target.id}', target);
  }

  Shop init() {
    for (final bi in builtin) {
      box.put('item2:${bi.id}', bi);
    }
    return Shop(
      shelves: [
        Shelf(
          id: nextId(),
          name: 'all',
          iids: builtin.map((item) => item.id).toList(),
        ),
      ],
    );
  }

  static final builtin = [
    Item(
      id: 2,
      ctime: DateTime.now(),
      name: 'Super Supportive',
      path: 'assets/super-supportive-dual.epub',
      type: ItemType.assets,
    ),
    Item(
      id: 3,
      ctime: DateTime.now(),
      name: 'Paranoid Mage',
      path: 'assets/paranoid-mage-dual.epub',
      type: ItemType.assets,
    ),
    Item(
      id: 4,
      ctime: DateTime.now(),
      name: 'Mother of Learning',
      path: 'assets/mother-of-learning-dual.epub',
      type: ItemType.assets,
    ),

    Item(
      id: 5,
      ctime: DateTime.now(),
      name: 'Freya Cycle',
      path: '',
      type: ItemType.demo,
    ),

    if (!bool.fromEnvironment('dart.vm.product'))
      Item(
        id: 6,
        ctime: DateTime.now(),
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

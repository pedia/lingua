import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:lingua/data/model.dart';
import 'package:lingua/g.dart';
import '../lib/hive/hive_registrar.g.dart';

void main() {
  Hive.registerAdapters();
  test('box2', () async {
    final box = await Hive.openBox('foo', path: '.');

    final lo = await box.get('list');
    if (lo != null) {
      expect(lo, equals([1, 2, 3]));
    }

    final la = [1, 2, 3];
    await box.put('list', la);

    final lb = box.get('list');
    lb[0] = 4;

    expect(la, equals([4, 2, 3]));
    expect(lb, equals([4, 2, 3]));
    expect(lo, equals([1, 2, 3]));
    // expect(box.length, equals(1));

    box.put(1, 42);
    box.put(2, {
      'a': 'b',
      'c': [1],
    });
    expect(box.get(2), isMap);
    // expect(box.length, equals(2));
    // box.add('hello');
    // for (var i = 0; i < box.length; i++) {
    //   print('$i: ${box.getAt(i)}');
    // }

    print(box.toMap());
  });
  test('model', () async {
    gid = 0;
    box = await Hive.openBox('app', path: '.');

    final a = Item(
      id: 100,
      ctime: DateTime(2027),
      name: 'The Little Prince',
      path: 'assets/the-little-prince-dual.epub',
      type: ItemType.assets,
    );
    box.put('item:100', a);

    final shop = ShopNotifier().init();
    box.put('shop', shop);

    final x = box.get('shop');
    expect(x, isNotNull);

    print(box.toMap());
  });
}

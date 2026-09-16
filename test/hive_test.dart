import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:lingua/data/model.dart';
import 'package:lingua/g.dart';

void main() {
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
    gbox = await Hive.openBox('app', path: '.');

    final a = Item(
      name: 'The Little Prince',
      path: 'assets/the-little-prince-dual.epub',
      type: ItemType.assets,
    )..toJson();

    final al = ItemList(items: [a]);

    final jl = al.toJson();
    final bl = ItemList.fromJson(jl);
    expect(al, bl);

    gbox.put('items', al.toJson());

    final cl = ItemList.fromJson(gbox.get('items'));
    expect(al, cl);
  });
}

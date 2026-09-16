import 'package:flutter_test/flutter_test.dart';
import 'package:lingua/settings/setting.dart';

void main() {
  test('settings all', () {
    final jd = {
      "tts": {
        "zh": {"pitch": 0.3, "rate": 0.4, "language": "en-US", "system": true},
      },
      "i": 13,
      "s": "foo",
      "b": false,
      "t": true,
      "seq": [13, 24],
    };

    final m = TypedMap(jd);
    expect(m.has("b"), isTrue);
    expect(m.has("a"), isFalse);
    expect(m.has("a.b"), isFalse);
    expect(m.has("b.c"), isFalse);
    expect(m.has("tts.zh.foo"), isFalse);
    expect(m.has("tts.zh.pitch"), isTrue);

    expect(m.flag("b"), isFalse);
    expect(m.flag("t"), isTrue);
    expect(m.stringOf("s"), "foo");
    expect(m.intOf("i"), 13);
    expect(m.flag("tts.zh.system"), isTrue);
    expect(m.doubleOf("tts.zh.rate"), equals(0.4));
    expect(m.listOf("seq"), equals([13, 24]));

    expect(() => m.stringOf("b"), throwsA(const TypeMatcher<TypeError>()));
    expect(m.flag("a"), isFalse);
    expect(m.flag("a.c"), isFalse);
    expect(m.objectOf("tts.zh"), TypeMatcher<Map>());

    // of not throw
    expect(m.of("none"), isNull);
    expect(m.of("none.none"), isNull);

    m.put("a.b.c", "cc");
    expect(m.stringOf("a.b.c"), "cc");
    m.put("a.c", "cc");
    expect(m.stringOf("a.b.c"), "cc"); //
    expect(m.stringOf("a.c"), "cc");
    m.put("a.c", 1);
    expect(m.stringOf("a.b.c"), "cc");
    expect(m.intOf("a.c"), 1);
    expect(m.stringOf("a.b.c"), "cc");
    expect(m.of("a"), isMap);
    expect(m.of("a"), {
      'b': {'c': 'cc'},
      'c': 1,
    });

    // i already exists
    m.put("i.b", "1");

    final o2 = m.copyWith('aa', 'newer');
    expect(o2 != m, isTrue);
  });
}

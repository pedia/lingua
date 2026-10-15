import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../g.dart';

class TypedMap {
  TypedMap(this.map);
  final Map<String, dynamic> map;

  // TODO: return bool? is better
  bool flag(String key) => (of(key) ?? false) as bool;
  int intOf(String key, {int? defaults}) => of(key) ?? defaults;
  double doubleOf(String key, {double? defaults}) =>
      (of(key) ?? defaults).toDouble();
  String stringOf(String key) => (of(key) ?? '') as String;
  Map objectOf(String key) => of(key) as Map;
  List listOf(String key) => of(key) as List;
  dynamic withType(String key, String type) {}

  TypedMap copyWith(String key, dynamic val) {
    final nm = TypedMap(Map.of(map));
    nm.put(key, val);
    return nm;
  }

  void put(String key, dynamic val) {
    var m = map;
    final arr = key.split(".");
    if (arr.isNotEmpty) {
      for (var i in arr.sublist(0, arr.length - 1)) {
        if (!m.containsKey(i)) {
          m[i] = <String, dynamic>{};
        }
        if (m[i] is! Map) {
          m[i] = <String, dynamic>{};
        }
        m = m[i].cast<String, dynamic>();
      }
      m[arr.last] = val;
    } else {
      map[key] = val;
    }
  }

  bool has(String key) {
    var m = map;
    final arr = key.split(".");
    if (arr.isNotEmpty) {
      for (var i in arr.sublist(0, arr.length - 1)) {
        if (!m.containsKey(i)) {
          return false;
        }

        try {
          m = m[i].cast<String, dynamic>();
        } catch (e) {
          debugPrint('TypedMap has $key failed $e');
          return false;
        }
      }
      return m.containsKey(arr.last);
    } else {
      return map.containsKey(key);
    }
  }

  dynamic of(String key) {
    var m = map;
    final arr = key.split(".");
    if (arr.isNotEmpty) {
      for (var i in arr.sublist(0, arr.length - 1)) {
        if (!m.containsKey(i)) {
          return null;
        }
        m = m[i].cast<String, dynamic>();
      }
      if (!m.containsKey(arr.last)) {
        return null;
      }
      return m[arr.last];
    } else {
      if (!m.containsKey(key)) {
        return null;
      }
      return map[key];
    }
  }

  @override
  String toString() {
    return JsonEncoder.withIndent('  ').convert(map);
  }
}

class Setting extends Notifier<TypedMap> {
  @override
  TypedMap build() => load();

  void put(String key, dynamic val) {
    // Important: create a new instance or notify so Riverpod sees the change
    state = state.copyWith(key, val);
    debugPrint('>>> Setting.put >>>');

    save(key);
  }

  void save(String key) {
    gbox
        .put('settings', state.map)
        .then((_) => debugPrint('saved by $key ${state.map}'));
  }

  TypedMap load() {
    final m = gbox.get('settings');

    debugPrint('setting load: $m');

    return m is Map && m.isNotEmpty
        ? TypedMap(m.cast<String, dynamic>())
        : TypedMap({
            // defaults
            'tts': {
              'mode': 'zh',
              'en': {
                'rate': 0.44,
                'pitch': 1.0,
                'language': 'en-US',
                'voice': {'locale': 'en-US', 'name': 'Samantha'},
              },
              'zh': {
                'rate': 0.62,
                'pitch': 1.0,
                'language': 'zh-TW',
                'voice': {'locale': 'zh-TW', 'name': 'Meijia'},
              },
            },
            'ui': {
              'mode': '',
              'en': {'font-size': 14},
              'zh': {'font-size': 18},
              'theme-mode': 0,
            },
          });
  }
}

final settingProvider = NotifierProvider<Setting, TypedMap>(
  Setting.new,
  name: 'Setting',
);

enum SettingType {
  bool, // switch
  choice,
  group,
  readonly,
  slider,
  builder,
}

class SettingItem {
  const SettingItem({
    required this.type,
    this.key,
    required this.title,
    this.defaults,
    this.description,
    this.choices,
    this.range = const Range(0, 1.0),
    this.builder,
    this.tailBuilder,
    this.children = const [],
  });
  final String? key;
  final dynamic defaults;
  final SettingType type;
  final String title;
  final String? description;
  // title, value
  final List<(String, Object)>? choices;
  final Range range;
  final ConsumerBuilder? builder;
  final ConsumerBuilder? tailBuilder;
  final List<SettingItem> children;
}

class Range<T extends num> {
  final T min;
  final T max;

  const Range(this.min, this.max);
}

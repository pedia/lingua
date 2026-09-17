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
  double doubleOf(String key) => (of(key) ?? 0.0) as double;
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
          debugPrint('$e');
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
  TypedMap build() {
    // TODO: load from storage
    Future.microtask(() => load());
    return TypedMap({});
  }

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

  Future load() async {
    final m = gbox.get('settings');

    debugPrint('load $m');

    state = m is Map && m.isNotEmpty
        ? TypedMap(m.cast<String, dynamic>())
        : TypedMap({
            // defaults
            'tts': {
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
            'ui': {'lang': '', 'theme-mode': 0},
          });
  }
}

/// ref.watch(settingsProvider.notifier) /// get Setting
/// ref.watch(settingsProvider)          /// watches the whole map

/// Only rebuilds when 'ui.thememode' changes
/// final themeMode = ref.watch(
///   settingsProvider.select((s) => s.getInt('ui.thememode')),
/// );

/// /// or better – typed selectors
/// final themeModeProvider = Provider<ThemeMode>((ref) {
///   return ref.watch(settingsProvider.select((s) => s.themeMode));
/// });
final settingProvider = NotifierProvider<Setting, TypedMap>(Setting.new);

enum SettingType {
  slider,
  bool, // switch
  title, // group title, stub
  readonly,
  choice,
  builder,
}

class SettingItem {
  SettingItem({
    required this.type,
    required this.key,
    required this.title,
    this.defaults,
    this.description,
    this.choices,
    this.range,
    this.gentitle,
    this.builder,
  });
  final String key;
  final dynamic defaults;
  final SettingType type;
  final String title;
  final String? description;
  // title, value
  final List<(String, Object)>? choices;
  final Range? range;
  final String Function(Object)? gentitle; // generate title
  final Widget Function(BuildContext context, WidgetRef ref)? builder;
}

class Range<T extends num> {
  final T min;
  final T max;

  Range(this.min, this.max);
}

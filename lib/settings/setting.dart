import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class TypedMap {
  TypedMap(this.map);
  final Map<String, dynamic> map;

  // TODO: return bool? is better
  bool flag(String key) => (of(key) ?? false) as bool;
  int intOf(String key) => (of(key) ?? 0) as int;
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

        m = m[i];
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
          m = m[i];
        } catch (_) {
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
        m = m[i];
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

  Future save(String key) async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, 'setting.json'));
    await file.writeAsString(jsonEncode(state.map));

    debugPrint('saved by $key');
  }

  Future load() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File(p.join(docs.path, 'setting.json'));
      final m = jsonDecode(file.readAsStringSync());
      state = TypedMap(m);
      debugPrint('loaded');
    } catch (e) {
      debugPrint('load failed $e');
      state = TypedMap({
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
        'ui': {'theme': 'system', 'lang': ''},
      });
    }
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
  onoff, // switch
  title, // group title
  text,
  custom,
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
  final Function? choices;
  final Range? range;
  final String Function(Object)? gentitle; // generate title
  final Widget Function(BuildContext context, WidgetRef ref)? builder;
}

class Range<T extends num> {
  final T min;
  final T max;

  Range(this.min, this.max);
}

/// Widget for setting item
class Tile extends ConsumerWidget {
  const Tile(this.item, {super.key});
  final SettingItem item;

  Widget choose(BuildContext context, WidgetRef ref) {
    final v = ref.watch(settingProvider.select((m) => m.of(item.key)));
    return PopupMenuButton<Object>(
      tooltip: item.title,
      initialValue: v,
      onSelected: (Object value) {
        ref.read(settingProvider.notifier).put(item.key, value);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Change ${item.title}: $value')));
      },
      itemBuilder: (BuildContext context) => item.choices!(),
      child: TextButton(
        onPressed: null, // disabled because PopupMenuButton handles the tap
        child: Text(item.gentitle != null ? item.gentitle!(v) : ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('Tile ${item.key}');
    final v = ref.watch(settingProvider.select((m) => m.of(item.key)));
    final tile = switch (item.type) {
      SettingType.custom => item.builder!(context, ref),
      SettingType.onoff => SwitchListTile(
        title: Text(item.title),
        subtitle: Text(item.description ?? ''),
        value: v ?? item.defaults,
        onChanged: (v) {
          ref.read(settingProvider.notifier).put(item.key, v);
        },
      ),
      SettingType.slider => ListTile(
        title: Text(item.title),
        trailing: Text(
          '${v ?? item.defaults}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        subtitle: Text(item.description ?? ''),
      ),
      SettingType.text => ListTile(
        title: Text(item.title),
        trailing: item.choices == null
            ? Text(
                v ?? item.defaults ?? '',
                style: Theme.of(context).textTheme.bodyLarge,
              )
            : choose(context, ref),
        subtitle: Text(item.description ?? ''),
      ),

      SettingType.title => Padding(
        padding: EdgeInsets.only(left: 8, top: 20),
        child: Text(item.title),
      ),
    };

    if (item.type == SettingType.slider) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          tile,
          Slider(
            value:
                (v as num?)?.toDouble() ??
                (item.defaults != null ? (item.defaults as num).toDouble() : 0),
            min: item.range?.min as double? ?? 0.0,
            max: item.range?.max as double? ?? 1.0,
            onChanged: (v) {
              ref.read(settingProvider.notifier).put(item.key, v);
            },
          ),
        ],
      );
    } else {
      return tile;
    }
  }
}

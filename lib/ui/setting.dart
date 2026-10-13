import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings/setting.dart';

class SettingFrame extends ConsumerStatefulWidget {
  const SettingFrame({super.key});

  @override
  ConsumerState<SettingFrame> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingFrame> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  final items = <SettingItem>[
    SettingItem(
      type: SettingType.choice,
      key: 'ui.theme-mode',
      title: 'Theme',
      choices: [
        ('System', ThemeMode.system.index),
        ('Light', ThemeMode.light.index),
        ('Dark', ThemeMode.dark.index),
      ],
    ),
    SettingItem(type: SettingType.title, title: 'Read', key: ''),
    SettingItem(
      type: SettingType.choice,
      key: 'ui.mode',
      title: 'Mode',
      defaults: '',
      description: 'List en|zh|all in read view',
      choices: [('Only English', 'en'), ('Only Chinese', 'zh'), ('All', '')],
    ),
    SettingItem(
      type: SettingType.choice,
      key: 'ui.en.font-size',
      title: 'English font size',
      defaults: 14,
      choices: [
        ('12', 12),
        ('14', 14),
        ('16', 16),
        ('18', 18),
        ('20', 20),
        ('24', 24),
      ],
    ),
    SettingItem(
      type: SettingType.choice,
      key: 'ui.zh.font-size',
      title: 'Chinese font size',
      defaults: 18,
      choices: [
        ('12', 12),
        ('14', 14),
        ('16', 16),
        ('18', 18),
        ('20', 20),
        ('24', 24),
      ],
    ),
    SettingItem(type: SettingType.title, title: 'TTS Speak', key: ''),
    SettingItem(
      type: SettingType.choice,
      key: 'tts.mode',
      title: 'Mode',
      defaults: '',
      choices: [('Only English', 'en'), ('Only Chinese', 'zh'), ('All', '')],
    ),
    SettingItem(
      type: SettingType.readonly,
      key: 'ui.foo',
      title: 'Readonly None',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(settingProvider);
    debugPrint('all setting: $m');
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Setting')),
      child: SafeArea(
        child: Material(
          child: ListView(children: items.map((e) => Tile(e)).toList()),
        ),
      ),
    );
  }
}

/// Widget for setting item
class Tile extends ConsumerWidget {
  const Tile(this.item, {super.key});
  final SettingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('Tile.build for ${item.key}');
    final v = ref.watch(settingProvider.select((m) => m.of(item.key)));
    final tile = switch (item.type) {
      SettingType.builder => item.builder!(context, ref),
      SettingType.bool => SwitchListTile(
        title: Text(item.title),
        subtitle: item.description == null ? null : Text(item.description!),
        value: v ?? item.defaults,
        onChanged: (v) {
          ref.read(settingProvider.notifier).put(item.key, v);
        },
      ),
      SettingType.choice => ListTile(
        title: Text(item.title),
        subtitle: item.description == null ? null : Text(item.description!),
        trailing: DropdownButton<Object>(
          key: Key(item.key),
          value: v ?? item.defaults,
          underline: null,
          onChanged: (v) {
            debugPrint('v: ${v.runtimeType}');
            ref.read(settingProvider.notifier).put(item.key, v);
          },
          items: item.choices!
              .map(
                (e) => DropdownMenuItem<Object>(value: e.$2, child: Text(e.$1)),
              )
              .toList(),
        ),
      ),
      SettingType.slider => ListTile(
        title: Text(item.title),
        trailing: Text(
          '${v ?? item.defaults}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        subtitle: item.description == null ? null : Text(item.description!),
      ),
      SettingType.readonly => ListTile(
        title: Text(item.title),
        trailing: Text('$v', style: Theme.of(context).textTheme.bodyLarge),
        subtitle: item.description == null ? null : Text(item.description!),
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

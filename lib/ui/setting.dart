import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:go_router/go_router.dart';
import '../settings/setting.dart';
import 'shelf.dart';

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
      type: SettingType.group,
      title: '',
      children: [
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
        SettingItem(
          type: SettingType.bool,
          key: 'detect',
          defaults: false,
          title: 'Proactive Language Detection',
        ),
      ],
    ),
    SettingItem(
      type: SettingType.group,
      title: 'Read',
      children: [
        SettingItem(
          type: SettingType.choice,
          key: 'ui.mode',
          title: 'Mode',
          defaults: '',
          description: 'List en|zh|all in read view',
          choices: [
            ('Only English', 'en'),
            ('Only Chinese', 'zh'),
            ('All', ''),
          ],
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
      ],
    ),
    SettingItem(
      type: SettingType.group,
      title: 'TTS',
      children: [
        SettingItem(
          type: SettingType.choice,
          key: 'tts.mode',
          title: 'Mode',
          defaults: '',
          choices: [
            ('Only English', 'en'),
            ('Only Chinese', 'zh'),
            ('All', ''),
          ],
        ),
        SettingItem(
          type: SettingType.readonly,
          key: 'ui.foo',
          title: 'Readonly None',
        ),
      ],
    ),

    SettingItem(
      type: SettingType.group,
      title: 'Info',
      children: [
        SettingItem(
          type: SettingType.builder,
          title: 'KV Storage',
          tailBuilder: (_, _, _) {
            return FutureBuilder<int>(
              future: boxSize(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text('...');
                } else if (snapshot.hasError) {
                  return const Text('error');
                }
                return Text(
                  snapshot.data?.kb ?? 'fail',
                  style: Theme.of(context).textTheme.bodyLarge,
                );
              },
            );
          },
        ),
        SettingItem(
          type: SettingType.builder,
          title: 'File Storage',
          tailBuilder: (_, _, _) {
            return FutureBuilder<int>(
              future: docsSize(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text('...');
                } else if (snapshot.hasError) {
                  return const Text('error');
                }
                return Text(
                  snapshot.data?.mb ?? 'fail',
                  style: Theme.of(context).textTheme.bodyLarge,
                );
              },
            );
          },
        ),
      ],
    ),
    SettingItem(
      type: SettingType.builder,
      title: 'Scan app documents folder',
      tailBuilder: (context, ref, child) {
        return GestureDetector(
          onTap: () async {
            final c = await scan(ref);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$c book added')));
          },
          child: Text('Start'),
        );
      },
    ),

    SettingItem(
      type: SettingType.builder,
      title: 'Debug',
      builder: (context, ref, child) => Wrap(
        spacing: 8.0, // Horizontal gap between buttons
        runSpacing: 8.0, // Vertical gap between lines
        children:
            [
              '/',
              '/note',
              '/shelf-mgmt',
              '/book/4',
              '/read/4',
              '/hive',
              '/setting',
              '/engine',
              '/library',
              '/provider',
              '/demo',
              '/font',
              '/sliver',
              '/sliver2',
              '/search',
              '/master-detail',
            ].map((action) {
              return CupertinoButton(
                onPressed: () => context.push(action),
                child: Text(action),
              );
            }).toList(),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(settingProvider);
    debugPrint('all setting: $m');
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: Material(
        child: ListView(children: [...items.map((e) => Tile(e))]),
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
    dynamic v;
    if (item.key != null) {
      v = ref.watch(settingProvider.select((m) => m.of(item.key!)));
    }
    final tile = switch (item.type) {
      SettingType.builder =>
        item.builder != null
            ? Card(child: item.builder!(context, ref, null))
            : ListTile(
                title: Text(item.title),
                trailing: item.tailBuilder!(context, ref, null),
              ),
      SettingType.bool => SwitchListTile(
        title: Text(item.title),
        subtitle: item.description == null ? null : Text(item.description!),
        value: v ?? item.defaults,
        onChanged: (v) {
          ref.read(settingProvider.notifier).put(item.key!, v);
        },
      ),
      SettingType.choice => ListTile(
        title: Text(item.title),
        subtitle: item.description == null ? null : Text(item.description!),
        trailing: DropdownButton<Object>(
          key: item.key == null ? null : Key(item.key!),
          value: v ?? item.defaults,
          underline: null,
          onChanged: (v) {
            debugPrint('v: ${v.runtimeType}');
            ref.read(settingProvider.notifier).put(item.key!, v);
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

      SettingType.group => Card(
        margin: EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(' ${item.title}'),
            ...item.children.map((i) => Tile(i)),
          ],
        ),
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
            min: item.range.min as double,
            max: item.range.max as double,
            onChanged: (v) {
              ref.read(settingProvider.notifier).put(item.key!, v);
            },
          ),
        ],
      );
    } else {
      return SafeArea(child: tile);
    }
  }
}

Future<int> boxSize() async {
  final docs = await getApplicationDocumentsDirectory();
  final fp = p.join(docs.path, 'all.hive');
  return File(fp).length();
}

extension _Byte on int {
  String get kb => '${(this / 1024).toStringAsFixed(1)}KB';
  String get mb => '${(this / 1024 / 1024).toStringAsFixed(2)}MB';
}

Future<int> docsSize() async {
  return directorySize(await getApplicationDocumentsDirectory());
}

Future<int> directorySize(Directory directory) async {
  if (await directory.exists()) {
    int totalSize = 0;

    // List all files and directories recursively
    await for (var entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }
  return 0;
}

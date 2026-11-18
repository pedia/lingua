import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:go_router/go_router.dart';
import '../app.dart';
import '../settings/setting.dart';
import '../tts/voice.dart';
import '../chunk/chunk.dart';
import 'open.dart';

class SettingFrame extends ConsumerStatefulWidget {
  const SettingFrame({super.key});

  @override
  ConsumerState<SettingFrame> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingFrame> {
  @override
  void initState() {
    loadVoices();
    super.initState();
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  final tts = FlutterTts();
  final envs = <(String, Voice)>[];
  final zhvs = <(String, Voice)>[];

  void loadVoices() {
    tts.getVoices.then((x) {
      final list = (x as List)
          .cast<Map>()
          .map((e) => Voice(Map<String, String>.from(e)))
          .where((e) => e.valid)
          .toList();

      for (final v in list) {
        if (v.match(Lang.en)) {
          envs.add((v.title, v));
        } else if (v.match(Lang.zh)) {
          zhvs.add((v.title, v));
        }
      }

      {
        final m = ref.read(settingProvider.select((s) => s.of('tts.en.voice')));
        final v = Voice((m as Map).cast<String, String>());
        for (final i in envs) {
          debugPrint('${i.$1}, == ${v == i.$2} ${v == i.$2 ? i.$2 : ''}');
        }
        if (envs.where((i) => i.$2 == v).length != 1) {
          debugPrint('Set tts.en.voice to null');
          ref.read(settingProvider.notifier).put('tts.en.voice', null);
        }
      }
      {
        final m = ref.read(settingProvider.select((s) => s.of('tts.zh.voice')));
        if (m != null) {
          final v = Voice((m as Map).cast<String, String>());
          for (final i in zhvs) {
            debugPrint('${i.$1}, == ${v == i.$2} ${v == i.$2 ? i.$2 : ''}');
          }
          if (zhvs.where((i) => i.$2 == v).length != 1) {
            debugPrint('Set tts.zh.voice to null');
            ref.read(settingProvider.notifier).put('tts.zh.voice', null);
          }
        }
      }

      // for zhvs/envs
      setState(() {});
    });
  }

  void _playSample(Lang lang, WidgetRef ref) async {
    // lang.name = en, setting key: tts.en
    final sm = ref.read(
      settingProvider.select((m) => m.of('tts.${lang.name}')),
    );
    final es = EngineSetting.from(lang, sm);
    await tts.stop();
    await tts.awaitSpeakCompletion(true);
    await tts.setSpeechRate(es.rate);
    await tts.setPitch(es.pitch);
    if (es.volume != null) {
      await tts.setVolume(es.volume!);
    }

    // setLanguage must before setVoice
    try {
      await tts.setLanguage(es.language);
    } catch (e) {
      debugPrint('setLanguage failed: $e');
    }

    if (es.voice != null) {
      await tts.setVoice(es.voice!);
    }

    final s =
        {
          Lang.zh: '你好,选择体验更好的语音合成引擎 say something in English',
          Lang.en: 'Hello, I am focus on english speaking',
        }[lang] ??
        '';
    tts.speak(s);
  }

  List<SettingItem> get items => <SettingItem>[
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
          title: 'Display',
          defaults: '',
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
          title: 'Speak',
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
      title: 'English Voice',
      children: [
        SettingItem(
          type: SettingType.choice,
          toType: (v) =>
              v != null ? Voice((v as Map).cast<String, String>()) : null,
          title: 'Voice',
          key: 'tts.en.voice',
          choices: envs,
        ),
        SettingItem(
          type: SettingType.builder,
          title: '',
          tailBuilder: (context, ref, child) => Text('Play Sample'),
          onTap: (_, ref) => _playSample(Lang.en, ref),
        ),
        SettingItem(
          type: SettingType.slider,
          title: 'Rate',
          key: 'tts.en.rate',
          range: Range<double>(0.4, 0.7),
        ),
        SettingItem(
          type: SettingType.slider,
          title: 'Pitch',
          key: 'tts.en.pitch',
          range: Range<double>(0.0, 1.0),
        ),
        SettingItem(
          type: SettingType.slider,
          title: 'Volume',
          key: 'tts.en.volume',
          defaults: 1.0,
          range: Range<double>(0.0, 1.0),
        ),
      ],
    ),
    SettingItem(
      type: SettingType.group,
      title: 'Chinese Voice',
      children: [
        SettingItem(
          type: SettingType.choice,
          toType: (v) =>
              v != null ? Voice((v as Map).cast<String, String>()) : null,
          title: 'Voice',
          key: 'tts.zh.voice',
          choices: zhvs,
        ),
        SettingItem(
          type: SettingType.builder,
          title: '',
          tailBuilder: (context, ref, child) => Text('Play Sample'),
          onTap: (_, ref) => _playSample(Lang.zh, ref),
        ),
        SettingItem(
          type: SettingType.slider,
          title: 'Rate',
          key: 'tts.zh.rate',
          range: Range<double>(0.4, 0.7),
        ),
        SettingItem(
          type: SettingType.slider,
          title: 'Pitch',
          key: 'tts.zh.pitch',
          range: Range<double>(0.0, 1.0),
        ),
        SettingItem(
          type: SettingType.slider,
          title: 'Volume',
          key: 'tts.zh.volume',
          defaults: 1.0,
          range: Range<double>(0.0, 1.0),
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
      tailBuilder: (context, ref, child) => Icon(Icons.folder_special),
      onTap: (context, ref) {
        scan().then((c) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$c book added')));
        });
      },
    ),
    SettingItem(
      type: SettingType.builder,
      title: 'Scan custom folder',
      tailBuilder: (context, ref, child) => Icon(Icons.folder_open),
      onTap: (context, ref) {
        pickDirAndScan().then((c) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$c book added')));
        });
      },
    ),

    SettingItem(
      type: SettingType.builder,
      title: 'Debug',
      builder: (context, ref, child) => Wrap(
        spacing: 8.0, // Horizontal gap between buttons
        runSpacing: 8.0, // Vertical gap between lines
        children: demoPaths.map((action) {
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
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(children: [...items.map((e) => Tile(e))]),
    );
  }
}

/// Widget for setting item
class Tile extends ConsumerWidget {
  const Tile(this.item, {super.key});
  final SettingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // debugPrint('Tile.build for ${item.key}');
    dynamic v;
    if (item.key != null) {
      v = ref.watch(settingProvider.select((m) => m.of(item.key!)));
    }
    if (item.toType != null) {
      v = item.toType?.call(v);
    }
    final tile = switch (item.type) {
      SettingType.builder =>
        item.builder != null
            ? Card(child: item.builder!(context, ref, null))
            : ListTile(
                title: Text(item.title),
                trailing: item.tailBuilder!(context, ref, null),
                onTap: () => item.onTap?.call(context, ref),
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
        trailing: DropdownButton<Object?>(
          key: item.key == null ? null : Key(item.key!),
          value: v ?? item.defaults,
          underline: null,
          onChanged: (v) {
            // debugPrint('v: ${v.runtimeType}');
            ref.read(settingProvider.notifier).put(item.key!, v);
          },
          items: item.choices!
              .map(
                (e) =>
                    DropdownMenuItem<Object?>(value: e.$2, child: Text(e.$1)),
              )
              .toList(),
        ),
      ),
      SettingType.slider => ListTile(
        title: Text(item.title),
        trailing: Text(
          //
          '${v is double ? v.toStringAsFixed(2) : v ?? item.defaults}',
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
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.title.isNotEmpty)
              ListTile(
                title: Text(
                  item.title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
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

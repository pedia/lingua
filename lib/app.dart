import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lingua/settings/setting.dart';

import 'ui/lib.dart';

ThemeData buildTheme(Brightness brightness) {
  final base = ThemeData(brightness: brightness, useMaterial3: true);

  final textTheme = base.textTheme
      .apply(
        fontFamily: 'SECCJK-Regular', // use platform default
        // fontFamily: 'Roboto', // use platform default
        fontFamilyFallback: const [
          
          //   // iOS/MacOS
          //   'PingFang TC',
          //   'PingFang SC',
          //   'Hiragino Sans',
          'SamsungOne', // Samsung specific
          //   // Windows
          //   'Microsoft YaHei',
          //   'Yu Gothic',
          //   'Malgun Gothic',
          //   // Android / Linux generic
          //   'Noto Sans CJK SC',
          //   'Noto Sans CJK JP',
          //   'Noto Sans CJK KR',
        ],
        bodyColor: brightness == Brightness.light
            ? Colors.black87
            : Colors.white,
        displayColor: brightness == Brightness.light
            ? Colors.black87
            : Colors.white,
      )
      .copyWith(
        // Optional: improve readability for Chinese
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          height: 1.55,
          fontSize: 16,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          height: 1.55,
          fontSize: 14.5,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      );

  return base.copyWith(textTheme: textTheme);
}

class LinguaApp extends ConsumerWidget {
  const LinguaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tm = ref.watch(
      settingProvider.select((m) => m.intOf('ui.theme-mode')),
    );
    return MaterialApp(
      title: 'Lingua Reader',
      themeMode: ThemeMode.values[tm],
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('zh', 'TW'),
        Locale('jp', 'JP'),
        Locale('ko', 'KR'),
        Locale('es', 'ES'),
      ],
      home: LibraryFrame(),
    );
  }
}

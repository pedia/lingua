import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'settings/setting.dart';
import 'ui/font.dart';
import 'ui/book.dart';

import 'ui/lib.dart';

class LinguaApp extends ConsumerWidget {
  const LinguaApp({this.family, super.key});
  final String? family;

  ThemeData buildTheme(Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    final textTheme = base.textTheme
        .apply(
          fontFamily: family ?? '',
          fontFamilyFallback: fontFamilyFallback,
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
            fontFamily: family,
            height: 1.55,
            fontSize: 16,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontFamily: family,
            height: 1.55,
            fontSize: 14.5,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontFamily: family,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        );

    return base.copyWith(textTheme: textTheme);
  }

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
        // Locale('es', 'ES'),
      ],
      home: LibraryFrame(),
    );
  }
}

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => LibraryFrame(),
      routes: [
        GoRoute(
          path: 'book/:path',
          builder: (context, state) {
            final _ = state.pathParameters['path']!;
            return Scaffold(
              appBar: AppBar(title: const Text('Details Screen')),
            );
            // BookFrame(book: book, progress: progress, path: path);
          },
        ),
      ],
    ),
  ],
);

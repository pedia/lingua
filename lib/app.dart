import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lingua/hive.dart';
import 'package:lingua/demo/prototype.dart';
import 'package:lingua/demo/route.dart';
import 'package:lingua/demo/sliver.dart';
import 'package:lingua/ui/book.dart';
import 'package:lingua/ui/setting.dart';
import 'package:lingua/ui/shelf.dart';
import 'package:lingua/ui/voice_setting.dart';

import 'settings/setting.dart';
import 'ui/font.dart';
import 'ui/gadget.dart';
import 'ui/read.dart';
import 'ui/lib.dart';
import 'ui/shelf_mgmt.dart';
import 'ui/md.dart';
import 'ui/edit.dart';

extension CupertinoTextThemeDataApply on CupertinoTextThemeData {
  CupertinoTextThemeData withFontFamily(String family) {
    return copyWith(
      textStyle: textStyle.copyWith(fontFamily: family),
      actionTextStyle: actionTextStyle.copyWith(fontFamily: family),
      tabLabelTextStyle: tabLabelTextStyle.copyWith(fontFamily: family),
      navTitleTextStyle: navTitleTextStyle.copyWith(fontFamily: family),
      navLargeTitleTextStyle: navLargeTitleTextStyle.copyWith(
        fontFamily: family,
      ),
      navActionTextStyle: navActionTextStyle.copyWith(fontFamily: family),
      pickerTextStyle: pickerTextStyle.copyWith(fontFamily: family),
      dateTimePickerTextStyle: dateTimePickerTextStyle.copyWith(
        fontFamily: family,
      ),
    );
  }
}

class MainApp extends ConsumerWidget {
  const MainApp({this.family, super.key});
  final String? family;

  ThemeData buildTheme(Brightness brightness) {
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: brightness,
      ),
      iconTheme: IconThemeData(
        color: ColorScheme.fromSeed(seedColor: Colors.blue).primary,
      ),
    );

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
      settingProvider.select((m) => m.intOf('ui.theme-mode', defaults: 0)),
    );
    return MaterialApp.router(
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
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        DefaultMaterialLocalizations.delegate, // <-- THIS FIXES THE ERROR
        DefaultWidgetsLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
      ],
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => RouteScreen()),
          GoRoute(path: '/shelf', builder: (_, _) => ShelfFrame()),
          GoRoute(
            path: '/book/:id',
            builder: (_, state) =>
                BookFrame(id: int.parse(state.pathParameters['id'] ?? '')),
          ),
          GoRoute(path: '/hive', builder: (_, _) => HiveFrame()),
          GoRoute(path: '/setting', builder: (_, _) => SettingFrame()),
          GoRoute(
            path: '/engine',
            builder: (ctx, _) => EngineSettingPage.from(ctx),
          ),
          GoRoute(path: '/route', builder: (_, _) => RouteScreen()),
          GoRoute(path: '/library', builder: (_, _) => LibraryFrame()),
          GoRoute(
            path: '/prototype',
            builder: (_, _) => TestProviderScreen(bookId: '3'),
          ),
          GoRoute(path: '/sliver', builder: (_, _) => SliverFrame()),
          GoRoute(
            path: '/shelf-mgmt',
            builder: (_, _) => ShelfManagementScreen(),
          ),
          GoRoute(path: '/error', builder: (_, _) => ErrScreen("Hello")),
          GoRoute(
            path: '/master-detail',
            builder: (_, _) => TabletReadFrame(2),
          ),
          GoRoute(
            path: '/read/:id',
            builder: (_, state) =>
                ReadFrame(id: int.parse(state.pathParameters['id'] ?? '')),
          ),
          GoRoute(
            path: '/edit/:id',
            builder: (_, state) =>
                BookEditScreen(id: int.parse(state.pathParameters['id'] ?? '')),
          ),
        ],
      ),
    );
  }

  Brightness resolveBrightness(BuildContext context, ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        // Reads the current OS brightness (light/dark) from context
        return MediaQuery.platformBrightnessOf(context);
    }
  }

  Widget c2(BuildContext context, WidgetRef ref) {
    final tm = ref.watch(
      settingProvider.select((m) => m.intOf('ui.theme-mode', defaults: 0)),
    );
    final br = resolveBrightness(context, ThemeMode.values[tm]);
    return CupertinoApp.router(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
      ],
      theme: CupertinoThemeData(
        brightness: br,
        primaryColor: CupertinoColors.activeBlue,
        textTheme: const CupertinoTextThemeData().withFontFamily(family!),
      ),
      // routerConfig: GoRouter(),
    );
  }
}

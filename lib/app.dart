import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lingua/chunk/book.dart';
import 'package:lingua/demo/demo.dart';
import 'package:lingua/demo/offset.dart';
import 'package:lingua/demo/stack.dart';
import 'package:lingua/demo/stuck.dart';
import 'package:lingua/log.dart';
import 'package:lingua/ui/hive.dart';
import 'package:lingua/demo/provider.dart';
import 'package:lingua/demo/sliver.dart';
import 'package:lingua/demo/sliver2.dart';
import 'package:lingua/ui/chapter_list.dart';
import 'package:lingua/ui/search.dart';
import 'package:lingua/ui/setting.dart';
import 'package:lingua/ui/shelf.dart';
import 'package:lingua/zh/fixedit.dart';
import 'package:lingua/chunk/chunk.dart';

import 'settings/setting.dart';
import 'ui/font.dart';
import 'ui/gadget.dart';
import 'ui/shelf_edit.dart';
import 'ui/md.dart';
import 'ui/item_edit.dart';
import 'err.dart';
import 'g.dart';

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
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? Colors.black
          : null,
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
        Locale('es', 'ES'),
      ],
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        DefaultMaterialLocalizations.delegate, // <-- THIS FIXES THE ERROR
        DefaultWidgetsLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
      ],
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) {
              // final id = box.get('last', defaultValue: 0);
              // if (id != 0) {
              //   return BookScreen(id);
              // }
              return ShelfFrame();
            },
          ),
          GoRoute(path: '/shelf', builder: (_, _) => ShelfFrame()),
          GoRoute(
            path: '/book/:id',
            builder: (_, state) {
              final id = state.pint('id', 4);
              box.put('last', id);
              return BookScreen(id);
            },
            onExit: (context, state) {
              box.delete('last');
              return true;
            },
          ),

          GoRoute(
            path: '/book/:id/search',
            builder: (_, state) =>
                SearchFrame(id: state.pint('id', 4), book: state.extra as Book),
          ),
          GoRoute(path: '/setting', builder: (_, _) => SettingFrame()),
          GoRoute(path: '/fixit/edit', builder: (_, _) => FixitEdit()),
          GoRoute(path: '/hive', builder: (_, _) => HiveFrame()),
          GoRoute(path: '/demo', builder: (_, _) => DemoFrame()),
          GoRoute(path: '/provider', builder: (_, _) => ProviderScreen(id: 3)),
          GoRoute(path: '/sliver', builder: (_, _) => LongTextScreen()),
          GoRoute(path: '/stack', builder: (_, _) => NonSliverTextScreen()),
          GoRoute(path: '/tabs', builder: (_, _) => DynamicTabScreen()),
          GoRoute(path: '/shelf/edit', builder: (_, _) => ShelfEditScreen()),
          GoRoute(path: '/font', builder: (_, _) => FontFrame()),
          GoRoute(
            path: '/master-detail',
            builder: (_, _) => TabletReadFrame(2),
          ),

          GoRoute(
            path: '/edit/:id',
            builder: (_, state) => ItemEditScreen(id: state.pint('id', 4)),
          ),
          GoRoute(path: '/note', builder: (_, state) => NoteScreen()),
          GoRoute(path: '/logger', builder: (_, state) => LogViewerScreen()),
          GoRoute(path: '/offset', builder: (_, state) => OffsetDemoScreen()),
          GoRoute(path: '/stuck', builder: (_, state) => StuckScreen()),
          GoRoute(
            path: '/error',
            builder: (context, state) {
              final errorDetails = ref.watch(globalErrorProvider);
              if (errorDetails == null) return InfoScreen('none captured');
              return ErrorScreen(errorDetails: errorDetails);
            },
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

  Widget cupertinoapp(BuildContext context, WidgetRef ref) {
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

extension _StateEx on GoRouterState {
  int pint(String key, int defaults) {
    final v = pathParameters[key] ?? '';
    final n = int.tryParse(v);
    return n ?? defaults;
  }
}

final demoPaths = [
  '/',
  '/book/91',
  '/fixit/edit',
  '/note',
  '/logger',
  '/offset',
  '/stuck',
  '/error',
  '/shelf',
  '/shelf/edit',
  '/hive',
  '/setting',
  '/provider',
  '/demo',
  '/font',
  '/sliver',
  '/stack',
  '/tabs',
  '/search',
  '/master-detail',
];

import 'package:flutter/material.dart';

import 'data/library_store.dart';
import 'settings/app_settings.dart';
import 'translate/translation_service.dart';
import 'ui/lib.dart';

class LinguaApp extends StatelessWidget {
  const LinguaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lingua Reader',
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6F5E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6F5E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: LibraryFrame(),
    );
  }
}

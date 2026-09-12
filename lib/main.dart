import 'dart:io';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:macos_file_open_handler/macos_file_open_handler.dart';
import 'package:open_with_app/open_with_app.dart';
import 'dart:async';

import 'app.dart';
import 'data/library_store.dart';
import 'epub/parser.dart';
import 'settings/app_settings.dart';
import 'translate/translation_service.dart';
import 'ui/lib.dart';

Future<void> _importEpub(Store store, Object? argument) async {
  if (argument is! String || argument.isEmpty) {
    return;
  }

  final file = File(argument);
  if (!file.existsSync()) {
    return;
  }

  try {
    final parsed = const EpubParser().parseBytes(await file.readAsBytes());
    await store.importEpub(
      sourcePath: argument,
      title: parsed.title,
      author: parsed.author,
    );
  } catch (error) {
    debugPrint('Unable to import opened EPUB: $error');
  }
}

/// macos
late final MacosFileOpenSubscription fileOpenSubscription;

// android openfile
final _openWithAppPlugin = OpenWithApp();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // final store = await Store.open();
  // final settings = AppSettings(await SharedPreferences.getInstance());
  // final translation = TranslationService(settings);

  if (Platform.isMacOS) {
    fileOpenSubscription = MacosFileOpenHandler.instance.listen(
      (files) async {
        for (final file in files) {
          debugPrint('Got MacosPackage: ${file.path}');
          OpenFile.send(file.path);
        }
      },
      onError: (error, stackTrace) {
        debugPrint('Could not open file[MacosPackage]: $error');
      },
    );
  }

  if (Platform.isAndroid) {
    // Check if app was opened with a file
    String? initialFile = await _openWithAppPlugin.getInitialFile();

    // Listen for new files opened while app is running
    _openWithAppPlugin.getFileStream().listen((filePath) {
      print("New file: $filePath");
    });
  }

  runApp(ProviderScope(child: LinguaApp()));
}

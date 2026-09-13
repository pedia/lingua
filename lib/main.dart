import 'dart:io';

import 'dart:io';

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
          debugPrint('Got[MacosPackage]: ${file.path}');
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
    debugPrint("initialFile: $initialFile");
    if (initialFile != null) {
      OpenFile.send(initialFile);
    }

    // Listen for new files opened while app is running
    _openWithAppPlugin.getFileStream().listen((filePath) {
      debugPrint("New file: $filePath");
      OpenFile.send(filePath);
    });
  }

  runApp(ProviderScope(child: LinguaApp()));
}

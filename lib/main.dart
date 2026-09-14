import 'dart:async';
import 'package:flutter/material.dart';
import 'package:universal_io/universal_io.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_file_open_handler/macos_file_open_handler.dart';
import 'package:open_with_app/open_with_app.dart';

import 'app.dart';
import 'ui/lib.dart';

/// macos
late final MacosFileOpenSubscription fileOpenSubscription;

// android openfile
late final OpenWithApp _openWithAppPlugin;

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
    _openWithAppPlugin = OpenWithApp();
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

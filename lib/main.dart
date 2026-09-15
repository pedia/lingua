import 'dart:async';
import 'package:flutter/material.dart';
import 'package:universal_io/universal_io.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_file_open_handler/macos_file_open_handler.dart';
import 'package:open_with_app/open_with_app.dart';

import 'app.dart';
import 'ui/lib.dart';
import 'ui/font.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS) {
    MacosFileOpenHandler.instance.listen(
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
    final openWithAppPlugin = OpenWithApp();
    // Check if app was opened with a file
    String? initialFile = await openWithAppPlugin.getInitialFile();
    debugPrint("initialFile: $initialFile");
    if (initialFile != null) {
      OpenFile.send(initialFile);
    }

    // Listen for new files opened while app is running
    openWithAppPlugin.getFileStream().listen((filePath) {
      debugPrint("New file: $filePath");
      OpenFile.send(filePath);
    });
  }

  final ff = await osFontFamily();
  debugPrint('osfont: $ff');

  runApp(ProviderScope(child: LinguaApp(family: ff)));
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:universal_io/universal_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_file_open_handler/macos_file_open_handler.dart';
import 'package:riverpod_devtools/riverpod_devtools.dart';
import 'package:open_with_app/open_with_app.dart';
import 'package:hive_ce/hive_ce.dart';
import 'hive/hive_registrar.g.dart';

import 'app.dart';
import 'log.dart';
import 'g.dart';
import 'ui/open.dart';
import 'ui/font.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logger.log(
      '${details.exceptionAsString()}\n${details.stack}',
      level: 'ERROR',
    );
  };

  // Capture asynchronous / platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.log('Async Error: $error\n$stack', level: 'FATAL');
    return true;
  };

  Hive.registerAdapters();

  final docs = await getApplicationDocumentsDirectory();
  await openBoxes(docs.path);

  if (Platform.isMacOS) {
    MacosFileOpenHandler.instance.listen(
      (files) async {
        for (final file in files) {
          debugPrint('Got[MacosPackage]: ${file.path}');
          OpenPump.send(file.path);
        }
      },
      onError: (error, stackTrace) {
        debugPrint('Could not open file[MacosPackage]: $error');
      },
    );
  } else if (Platform.isAndroid) {
    final openWithAppPlugin = OpenWithApp();
    // Check if app was opened with a file
    String? initialFile = await openWithAppPlugin.getInitialFile();
    if (initialFile != null) {
      OpenPump.send(initialFile);
    }

    // Listen for new files opened while app is running
    openWithAppPlugin.getFileStream().listen((filePath) {
      debugPrint("New file: $filePath");
      OpenPump.send(filePath);
    });
  }

  final ff = await osFontFamily();
  debugPrint('osfont: $ff ${Directory.current.path}');

  runApp(
    ProviderScope(
      observers: [RiverpodDevToolsObserver()],
      child: MainApp(family: ff),
    ),
  );
}

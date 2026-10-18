import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_io/universal_io.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_file_open_handler/macos_file_open_handler.dart';
import 'package:riverpod_devtools/riverpod_devtools.dart';
import 'package:open_with_app/open_with_app.dart';
import 'package:hive_ce/hive_ce.dart';
import 'hive/hive_registrar.g.dart';

import 'app.dart';
import 'g.dart';
import 'ui/lib.dart';
import 'ui/font.dart';
import 'err.dart';

Future<void> main2() async {
  try {
    final json = await rootBundle.loadString('lib/riverpod_dependencies.json');
    RiverpodDevToolsRegistry.instance.loadFromJson(json);
  } catch (_) {
    // DevTools shows setup instructions
  }

  Hive.registerAdapters();

  final docs = await getApplicationDocumentsDirectory();
  gbox = await Hive.openBox('all', path: docs.path);
  gid = gbox.get('gid', defaultValue: 10);

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
  debugPrint('osfont: $ff ${Directory.current.path}');

  runApp(
    ProviderScope(
      observers: [RiverpodDevToolsObserver()],
      child: MainApp(family: ff),
    ),
  );
}

void main() {
  final container = ProviderContainer();

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.dumpErrorToConsole(details);
        container.read(globalErrorProvider.notifier).reportError(details);
      };

      await main2();
    },
    (error, stackTrace) {
      final details = FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Async / Zone',
      );
      container.read(globalErrorProvider.notifier).reportError(details);
    },
  );
}

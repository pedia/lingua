import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:saf_util/saf_util.dart' as saf;
import 'package:saf/saf.dart' as saf;

/// Globally pump `OpenFile` event to Widgets
class OpenPump {
  static final _controller = StreamController<String>.broadcast();
  static Stream<String> get stream => _controller.stream;

  static void send(String fp) async {
    print('$fp, ${isSharedStorage(fp)}');
    if (!isSharedStorage(fp)) {
      fp = await cp(fp);
    }
    _controller.add(fp);
  }

  static void dispose() {
    _controller.close();
  }

  /// iOS/Android Must copy
  /// macOS → Better, but still safer to copy
  /// Always copy the file to a permanent location
  static Future<String> cp(String fp) async {
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    if (fp.startsWith('content://')) {
      final u = saf.Saf();
      String fileName = p.basename(fp);
      fileName = Uri.decodeComponent(fileName);
      fileName = p.basename(fileName);
      debugPrint('cp $fp -> $fileName');
      await u.copyToLocalFile(fp, p.join(booksDir.path, fileName));
      return fileName;
    } else {
      final src = File(fp);

      final fileName = p.basename(fp);
      final dest = p.join(booksDir.path, fileName);

      await src.copy(dest);
      return fileName;
    }
  }
}

/// check file from pick_file
bool isSharedStorage(String path) {
  // If it's running on iOS or macOS
  if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
    // On macOS/iOS, picked files are typically sandbox-secured or temporary.
    // Usually, you treat them based on whether they are in your app's documents directory.
    return false;
  }

  // Android-specific checks
  if (path.startsWith('/storage/emulated/0/')) {
    return true;
  }

  /// [scan] app documents/books/*.epub
  if (!path.contains('/')) {
    return true;
  }

  return false;
}

/// Scan application documents books/ or Shared folder
Future<int> scan({String? folder}) async {
  late Directory dir;
  if (folder == null) {
    final appDir = await getApplicationDocumentsDirectory();
    dir = Directory(p.join(appDir.path, 'books'));
  } else {
    dir = Directory(folder);
  }
  debugPrint('scan $folder');

  final c = Completer<int>();
  int count = 0;
  dir
      .list(followLinks: false)
      .listen(
        (e) {
          debugPrint('scan loop $e');

          if (e.path.endsWith('.epub')) {
            final fp = folder == null
                ? e.path.substring(dir.path.length + 1) // +1 for last /
                : e.path; // absolute full path with start /

            debugPrint('send $fp');
            OpenPump.send(fp);
            count += 1;
          }
        },
        onDone: () {
          c.complete(count);
        },
      );

  return c.future;
}

void pickFiles() async {
  if (Platform.isAndroid) {
    final docs = await saf.SafUtil().pickFiles(
      mimeTypes: ['application/epub+zip'],
    );
    if (docs != null) {
      for (final f in docs) {
        OpenPump.send(f.uri);
      }
    }
  } else {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['epub'],
      allowMultiple: true,
    );
    // /data/user/0/com.lingua.reader.lingua/cache/file_picker/1792052890257/最后...
    if (result?.files != null) {
      for (final file in result!.files) {
        OpenPump.send(file.path!);
      }

      FilePicker.clearTemporaryFiles();
    }
  }
}

Future<int> pickDirAndScan() async {
  if (Platform.isAndroid) {
    final u = saf.SafUtil();
    final dir = await u.pickDirectory(
      writePermission: false,
      persistablePermission: false,
    );
    if (dir != null) {
      final fs = await u.list(dir.uri);

      Isolate.run(() {
        for (final f in fs) {
          if (!f.isDir && f.name.endsWith('.epub')) {
            OpenPump.send(f.uri);
          }
        }
      });

      return fs.length;
    }
  } else {
    final dir = await FilePicker.getDirectoryPath();
    if (dir != null) {
      return scan(folder: dir);
    }
  }
  return 0;
}

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Globally pump `OpenFile` event to Widgets
class OpenPump {
  static final _controller = StreamController<String>.broadcast();
  static Stream<String> get stream => _controller.stream;

  static void send(String fp) {
    cp(fp).then((nf) {
      _controller.add(nf);
    });
  }

  static void dispose() {
    _controller.close();
  }

  /// iOS/Android Must copy
  /// macOS → Better, but still safer to copy
  /// Always copy the file to a permanent location
  static Future<String> cp(String fp) async {
    final src = File(fp);

    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'books'));

    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final fileName = p.basename(fp);
    final dest = '${booksDir.path}/$fileName';

    await src.copy(dest);
    return dest.substring(booksDir.path.length + 1); // +1 for last /
  }
}

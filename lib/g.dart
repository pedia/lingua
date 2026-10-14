import 'dart:io';
import 'dart:typed_data';
import 'package:hive_ce/hive_ce.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// stupid global instance
late final Box gbox;

late int gid;
int nextId() {
  gid++;
  gbox.put('gid', gid);
  return gid;
}

/// Returns PNG bytes of a thumbnail with width = 64 (height maintains aspect ratio).
Uint8List? iconify(Uint8List imageBytes, {int width = 128}) {
  // Decode the image (supports JPG, PNG, WebP, GIF, BMP, etc.)
  final original = img.decodeImage(imageBytes);
  if (original == null) return null;

  // Resize – only width is given → height is calculated automatically
  final thumbnail = img.copyResize(
    original,
    width: width,
    // Optional better quality:
    interpolation: img.Interpolation.average, // or linear / cubic
  );

  // Encode back to PNG (or use encodeJpg for smaller size)
  return Uint8List.fromList(img.encodePng(thumbnail));
  // return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 85));
}

// not work
Future<Uint8List?> iconify2(Uint8List imageBytes, {int width = 64}) async {
  return await (img.Command()
        ..decodeImage(imageBytes)
        ..copyResize(width: 64)
        ..encodePng())
      .getBytes();
}

Widget? boxImage(String key) {
  final cb = gbox.get(key);
  if (cb != null) {
    return SizedBox(
      height: 64, // not worked in ListTile
      child: Image.memory(cb, width: 48, fit: BoxFit.fitWidth),
    );
  }
  return null;
}

/// check file from pick_file
bool isSharedStorage(String path) {
  // If it's running on iOS or macOS
  if (!kIsWeb && (Platform.isMacOS || Platform.isIOS)) {
    // On macOS/iOS, picked files are typically sandbox-secured or temporary.
    // Usually, you treat them based on whether they are in your app's documents directory.
    return false;
  }

  // Android-specific checks
  if (path.startsWith('content://') ||
      path.startsWith('/storage/emulated/0/')) {
    return true;
  }

  return false;
}

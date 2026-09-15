import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'osfont_platform_interface.dart';

class Osfont {
  Future<String?> getPlatformVersion() {
    return OsfontPlatform.instance.getPlatformVersion();
  }

  Future<List<SystemFont>> getAvailableFonts() {
    return OsfontPlatform.instance.getAvailableFonts();
  }

  /// Load a system font into Flutter so you can use it with fontFamily
  static Future<String?> loadFont(
    SystemFont font, {
    String? customFamilyName,
  }) async {
    final family =
        customFamilyName ??
        font.fileName.replaceAll(
          RegExp(r'\.(ttf|otf|ttc)$', caseSensitive: false),
          '',
        );

    try {
      final bytes = await File(font.path).readAsBytes();
      final loader = FontLoader(family);
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      return family; // now you can use TextStyle(fontFamily: family)
    } catch (e) {
      debugPrint('Failed to load font ${font.path}: $e');
      return null;
    }
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'osfont_platform_interface.dart';

/// An implementation of [OsfontPlatform] that uses method channels.
class MethodChannelOsfont extends OsfontPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('osfont');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<List<SystemFont>> getAvailableFonts() async {
    final List<dynamic>? result = await methodChannel
        .invokeMethod<List<Object?>>('getAvailableFonts');
    if (result == null) return <SystemFont>[];
    try {
      return result
          .map((e) => SystemFont.fromMap(e as Map))
          .where((f) => f.path.isNotEmpty && File(f.path).existsSync())
          .toList();
    } on PlatformException catch (e) {
      debugPrint('Failed to get system fonts: ${e.message}');
      return [];
    }
  }
}

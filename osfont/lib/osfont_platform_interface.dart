import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'osfont_method_channel.dart';

class SystemFont {
  final String path;
  final int weight;
  final int slant; // 0 = normal, 1 = italic
  final int ttcIndex;
  final List<Map<String, dynamic>> axes;

  SystemFont({
    required this.path,
    required this.weight,
    required this.slant,
    required this.ttcIndex,
    required this.axes,
  });

  factory SystemFont.fromMap(Map<dynamic, dynamic> map) {
    return SystemFont(
      path: map['path'] as String? ?? '',
      weight: map['weight'] as int? ?? 400, // regular
      slant: map['slant'] as int? ?? 0,
      ttcIndex: map['ttcIndex'] as int? ?? 0,
      axes:
          (map['axes'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }

  bool get isItalic => slant != 0;
  String get fileName => path.split('/').last;
}

abstract class OsfontPlatform extends PlatformInterface {
  /// Constructs a OsfontPlatform.
  OsfontPlatform() : super(token: _token);

  static final Object _token = Object();

  static OsfontPlatform _instance = MethodChannelOsfont();

  /// The default instance of [OsfontPlatform] to use.
  ///
  /// Defaults to [MethodChannelOsfont].
  static OsfontPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OsfontPlatform] when
  /// they register themselves.
  static set instance(OsfontPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<List<SystemFont>> getAvailableFonts() async {
    throw UnimplementedError('getAvailableFonts() has not been implemented.');
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:osfont/osfont.dart';

// packages/flutter/lib/src/material/typography.dart
const fontFamilyFallback = [
  '.osdefault',
  '.AppleSystemUIFont',
  'CupertinoSystemDisplay',
  'Segoe UI',
  'Roboto',
];

/// flutter supported system font, return family name
Future<String?> osFontFamily() async {
  if (Platform.isMacOS) return '.AppleSystemUIFont';
  if (Platform.isIOS) return 'CupertinoSystemDisplay';
  if (Platform.isAndroid) {
    final fl = await Osfont().getAvailableFonts();
    try {
      // MIUI / HyperOS: MiSans.ttc MiSans-Regular.ttf
      // ColorOS: OPPOSans.ttc or OPPOSans-Regular.ttf
      // Vivo: VivoSans.ttc or VivoSans-Regular.ttf
      // Galaxy, 'NotoSerifCJK-Regular',FlymeSans-Regular.ttf
      // TODO: sort `fl`
      final ds = {
        'seccjk-regular',
        'misans-regular',
        'opposans-regular',
        'vivosans-regular',
        'flymesans-regular',
        // 'notosanscjk-regular',
        // 'notosanscjk',
        // 'misans',
        // 'opposans',
        // 'vivosans',
        // 'notoserifcjk-regular',
      };
      final font = fl.firstWhere(
        (e) => ds.contains(
          e.fileName.substring(0, e.fileName.indexOf('.')).toLowerCase(),
        ),
      );
      // debugPrint('font ${font.path}');
      return await Osfont.loadFont(font.path, customFamilyName: '.osdefault');
    } catch (e) {
      debugPrint('loadFont failed: $e');
      return 'Roboto';
    }
  }
  return null;
}

class FontFrame extends StatelessWidget {
  const FontFrame({super.key});

  final List<String> fonts = const [
    '.osdefault', // osfont
    '.AppleSystemUIFont',
    'CupertinoSystemDisplay',
    'Segoe UI', // Windows
    'Roboto', // Android
  ];

  final demo = """English is hard, right? 123.
「私は、ガラスを食べられますか？」――いいえ！それは私を傷つけません。
『我能吞下玻璃嗎？』——不，這傷不到我的身體！
“나는유리를먹을수있습니까?”…… 아니요! 그래도 아프지 않아요.
“简”体、中文，年度报告。""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Font Demo')),
      body: Builder(
        // for inside DefaultTextStyle
        builder: (context) => Scrollbar(
          child: ListView(
            primary: true,
            children: [
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(
                    'Default ${DefaultTextStyle.of(context).style.fontFamily ?? ''}',
                  ),
                  subtitle: Text(
                    demo,
                    style: DefaultTextStyle.of(context).style.copyWith(
                      fontSize: 18,
                      height: 1.5,
                      decoration: null,
                    ),
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(
                    'body ${Theme.of(context).textTheme.bodyMedium?.fontFamily ?? ''}',
                  ),
                  subtitle: Text(
                    demo,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              ...fonts.map(
                (font) => Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    title: Text(
                      font,
                      style: TextStyle(fontFamily: font, fontSize: 16),
                    ),
                    subtitle: Text(
                      demo,
                      style: TextStyle(
                        fontFamily: font,
                        fontFamilyFallback: [],
                        fontSize: 18,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

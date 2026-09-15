import 'package:flutter/material.dart';

class FontFrame extends StatelessWidget {
  const FontFrame({super.key});

  final List<String> fonts = const [
    'NotoSansTC', // assets
    'SECCJK-Regular',
    // Generic
    'NotoSerifCJK-Regular',

    // Android common
    'Roboto',
    'Noto Sans',
    'Noto Sans CJK TC',
    'Noto Sans TC',
    'Noto Sans SC',
    'Source Han Sans TC',
    'SEC CJK',

    // iOS / macOS
    '.AppleSystemUIFont',
    'PingFang TC',
    'PingFang SC',
    'PingFang HK',
    '.SF UI Text',
    '.SF UI Display',
    'Helvetica',
    'Helvetica Neue',
    'Arial',
  ];

  final demo = """「私は、ガラスを食べられますか？」――いいえ！それは私を傷つけません。
『我能吞下玻璃嗎？』——不，這傷不到我的身體！
“나는 유리를 먹을 수 있습니까?”…… 아니요! 그래도 아프지 않아요.
“简”体中文。',English 123""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Font Demo')),
      body: Builder(
        // for inside DefaultTextStyle
        builder: (context) => Scrollbar(
          child: ListView(
            primary: true,
            children: [
              Text(demo, style: TextStyle(fontFamily: 'SamsungOne')),
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

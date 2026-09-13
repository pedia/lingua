import 'package:flutter/material.dart';

class FontFrame extends StatelessWidget {
  const FontFrame({super.key});

  final List<String> fonts = const [
    'NotoSansTC',
    // Generic
    'sans-serif',
    'serif',
    'monospace', // Samsung
    'Roboto', // Samsung
    /// not work for Chinese on Samsung Android
    'Droid Sans',
    'Noto Sans CJK',
    'Source Han Sans',
    'Samsung One',
    'Samsung Sans',

    // Android common
    'Roboto',
    'Noto Sans',
    'Noto Sans CJK TC',
    'Noto Sans TC',
    'Noto Sans SC',
    'Source Han Sans TC',
    'SEC CJK',

    // iOS / macOS
    'PingFang TC',
    'PingFang SC',
    'PingFang HK',
    '.SF UI Text',
    '.SF UI Display',
    'Helvetica',
    'Helvetica Neue',
    'Arial',
  ];

  final demo = """繁“體”中文?'简体中文' English 123""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Font Demo')),
      body: Scrollbar(
        child: ListView(
          children: [
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(
                  'Default ${DefaultTextStyle.of(context).style.fontFamily ?? ''}',
                ),
                subtitle: Text(
                  demo,
                  style: DefaultTextStyle.of(
                    context,
                  ).style.copyWith(fontSize: 18, height: 1.5),
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
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(
                    font,
                    style: TextStyle(fontFamily: font, fontSize: 16),
                  ),
                  subtitle: Text(
                    demo,
                    style: TextStyle(
                      fontFamily: font,
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
    );
  }
}

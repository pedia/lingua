import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  final dir = Directory('freya');

  /// (001, freya/ch001.dart)
  final ps = <(String, String)>[];

  await for (final e in dir.list()) {
    final fn = p.basename(e.path);
    final m = RegExp(r'ch(\d+)\.md').firstMatch(fn);
    if (m != null) {
      ps.add((m.group(1)!, e.path));
    }
  }

  ps.sort(((String, String) a, (String, String) b) {
    return a.$1.compareTo(b.$1);
  });

  final buf = StringBuffer('''
import 'epub/epub.dart';

final freya = Book(
    title: 'Freya Cycle',
    author: 'aistudio',
    chapters: [
''');

  // Open read stream, decode to UTF-8, split into lines, take first line

  for (final p in ps) {
    final firstLine = await File(
      p.$2,
    ).openRead().transform(utf8.decoder).transform(const LineSplitter()).first;

    final title = firstLine.replaceAll('# ', '');

    buf.writeln('''
Chapter.cache(title: '$title', href: '', chunks: md2ch(ch${p.$1})),''');
  }

  buf.writeln('''
  ]
);
''');

  for (final p in ps) {
    final s = File(p.$2).readAsStringSync();
    buf.writeln("final ch${p.$1} = '''$s''';");
  }

  File('lib/freya.dart').writeAsStringSync(buf.toString());
}

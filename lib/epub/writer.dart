import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'epub.dart';
import '../settings/app_settings.dart';

class EpubWriter {
  const EpubWriter();

  Uint8List write({
    required String title,
    required String author,
    required ReaderViewMode mode,
    required List<Chapter> chapters,
  }) {
    final archive = Archive();
    void add(String name, String body, {bool compress = true}) {
      final bytes = utf8.encode(body);
      final file = ArchiveFile(name, bytes.length, bytes);
      file.compression = compress
          ? CompressionType.deflate
          : CompressionType.none;
      archive.addFile(file);
    }

    add('mimetype', 'application/epub+zip', compress: false);
    add('META-INF/container.xml', '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''');

    final manifest = StringBuffer();
    final spine = StringBuffer();
    for (var i = 0; i < chapters.length; i++) {
      final id = 'ch$i';
      manifest.writeln(
        '    <item id="$id" href="$id.xhtml" media-type="application/xhtml+xml"/>',
      );
      spine.writeln('    <itemref idref="$id"/>');
      add('OEBPS/$id.xhtml', _chapterXhtml(chapters[i]));
    }

    add('OEBPS/content.opf', '''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="bookid">lingua-${title.hashCode}</dc:identifier>
    <dc:title>${_esc(title)}</dc:title>
    <dc:creator>${_esc(author)}</dc:creator>
    <dc:language>${mode == ReaderViewMode.english ? 'en' : 'zh'}</dc:language>
  </metadata>
  <manifest>
$manifest  </manifest>
  <spine>
$spine  </spine>
</package>''');

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  String _chapterXhtml(Chapter ch) {
    final body = StringBuffer();
    body.writeln('<h1>${_esc(ch.title)}</h1>');

    for (var i = 0; i < ch.lines.length; i++) {
      final line = ch.lines[i];
      if (line is TextBlock) {
        switch (line.lang) {
          case '':
            body.writeln('<p>${_esc(line.text)}</p>');
          default:
            body.writeln('<p lang=${line.lang}>${_esc(line.text)}</p>');
        }
      }
    }
    return '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>${_esc(ch.title)}</title></head>
<body>
$body
</body>
</html>''';
  }

  String _esc(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingua/epub/book.dart';
import 'package:lingua/epub/parser.dart';
import 'package:lingua/epub/writer.dart';
import 'package:lingua/epub/text_splitter.dart';
import 'package:lingua/settings/app_settings.dart';

void main() {
  test('equal', () {
    expect(Line('Hello world.'), Line('Hello world.'));
  });
  test('splits latin and cjk sentences', () {
    expect(
      splitSentences('Hello world. How are you? Fine!'),
      equals([Line('Hello world.','en'), Line('How are you?','en'), Line('Fine!','en')]),
    );
    expect(splitSentences('你好。世界！'), equals([Line('你好。','zh'), Line('世界！','zh')]));
  });

  test('parses a minimal epub', () {
    final zip = _minimalEpub();
    final book = const EpubParser().parseBytes(zip);
    expect(book.title, 'Test Book');
    expect(book.author, 'Ada');
    expect(book.chapters, hasLength(1));
    expect(book.chapters.first.lines.first.text, contains('Once upon a time'));
  });

  test('rejects encrypted epubs', () {
    final zip = _minimalEpub(encrypted: true);
    expect(() => const EpubParser().parseBytes(zip),
        throwsA(isA<DrmEpubException>()));
  });

  test('writes a bilingual epub that can be parsed', () {
    final bytes = const EpubWriter().write(
      title: 'Export',
      author: 'Ada',
      mode: ReaderViewMode.lingua,
      chapters: [
        Chapter.cache(
          href: '',
          title: 'One',
          lines: [Line('Hello world.', 'en'), Line('你好世界。', 'zh')],
        ),
      ],
    );
    final book = const EpubParser().parseBytes(bytes);
    expect(book.title, 'Export');
    expect(book.chapters.single.text, contains('Hello world.'));
    expect(book.chapters.single.text, contains('你好世界。'));
  });
}

Uint8List _minimalEpub({bool encrypted = false}) {
  final archive = Archive();
  void add(String name, String body) {
    final bytes = utf8.encode(body);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('mimetype', 'application/epub+zip');
  add(
    'META-INF/container.xml',
    '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''',
  );
  if (encrypted) {
    add('META-INF/encryption.xml', '<encryption/>');
  }
  add(
    'OEBPS/content.opf',
    '''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Test Book</dc:title>
    <dc:creator>Ada</dc:creator>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
  </spine>
</package>''',
  );
  add(
    'OEBPS/ch1.xhtml',
    '''<html><head><title>One</title></head>
<body><h1>One</h1><p>Once upon a time. The end.</p></body></html>''',
  );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

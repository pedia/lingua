import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/parser.dart' as dom;
import 'package:flutter_test/flutter_test.dart';

import 'package:lingua/epub/epub.dart';
import 'package:lingua/epub/parser.dart';
import 'package:lingua/epub/writer.dart';
import 'package:lingua/hw.dart';
import 'package:lingua/settings/app_settings.dart';

void main() {
  test('unwrap', () {
    final doc = dom.parse('''<div id="chapter01.xhtml" class="calibre3">
</div><div class="calibre3"><h1 class="calibre4"><span id="sigil_toc_id_1" class="calibre5"><b class="calibre6">前</b><b class="calibre6">言</b></span></h1></div>
<div class="calibre3">
	<p class="calibre7"><span class="calibre10">非常幸运</span></p>
</div>
''');
    final ces = unwrap(doc.body!).children;
    expect(ces.length, 2);
    expect(ces.first.localName, 'h1');
    expect(ces.first.text, '前言');
    expect(ces[1].localName, 'p');
    expect(ces[1].text, '非常幸运');
    expect(ces[1].innerHtml, '<span class="calibre10">非常幸运</span>');
    ces.forEach((e) => print(e.outerHtml));
  });
  test('parses inside', () {
    expect(EpubParser.html2text('<div>hello</div>'), 'hello');
  });
  test('parses a minimal epub', () {
    final zip = _minimalEpub();
    final book = const EpubParser().parseBytes(zip);
    expect(book.title, 'Test Book');
    expect(book.author, 'Ada');
    expect(book.description, 'nd');
    expect(book.chapters, hasLength(1));
    expect(book.chapters.first.chunks.first.text, contains('One'));
    expect(book.chapters.first.chunks[1].text, contains('Once upon a time'));
  });

  test('rejects encrypted epubs', () {
    final zip = _minimalEpub(encrypted: true);
    expect(
      () => const EpubParser().parseBytes(zip),
      throwsA(isA<DRMException>()),
    );
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
          chunks: [
            Chunk('Hello world.', lang: 'en'),
            Chunk('你好世界。', lang: 'zh'),
          ],
        ),
      ],
    );
    final book = const EpubParser().parseBytes(bytes);
    expect(book.title, 'Export');
    expect(book.chapters.single.chunks[0], contains('Hello world.'));
    expect(book.chapters.single.chunks[1], contains('你好世界。'));
  });

  test('extract', () {
    final doc = dom.parse('''
<?xml version="1.0" encoding="utf-8"?>
<!--?xml version="1.0" encoding="utf-8" standalone="no"?--><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title/>
<link href="../Styles/stylesheet.css" rel="stylesheet" type="text/css"/>
</head>
<body>
<h1 class="hidden" title="封面"/>
<div align="center" class="image-single">
<img alt="" src="../Images/cover.jpg"/>
</div>
</body>
</html>
''');
    expect(doc.querySelectorAll('title').length, 1);
    expect(doc.querySelector('title')?.innerHtml, isNotEmpty);
    expect(doc.querySelectorAll('body title'), isEmpty);
    expect(doc.querySelector('h1')?.innerHtml, isNull);
  });
}

Uint8List _minimalEpub({bool encrypted = false}) {
  final archive = Archive();
  void add(String name, String body) {
    final bytes = utf8.encode(body);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('mimetype', 'application/epub+zip');
  add('META-INF/container.xml', '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''');
  if (encrypted) {
    add('META-INF/encryption.xml', '<encryption/>');
  }
  add('OEBPS/content.opf', '''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Test Book</dc:title>
    <dc:creator>Ada</dc:creator>
    <dc:language>en</dc:language>
    <description xmlns="http://purl.org/dc/elements/1.1/">nd</description>
  </metadata>
  <manifest>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
  </spine>
</package>''');
  add('OEBPS/ch1.xhtml', '''<html><head><title>One</title></head>
<body><h1>One</h1><p lang="en">Once upon a time. The end.</p></body></html>''');
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

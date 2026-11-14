/// EPUB archive reader producing [Book] and lazy [Chapter]s.
library chunk.epub;

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'chunk.dart';

/// Parses `.epub` files and byte buffers into a [Book].
class EpubParser {
  /// Parse an EPUB archive from raw [bytes] into a [Book].
  static Book parseBytes(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = {
      for (final f in archive.files)
        if (f.isFile) f.name: f,
    };

    final container = files['META-INF/container.xml'];
    if (container == null) {
      throw const FormatException('Missing META-INF/container.xml');
    }

    final containerXml = XmlDocument.parse(
      utf8.decode(container.content as List<int>),
    );
    final opfPath = containerXml
        .findAllElements('rootfile')
        .firstOrNull
        ?.getAttribute('full-path');
    if (opfPath == null || !files.containsKey(opfPath)) {
      throw const FormatException('Missing root OPF file');
    }

    final opfXml = XmlDocument.parse(
      utf8.decode(files[opfPath]!.content as List<int>),
    );
    final opfDir = p.dirname(opfPath);
    final title =
        opfXml.findAllElements('dc:title').firstOrNull?.innerText.trim() ??
        'EPUB';
    final author = opfXml
        .findAllElements('dc:creator')
        .firstOrNull
        ?.innerText
        .trim();

    final manifest = <String, String>{};
    for (final item in opfXml.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) manifest[id] = href;
    }

    final spineDocs = <({String path, String html})>[];
    final globalFootnotes = <String, String>{};

    for (final itemref in opfXml.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      final relHref = manifest[idref];
      if (relHref == null) continue;

      final fullHref = opfDir.isEmpty || opfDir == '.'
          ? relHref
          : p.posix.join(opfDir, relHref);
      final docFile = files[fullHref] ?? files[relHref];
      if (docFile == null) continue;

      final html = utf8.decode(
        docFile.content as List<int>,
        allowMalformed: true,
      );
      spineDocs.add((path: fullHref, html: html));
      globalFootnotes.addAll(HtmlChunkParser.extractFootnotes(html));
    }

    final chapters = spineDocs.map((doc) {
      final fallback = p.posix.basenameWithoutExtension(doc.path);
      final chapterTitle = HtmlChunkParser.extractChapterTitle(
        doc.html,
        fallback,
      );
      return LazyChapter(
        chapterTitle,
        () => HtmlChunkParser.parseHtml(doc.html, footnotes: globalFootnotes),
      );
    }).toList();

    return Book(title: title, author: author, chapters: chapters);
  }

  /// Parse an EPUB file at [filePath] into a [Book].
  static Future<Book> parseFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return parseBytes(bytes);
  }
}

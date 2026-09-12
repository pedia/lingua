import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import 'book.dart';
import 'text_splitter.dart';

class EpubParser {
  const EpubParser();

  Book parseBytes(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    return parseArchive(archive);
  }

  Book parseArchive(Archive archive) {
    final files = <String, ArchiveFile>{};
    for (final file in archive) {
      if (!file.isFile) {
        continue;
      }
      files[_normalize(file.name)] = file;
    }

    if (files.keys.any((name) => name.endsWith('meta-inf/encryption.xml'))) {
      throw const DrmEpubException();
    }

    final container = _xml(files, 'meta-inf/container.xml');
    final rootPath = container
        .findAllElements('rootfile')
        .map((el) => el.getAttribute('full-path'))
        .firstWhere(
          (path) => path != null && path.isNotEmpty,
          orElse: () => null,
        );
    if (rootPath == null) {
      throw const EpubParseException('EPUB is missing a package document.');
    }

    final opfPath = _normalize(rootPath);
    final opf = _xml(files, opfPath);
    final opfDir = _dirName(opfPath);

    final title = _firstText(opf, 'title') ?? 'Untitled';
    final author = _firstText(opf, 'creator') ?? 'Unknown author';
    final language = _firstText(opf, 'language') ?? 'en';

    final manifest = <String, String>{};
    for (final item in opf.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id == null || href == null) {
        continue;
      }
      manifest[id] = _normalize('$opfDir$href');
    }

    final chapters = <Chapter>[];
    var index = 1;
    for (final itemRef in opf.findAllElements('itemref')) {
      final idRef = itemRef.getAttribute('idref');
      if (idRef == null) {
        continue;
      }
      final href = manifest[idRef];
      if (href == null) {
        continue;
      }
      final file = _file(files, href);
      if (file == null) {
        continue;
      }
      final html = utf8.decode(file.content as List<int>);
      final extracted = _extractHtml(html);
      final sentences = splitSentences(extracted);
      if (sentences.isEmpty) {
        continue;
      }
      chapters.add(
        Chapter.from(href, file),
      );
      index += 1;
    }

    if (chapters.isEmpty) {
      throw const EpubParseException(
        'No readable text was found in this EPUB.',
      );
    }

    return Book(
      title: title,
      author: author,
      language: language.split('-').first.toLowerCase(),
      chapters: chapters,
    );
  }

  ArchiveFile? _file(Map<String, ArchiveFile> files, String path) {
    return files[_normalize(path)];
  }

  XmlDocument _xml(Map<String, ArchiveFile> files, String path) {
    final file = _file(files, path);
    if (file == null) {
      throw EpubParseException('Missing $path in EPUB.');
    }
    return XmlDocument.parse(utf8.decode(file.content as List<int>));
  }

  String? _firstText(XmlDocument doc, String localName) {
    for (final el in doc.descendants.whereType<XmlElement>()) {
      if (el.localName == localName) {
        final text = el.innerText.trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  static Chapter decode(String href, ArchiveFile file) {
    final html = utf8.decode(file.content as List<int>);
    final extracted = _extractHtml(html);
    return Chapter.cache(
        href: href,
        lines: splitSentences(extracted),
        title: _headingFromHtml(html) ?? '');
  }

  static String _extractHtml(String html) {
    final document = html_parser.parse(html);
    for (final tag in ['script', 'style', 'nav']) {
      document.querySelectorAll(tag).forEach((node) => node.remove());
    }
    return collapseWhitespace(
      document.body?.text ?? document.documentElement?.text ?? '',
    );
  }

  static String? _headingFromHtml(String html) {
    final document = html_parser.parse(html);
    for (final selector in ['h1', 'h2', 'h3', 'title']) {
      final text = document.querySelector(selector)?.text.trim();
      if (text != null && text.isNotEmpty) {
        return collapseWhitespace(text);
      }
    }
    return null;
  }

  String _dirName(String path) {
    final index = path.lastIndexOf('/');
    if (index < 0) {
      return '';
    }
    return path.substring(0, index + 1);
  }

  String _normalize(String path) {
    return path
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/'), '')
        .toLowerCase();
  }
}

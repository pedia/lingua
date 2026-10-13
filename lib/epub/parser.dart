import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:html/parser.dart' show parse;

import 'epub.dart';

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

    final title = _firstText(opf, 'title') ?? '';
    final author = _firstText(opf, 'creator') ?? '';
    final language = _firstText(opf, 'language') ?? 'en';
    final description = _firstText(opf, 'description') ?? '';

    final manifest = <String, String>{};
    for (final item in opf.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id == null || href == null) {
        continue;
      }
      manifest[id] = _normalize('$opfDir$href');
    }

    String? cover = manifest['cover'];
    if (cover == null) {
      // A. EPUB 3 cover-image
      for (final item in opf.findAllElements('item')) {
        final props = item.getAttribute('properties') ?? '';
        if (props.contains('cover-image')) {
          cover = item.getAttribute('href');
        }
      }
    }

    if (cover == null) {
      // B. meta name="cover"
      final coverMeta = opf
          .findAllElements('meta')
          .where((m) => m.getAttribute('name') == 'cover');
      if (coverMeta.isNotEmpty) {
        final coverId = coverMeta.first.getAttribute('content');
        if (coverId != null) {
          final item = opf
              .findAllElements('item')
              .where((i) => i.getAttribute('id') == coverId);
          if (item.isNotEmpty) {
            cover = item.first.getAttribute('href');
          }
        }
      }
    }

    if (cover == null) {
      // C. First image fallback
      for (final item in opf.findAllElements('item')) {
        final mediaType = item.getAttribute('media-type') ?? '';
        if (mediaType.startsWith('image/')) {
          cover = item.getAttribute('href');
        }
      }
    }

    if (cover != null) {
      cover = Uri(path: opfPath).resolve(cover).path.toLowerCase();
    }

    final chapters = <Chapter>[];
    // Read spine
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

      chapters.add(Chapter.from(href, file));
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
      files: files,
      cover: cover,
      description: html2text(description),
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

  String _dirName(String path) {
    final index = path.lastIndexOf('/');
    if (index < 0) {
      return '';
    }
    return path.substring(0, index + 1);
  }

  static String _normalize(String path) {
    return path
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/'), '')
        .toLowerCase();
  }

  static String html2text(String src) {
    if (src.contains('<div>')) {
      final doc = parse(src);
      return doc.body?.text ?? '';
    }
    return src;
  }
}

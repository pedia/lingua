import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';
import 'package:html/dom.dart';

import 'book.dart';
import 'text_splitter.dart';
import 'extract.dart';

class EpubParser {
  const EpubParser();

  Book parseBytes(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    return parseArchive(archive);
  }

  Book parseArchive(Archive archive) {
    final files = <String, ArchiveFile>{};
    for (final file in archive) {
      // print(file.name);
      if (!file.isFile) {
        continue;
      }
      files[_normalize(file.name)] = file;
    }

    // print(files);

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

      // TODO: check first 2 chapter empty or use nav
      if (index < 2) {}

      chapters.add(Chapter.from(href, file));
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
      files: files,
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
    final dom = html_parser.parse(html);

    String? title;
    for (final selector in ['title', 'h1', 'h2', 'h3']) {
      final text = dom.querySelector(selector)?.text.trim();
      if (text != null && text.isNotEmpty) {
        title = text;
        break;
      }
    }

    return Chapter.cache(
      href: href,
      lines: extractLines(dom, href),
      title: title ?? '',
    );
  }

  static Chapter decode2(String href, ArchiveFile file) {
    final html = utf8.decode(file.content as List<int>);
    final dom = html_parser.parse(html);

    String? title;
    for (final selector in ['title', 'h1', 'h2', 'h3']) {
      final text = dom.querySelector(selector)?.text.trim();
      if (text != null &&
          text.isNotEmpty &&
          !{'未知', 'Unknown'}.contains(text)) {
        title = text;
        break;
      }
    }

    final base = Uri(path: href);

    // fix relative Picture.src
    final lines = extract(dom.body!).map((line) {
      if (line is Picture) {
        final nu = base.resolve(line.src);
        print('${line.src} to ${_normalize(nu.path)}');
        return Picture(_normalize(nu.path));
      } else {
        return line;
      }
    }).toList();

    return Chapter.cache(href: href, lines: lines, title: title ?? '');
  }

  /// TODO: impl with textOf(node)
  static List<Line> extractLines(Document dom, String href) {
    final base = Uri(path: href);
    final ret = <Line>[];
    for (var p in dom.querySelectorAll('p')) {
      final t = p.text.trim();
      if (t.isNotEmpty) {
        var lang = p.attributes['lang'] ?? detectLang(p.text);
        ret.add(Line(t, lang));
      } else {
        // for (final c in p.children) {
        //   print('child: ${c.localName}');
        // }
        if (p.children.isNotEmpty) {
          final src = p.querySelector('img')?.attributes['src'];
          if (src != null && src.isNotEmpty) {
            final nu = base.resolve(src);
            ret.add(Picture(_normalize(nu.path)));
          }
        }
      }
    }
    return ret;
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
}

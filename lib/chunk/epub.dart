/// EPUB archive reader producing [Book] and lazy [Chapter]s.
library chunk.epub;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'chunk.dart';

/// Parses `.epub` files and byte buffers into a [Book].
class EpubParser {
  /// Parse an EPUB archive from raw [bytes] into a [Book].
  static Book parseBytes(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, ArchiveFile>{
      for (final f in archive.files)
        if (f.isFile) _normalizeArchivePath(f.name): f,
    };

    final container = files['META-INF/container.xml'];
    if (container == null) {
      throw const FormatException('Missing META-INF/container.xml');
    }

    final containerXml =
        XmlDocument.parse(utf8.decode(container.content as List<int>));
    final opfPathRaw = containerXml
        .findAllElements('rootfile')
        .firstOrNull
        ?.getAttribute('full-path');
    final opfPath =
        opfPathRaw != null ? _normalizeArchivePath(opfPathRaw) : null;
    if (opfPath == null || !files.containsKey(opfPath)) {
      throw const FormatException('Missing root OPF file');
    }

    final opfXml =
        XmlDocument.parse(utf8.decode(files[opfPath]!.content as List<int>));
    final metadataEl = opfXml.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'metadata')
        .firstOrNull;
    String? metaText(String local) {
      final root = metadataEl ?? opfXml.rootElement;
      for (final el in root.descendants.whereType<XmlElement>()) {
        if (el.name.local == local) {
          final t = el.innerText.trim();
          if (t.isNotEmpty) return t;
        }
      }
      return null;
    }

    final title = metaText('title') ?? 'EPUB';
    final author = metaText('creator');
    final lang = metaText('language');
    final description = metaText('description');

    final manifest =
        <String, ({String href, String? mediaType, String? properties})>{};
    for (final item in opfXml.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) {
        manifest[id] = (
          href: href,
          mediaType: item.getAttribute('media-type')?.toLowerCase(),
          properties: item.getAttribute('properties'),
        );
      }
    }

    final spineDocs = <({String path, String html})>[];

    for (final itemref in opfXml.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      final item = manifest[idref];
      if (item == null) continue;
      final relHref = item.href;

      final fullHref = _resolvePath(opfPath, relHref);
      final docFile = (fullHref.isNotEmpty ? files[fullHref] : null) ??
          files[_normalizeArchivePath(relHref)];
      if (docFile == null) continue;

      final docPath =
          fullHref.isNotEmpty ? fullHref : _normalizeArchivePath(relHref);
      final html = utf8.decode(docFile.content as List<int>, allowMalformed: true);
      spineDocs.add((path: docPath, html: html));
    }

    Map<String, String>? globalFootnotes;
    Map<String, String> getGlobalFootnotes() {
      if (globalFootnotes != null) return globalFootnotes!;
      final map = <String, String>{};
      for (final d in spineDocs) {
        map.addAll(HtmlChunkParser.extractFootnotes(d.html));
      }
      return globalFootnotes = map;
    }

    Uint8List? readArchiveBytes(String key) {
      if (key.isEmpty) return null;
      final file = files[key];
      if (file == null) return null;
      final content = file.content;
      return content is Uint8List
          ? content
          : Uint8List.fromList(content as List<int>);
    }

    Uint8List? resolveAsset(String docPath, String src) =>
        readArchiveBytes(_resolvePath(docPath, src));

    bool isImageHref(String? mediaType, String href) {
      if (mediaType != null && mediaType.startsWith('image/')) return true;
      final lower = href.split('?').first.split('#').first.toLowerCase();
      return lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.webp') ||
          lower.endsWith('.bmp') ||
          lower.endsWith('.svg');
    }

    Uint8List? resolveCoverFromHref(String href, {String? mediaType}) {
      final resolved = _resolvePath(opfPath, href);
      final key = resolved.isNotEmpty ? resolved : _normalizeArchivePath(href);
      if (isImageHref(mediaType, href)) {
        return readArchiveBytes(key);
      }
      final pageBytes = readArchiveBytes(key);
      if (pageBytes == null) return null;
      final coverHtml = utf8.decode(pageBytes, allowMalformed: true);
      final chunks = HtmlChunkParser.parseHtml(
        coverHtml,
        resolveImageBytes: (src) => resolveAsset(key, src),
      );
      for (final c in chunks) {
        if (c is Picture) {
          final b = c.bytes();
          if (b != null) return b;
        }
      }
      return null;
    }

    Uint8List? resolveCover() {
      for (final item in manifest.values) {
        final props = item.properties?.split(RegExp(r'\s+')) ?? const <String>[];
        if (props.contains('cover-image')) {
          final b = resolveCoverFromHref(item.href, mediaType: item.mediaType);
          if (b != null) return b;
        }
      }

      final metaRoot = metadataEl ?? opfXml.rootElement;
      for (final meta in metaRoot.descendants.whereType<XmlElement>()) {
        if (meta.name.local == 'meta' &&
            meta.getAttribute('name')?.toLowerCase() == 'cover') {
          final content = meta.getAttribute('content')?.trim();
          if (content != null && content.isNotEmpty) {
            final item = manifest[content];
            final b = item != null
                ? resolveCoverFromHref(item.href, mediaType: item.mediaType)
                : resolveCoverFromHref(content);
            if (b != null) return b;
          }
        }
      }

      for (final ref in opfXml.findAllElements('reference')) {
        if (ref.getAttribute('type')?.toLowerCase() == 'cover') {
          final href = ref.getAttribute('href')?.trim();
          if (href != null && href.isNotEmpty) {
            final b = resolveCoverFromHref(href);
            if (b != null) return b;
          }
        }
      }

      for (final id in ['cover-image', 'cover']) {
        final item = manifest[id];
        if (item != null && isImageHref(item.mediaType, item.href)) {
          final b = resolveCoverFromHref(item.href, mediaType: item.mediaType);
          if (b != null) return b;
        }
      }
      return null;
    }

    final chapters = spineDocs.map((doc) {
      final fileName = doc.path.split('/').last;
      final dot = fileName.lastIndexOf('.');
      final fallback = dot > 0 ? fileName.substring(0, dot) : fileName;
      final chapterTitle =
          HtmlChunkParser.extractChapterTitle(doc.html, fallback);
      return LazyChapter(
        chapterTitle,
        () => HtmlChunkParser.parseHtml(
          doc.html,
          footnotes: getGlobalFootnotes(),
          resolveImageBytes: (src) => resolveAsset(doc.path, src),
        ),
      );
    }).toList();

    return Book(
      title: title,
      author: author,
      lang: lang,
      description: description,
      cover: resolveCover,
      chapters: chapters,
    );
  }

  /// Parse an EPUB file at [filePath] into a [Book].
  static Future<Book> parseFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return parseBytes(bytes);
  }

  static String _normalizeArchivePath(String raw) {
    final clean = raw.replaceAll('\\', '/');
    return Uri(path: '/$clean').normalizePath().pathSegments.join('/');
  }

  static String _resolvePath(String basePath, String href) {
    final trimmed = href.trim().replaceAll('\\', '/');
    if (trimmed.isEmpty) return '';
    try {
      final base = Uri(path: basePath.startsWith('/') ? basePath : '/$basePath');
      final resolved = base.resolve(trimmed);
      if (resolved.hasScheme) return '';
      return resolved.pathSegments.join('/');
    } catch (_) {
      return '';
    }
  }
}

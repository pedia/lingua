/// MOBI / AZW / AZW3 (PalmDB + PalmDOC + HuffCDIC + KF8) reader producing [Book] and lazy [Chapter]s.
library chunk.mobi;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'chunk.dart';

/// Parses DRM-free `.mobi`, `.azw`, and `.azw3` files and bytes into a [Book].
class MobiParser {
  static final RegExp _pageBreak = RegExp(
    r'<mbp:pagebreak\b[^>]*\/?>',
    caseSensitive: false,
  );

  /// Returns true if [bytes] looks like a PalmDB/Mobipocket (`BOOKMOBI` / `TEXtREAd`) file.
  static bool isMobiBytes(List<int> bytes) {
    if (bytes.length < 68) return false;
    final sig = latin1.decode(bytes.sublist(60, 68), allowInvalid: true);
    return sig == 'BOOKMOBI' || sig == 'TEXtREAd';
  }

  /// Parse a `.mobi`, `.azw`, or `.azw3` byte buffer into a [Book].
  static Book parseBytes(List<int> bytes) {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    if (data.length < 78) {
      throw const FormatException('Invalid MOBI/AZW file: header too short');
    }

    final bd = ByteData.sublistView(data);
    final pdbTitle = _readCString(data, 0, 32);
    final numRecords = bd.getUint16(76, Endian.big);
    if (numRecords == 0 || data.length < 78 + numRecords * 8) {
      throw const FormatException('Invalid MOBI/AZW file: invalid record table');
    }

    final offsets = List<int>.generate(
      numRecords,
      (i) => bd.getUint32(78 + i * 8, Endian.big),
    );
    Uint8List recordAt(int index) {
      final start = offsets[index];
      final end = index + 1 < numRecords ? offsets[index + 1] : data.length;
      if (start < 0 || end < start || end > data.length) {
        throw FormatException('Invalid record offset at $index');
      }
      return Uint8List.sublistView(data, start, end);
    }

    int headerIdx = 0;
    var headerRec = recordAt(headerIdx);
    var header = _parseHeader(headerRec);

    // Dual MOBI6 + KF8 (AZW3) combo files point to a BOUNDARY record before the KF8 header.
    final boundaryIdx = header.kf8Boundary;
    if (boundaryIdx != null &&
        boundaryIdx > 0 &&
        boundaryIdx + 1 < numRecords) {
      final bRec = recordAt(boundaryIdx);
      if (bRec.length >= 8 &&
          ascii.decode(bRec.sublist(0, 8), allowInvalid: true) == 'BOUNDARY') {
        final mobi6Header = header;
        headerIdx = boundaryIdx + 1;
        headerRec = recordAt(headerIdx);
        header = _parseHeader(headerRec, fallback: mobi6Header);
      }
    }

    if (header.encryption != 0) {
      throw const FormatException(
        'Encrypted/DRM MOBI/AZW/AZW3 files are not supported',
      );
    }

    final textBytes = _decompressAllText(
      headerIdx: headerIdx,
      header: header,
      numRecords: numRecords,
      recordAt: recordAt,
    );

    Uint8List htmlBytes = textBytes;
    if (header.fdstRecordOffset != null) {
      final fdstRecIdx = headerIdx + header.fdstRecordOffset!;
      if (fdstRecIdx < numRecords) {
        final flow0 = _extractFdstFlow0(recordAt(fdstRecIdx), textBytes);
        if (flow0 != null) htmlBytes = flow0;
      }
    }

    final html = header.textEncoding == 65001
        ? utf8.decode(htmlBytes, allowMalformed: true)
        : latin1.decode(htmlBytes, allowInvalid: true);

    String resolveRecindex(String recindex) {
      final idx = int.tryParse(recindex.trim());
      if (idx == null || idx <= 0) return 'image_$recindex.bin';
      final firstImg = header.firstImageRecord;
      if (firstImg != null && firstImg + idx - 1 < numRecords) {
        final imgRec = recordAt(firstImg + idx - 1);
        final ext = _detectImageExt(imgRec);
        return 'mobi_image_${idx.toString().padLeft(5, '0')}.$ext';
      }
      return 'mobi_image_${idx.toString().padLeft(5, '0')}.jpg';
    }

    Uint8List? resolveMobiImageBytes(String src) {
      final firstImg = header.firstImageRecord;
      if (firstImg == null) return null;
      final match = RegExp(r'mobi_image_(\d+)').firstMatch(src);
      final idx = int.tryParse(match?.group(1) ?? src.trim());
      if (idx == null || idx <= 0 || firstImg + idx - 1 >= numRecords) {
        return null;
      }
      return recordAt(firstImg + idx - 1);
    }

    final globalFootnotes = HtmlChunkParser.extractFootnotes(html);
    final rawSections = html
        .split(_pageBreak)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final sections = rawSections.isEmpty ? <String>[html] : rawSections;

    final bookTitle = header.title?.isNotEmpty == true
        ? header.title!
        : (pdbTitle.isNotEmpty ? pdbTitle : 'MOBI');

    final chapters = <Chapter>[];
    for (int i = 0; i < sections.length; i++) {
      final sectionHtml = sections[i];
      final fallbackTitle =
          sections.length == 1 ? bookTitle : 'Chapter ${i + 1}';
      final chapterTitle =
          HtmlChunkParser.extractChapterTitle(sectionHtml, fallbackTitle);
      chapters.add(
        LazyChapter(
          chapterTitle,
          () => HtmlChunkParser.parseHtml(
            sectionHtml,
            footnotes: globalFootnotes,
            resolveRecindex: resolveRecindex,
            resolveImageBytes: resolveMobiImageBytes,
          ),
        ),
      );
    }

    Uint8List? resolveCover() {
      final firstImg = header.firstImageRecord;
      final coverOff = header.coverOffset;
      if (firstImg == null || coverOff == null) return null;
      final recIdx = firstImg + coverOff;
      if (recIdx < 0 || recIdx >= numRecords) return null;
      return recordAt(recIdx);
    }

    return Book(
      title: bookTitle,
      author: header.author,
      lang: header.lang,
      description: header.description,
      cover: resolveCover,
      chapters: chapters,
    );
  }

  /// Parse a `.mobi`, `.azw`, or `.azw3` file at [filePath] into a [Book].
  static Future<Book> parseFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return parseBytes(bytes);
  }

  // --- Header & EXTH Parsing ---

  static _MobiHeader _parseHeader(
    Uint8List rec0, {
    _MobiHeader? fallback,
  }) {
    if (rec0.length < 16) {
      throw const FormatException('Invalid PalmDOC record 0');
    }
    final bd = ByteData.sublistView(rec0);
    final compression = bd.getUint16(0, Endian.big);
    final textLength = bd.getUint32(4, Endian.big);
    final textRecordCount = bd.getUint16(8, Endian.big);
    final encryption = bd.getUint16(12, Endian.big);

    int textEncoding = 1252;
    int extraDataFlags = 0;
    int? firstImageRecord = fallback?.firstImageRecord;
    int? huffOffset;
    int? huffCount;
    int? fdstOffset;
    String? title;
    String? author;
    String? lang;
    String? description;
    int? coverOffset;
    int? thumbOffset;
    int? kf8Boundary;

    String? decodeField(Uint8List payload) {
      if (payload.isEmpty) return null;
      final s = (textEncoding == 65001
              ? utf8.decode(payload, allowMalformed: true)
              : latin1.decode(payload, allowInvalid: true))
          .trim();
      return s.isEmpty ? null : s;
    }

    final hasMobi = rec0.length >= 24 &&
        ascii.decode(rec0.sublist(16, 20), allowInvalid: true) == 'MOBI';

    if (hasMobi) {
      final headerLen = bd.getUint32(20, Endian.big);
      if (rec0.length >= 32) {
        textEncoding = bd.getUint32(28, Endian.big);
      }
      final version = rec0.length >= 40 ? bd.getUint32(36, Endian.big) : 0;

      if (rec0.length >= 92) {
        final fullNameOff = bd.getUint32(84, Endian.big);
        final fullNameLen = bd.getUint32(88, Endian.big);
        if (fullNameOff > 0 &&
            fullNameLen > 0 &&
            fullNameOff + fullNameLen <= rec0.length) {
          title = decodeField(rec0.sublist(fullNameOff, fullNameOff + fullNameLen));
        }
      }

      if (headerLen >= 80 && rec0.length >= 96) {
        final locale = bd.getUint32(92, Endian.big);
        lang ??= _langFromMobiLocale(locale);
      }

      if (headerLen >= 96 && rec0.length >= 112) {
        final imgRec = bd.getUint32(108, Endian.big);
        if (imgRec != 0xFFFFFFFF) firstImageRecord = imgRec;
      }

      if (headerLen >= 104 && rec0.length >= 120) {
        final hOff = bd.getUint32(112, Endian.big);
        final hCnt = bd.getUint32(116, Endian.big);
        if (hOff != 0xFFFFFFFF && hCnt > 0) {
          huffOffset = hOff;
          huffCount = hCnt;
        }
      }

      if (version >= 8 && headerLen >= 180 && rec0.length >= 196) {
        final fdst = bd.getUint32(192, Endian.big);
        if (fdst != 0xFFFFFFFF && fdst > 0) fdstOffset = fdst;
      }

      if (headerLen >= 228 && rec0.length >= 244) {
        extraDataFlags = bd.getUint16(242, Endian.big);
      }

      final exthFlags =
          (headerLen >= 116 && rec0.length >= 132) ? bd.getUint32(128, Endian.big) : 0;
      final exthStart = 16 + headerLen;
      if ((exthFlags & 0x40) != 0 && exthStart + 12 <= rec0.length) {
        if (ascii.decode(rec0.sublist(exthStart, exthStart + 4), allowInvalid: true) ==
            'EXTH') {
          final count = bd.getUint32(exthStart + 8, Endian.big);
          int pos = exthStart + 12;
          for (int i = 0; i < count && pos + 8 <= rec0.length; i++) {
            final recType = bd.getUint32(pos, Endian.big);
            final recLen = bd.getUint32(pos + 4, Endian.big);
            if (recLen < 8 || pos + recLen > rec0.length) break;
            final payload = rec0.sublist(pos + 8, pos + recLen);

            if (recType == 100) {
              author = decodeField(payload) ?? author;
            } else if (recType == 103) {
              description = decodeField(payload) ?? description;
            } else if (recType == 121 && payload.length >= 4) {
              final b = ByteData.sublistView(payload).getUint32(0, Endian.big);
              if (b != 0xFFFFFFFF) kf8Boundary = b;
            } else if (recType == 201 && payload.length >= 4) {
              final c = ByteData.sublistView(payload).getUint32(0, Endian.big);
              if (c != 0xFFFFFFFF) coverOffset = c;
            } else if (recType == 202 && payload.length >= 4) {
              final t = ByteData.sublistView(payload).getUint32(0, Endian.big);
              if (t != 0xFFFFFFFF) thumbOffset = t;
            } else if (recType == 503) {
              title = decodeField(payload) ?? title;
            } else if (recType == 524) {
              lang = decodeField(payload) ?? lang;
            }
            pos += recLen;
          }
        }
      }
    }

    return _MobiHeader(
      compression: compression,
      textLength: textLength,
      textRecordCount: textRecordCount,
      encryption: encryption,
      textEncoding: textEncoding,
      extraDataFlags: extraDataFlags,
      firstImageRecord: firstImageRecord,
      huffOffset: huffOffset,
      huffCount: huffCount,
      fdstRecordOffset: fdstOffset,
      kf8Boundary: kf8Boundary,
      title: title ?? fallback?.title,
      author: author ?? fallback?.author,
      lang: lang ?? fallback?.lang,
      description: description ?? fallback?.description,
      coverOffset: coverOffset ?? thumbOffset ?? fallback?.coverOffset,
    );
  }

  static String? _langFromMobiLocale(int locale) {
    if (locale == 0) return null;
    final langId = locale & 0xFF;
    switch (langId) {
      case 0x04:
        return (locale & 0xFFFF) == 0x0404 ? 'zh-TW' : 'zh';
      case 0x07:
        return 'de';
      case 0x09:
        return 'en';
      case 0x0A:
        return 'es';
      case 0x0C:
        return 'fr';
      case 0x10:
        return 'it';
      case 0x11:
        return 'ja';
      case 0x12:
        return 'ko';
      case 0x16:
        return 'pt';
      case 0x19:
        return 'ru';
      default:
        return null;
    }
  }

  // --- Decompression (None, PalmDOC LZ77, HuffCDIC) ---

  static Uint8List _decompressAllText({
    required int headerIdx,
    required _MobiHeader header,
    required int numRecords,
    required Uint8List Function(int index) recordAt,
  }) {
    _HuffCdicDecoder? huff;
    if (header.compression == 17480) {
      if (header.huffOffset == null || header.huffCount == null) {
        throw const FormatException('Missing HUFF/CDIC tables');
      }
      final huffBase = headerIdx + header.huffOffset!;
      final huffRec = recordAt(huffBase);
      final cdicRecs = [
        for (int i = 1; i < header.huffCount!; i++)
          if (huffBase + i < numRecords) recordAt(huffBase + i),
      ];
      huff = _HuffCdicDecoder(huffRec, cdicRecs);
    }

    final builder = BytesBuilder(copy: false);
    for (int i = 1; i <= header.textRecordCount; i++) {
      final recIndex = headerIdx + i;
      if (recIndex >= numRecords) break;
      final raw = _trimExtraData(recordAt(recIndex), header.extraDataFlags);

      if (header.compression == 1) {
        builder.add(raw);
      } else if (header.compression == 2) {
        builder.add(_decompressPalmDoc(raw));
      } else if (header.compression == 17480) {
        builder.add(huff!.decompress(raw));
      } else {
        throw FormatException(
          'Unsupported MOBI compression: ${header.compression}',
        );
      }
    }

    final out = builder.takeBytes();
    if (header.textLength > 0 && out.length > header.textLength) {
      return Uint8List.sublistView(out, 0, header.textLength);
    }
    return out;
  }

  static Uint8List _trimExtraData(Uint8List rec, int flags) {
    int end = rec.length;
    if (flags == 0 || end == 0) return rec;

    for (int bit = 1; bit < 16; bit++) {
      if ((flags & (1 << bit)) != 0) {
        int size = 0;
        int shift = 0;
        int pos = end - 1;
        while (pos >= 0 && shift < 28) {
          final v = rec[pos];
          size |= (v & 0x7F) << shift;
          shift += 7;
          pos--;
          if ((v & 0x80) != 0) break;
        }
        if (size > 0 && size <= end) {
          end -= size;
        }
      }
    }

    if ((flags & 1) != 0 && end > 0) {
      final overlap = (rec[end - 1] & 0x03) + 1;
      if (overlap <= end) end -= overlap;
    }

    return Uint8List.sublistView(rec, 0, end);
  }

  static Uint8List _decompressPalmDoc(Uint8List src) {
    final out = <int>[];
    int i = 0;
    while (i < src.length) {
      final b = src[i++];
      if (b == 0 || (b >= 9 && b <= 0x7F)) {
        out.add(b);
      } else if (b >= 1 && b <= 8) {
        for (int k = 0; k < b && i < src.length; k++) {
          out.add(src[i++]);
        }
      } else if (b >= 0xC0) {
        out.add(0x20);
        out.add(b ^ 0x80);
      } else {
        if (i >= src.length) break;
        final pair = (b << 8) | src[i++];
        final dist = (pair >> 3) & 0x07FF;
        final len = (pair & 0x07) + 3;
        if (dist > 0 && dist <= out.length) {
          for (int k = 0; k < len; k++) {
            out.add(out[out.length - dist]);
          }
        }
      }
    }
    return Uint8List.fromList(out);
  }

  static Uint8List? _extractFdstFlow0(Uint8List fdstRec, Uint8List textBytes) {
    if (fdstRec.length < 20) return null;
    if (ascii.decode(fdstRec.sublist(0, 4), allowInvalid: true) != 'FDST') {
      return null;
    }
    final bd = ByteData.sublistView(fdstRec);
    final numFlows = bd.getUint32(8, Endian.big);
    if (numFlows == 0) return null;
    final start = bd.getUint32(12, Endian.big);
    final end = bd.getUint32(16, Endian.big);
    if (start <= end && end <= textBytes.length) {
      return Uint8List.sublistView(textBytes, start, end);
    }
    return null;
  }

  static String _readCString(Uint8List data, int offset, int maxLen) {
    final end = (offset + maxLen).clamp(0, data.length);
    int nul = offset;
    while (nul < end && data[nul] != 0) {
      nul++;
    }
    return utf8.decode(data.sublist(offset, nul), allowMalformed: true).trim();
  }

  static String _detectImageExt(Uint8List img) {
    if (img.length >= 4 &&
        img[0] == 0x89 &&
        img[1] == 0x50 &&
        img[2] == 0x4E &&
        img[3] == 0x47) {
      return 'png';
    }
    if (img.length >= 3 && img[0] == 0x47 && img[1] == 0x49 && img[2] == 0x46) {
      return 'gif';
    }
    return 'jpg';
  }
}

class _MobiHeader {
  _MobiHeader({
    required this.compression,
    required this.textLength,
    required this.textRecordCount,
    required this.encryption,
    required this.textEncoding,
    required this.extraDataFlags,
    this.firstImageRecord,
    this.huffOffset,
    this.huffCount,
    this.fdstRecordOffset,
    this.kf8Boundary,
    this.title,
    this.author,
    this.lang,
    this.description,
    this.coverOffset,
  });

  final int compression;
  final int textLength;
  final int textRecordCount;
  final int encryption;
  final int textEncoding;
  final int extraDataFlags;
  final int? firstImageRecord;
  final int? huffOffset;
  final int? huffCount;
  final int? fdstRecordOffset;
  final int? kf8Boundary;
  final String? title;
  final String? author;
  final String? lang;
  final String? description;
  final int? coverOffset;
}

/// Decoder for Amazon/Mobipocket HUFF/CDIC dictionary compression.
class _HuffCdicDecoder {
  _HuffCdicDecoder(Uint8List huffRec, List<Uint8List> cdicRecs) {
    if (huffRec.length < 24 ||
        ascii.decode(huffRec.sublist(0, 4), allowInvalid: true) != 'HUFF') {
      throw const FormatException('Invalid HUFF header');
    }
    final bd = ByteData.sublistView(huffRec);
    final off1 = bd.getUint32(8, Endian.big);
    final off2 = bd.getUint32(12, Endian.big);

    _dict1 = List<int>.generate(
      256,
      (i) => bd.getUint32(off1 + i * 4, Endian.big),
    );

    _mincode = List<int>.filled(33, 0);
    _maxcode = List<int>.filled(33, 0);
    for (int i = 1; i <= 32; i++) {
      final minVal = bd.getUint32(off2 + (i - 1) * 8, Endian.big);
      final maxVal = bd.getUint32(off2 + (i - 1) * 8 + 4, Endian.big);
      _mincode[i] = minVal << (32 - i);
      _maxcode[i] = ((maxVal + 1) << (32 - i)) - 1;
    }

    for (final cdic in cdicRecs) {
      if (cdic.length < 16 ||
          ascii.decode(cdic.sublist(0, 4), allowInvalid: true) != 'CDIC') {
        continue;
      }
      final cbd = ByteData.sublistView(cdic);
      final phrasesInRec = cbd.getUint32(8, Endian.big);
      final codeLen = cbd.getUint32(12, Endian.big);
      if (_entryBits == 0) _entryBits = codeLen;
      final limit = 1 << codeLen;
      for (int i = 0; i < limit && _phrases.length < phrasesInRec; i++) {
        final offset = cbd.getUint16(16 + i * 2, Endian.big);
        final absOff = 16 + offset;
        if (absOff + 2 > cdic.length) break;
        final lenAndFlag = cbd.getUint16(absOff, Endian.big);
        final len = lenAndFlag & 0x7FFF;
        final isLeaf = (lenAndFlag & 0x8000) != 0;
        final slice = Uint8List.sublistView(
          cdic,
          absOff + 2,
          (absOff + 2 + len).clamp(0, cdic.length),
        );
        _phrases.add((data: slice, isLeaf: isLeaf));
      }
    }
  }

  late final List<int> _dict1;
  late final List<int> _mincode;
  late final List<int> _maxcode;
  final List<({Uint8List data, bool isLeaf})> _phrases = [];
  int _entryBits = 0;

  Uint8List decompress(Uint8List src) {
    final out = BytesBuilder(copy: false);
    _decodeInto(src, out);
    return out.takeBytes();
  }

  void _decodeInto(Uint8List src, BytesBuilder out) {
    int bitPos = 0;
    final totalBits = src.length * 8;

    while (bitPos < totalBits) {
      final byteIdx = bitPos >> 3;
      final bitShift = bitPos & 7;
      int window = 0;
      for (int k = 0; k < 5; k++) {
        final b = byteIdx + k < src.length ? src[byteIdx + k] : 0;
        window = (window << 8) | b;
      }
      final x = (window >> (8 - bitShift)) & 0xFFFFFFFF;

      final v = _dict1[x >> 24];
      int codelen = v & 0x1F;
      final term = (v & 0x80) != 0;
      int maxc = ((v >> 8) + 1) << (32 - codelen);
      maxc = (maxc - 1) & 0xFFFFFFFF;

      if (!term) {
        if (codelen <= 0) codelen = 1;
        while (codelen < 32 && x < _mincode[codelen]) {
          codelen++;
        }
        maxc = _maxcode[codelen] & 0xFFFFFFFF;
      }

      if (codelen <= 0) break;
      bitPos += codelen;
      if (bitPos > totalBits) break;

      final dictIdx = (maxc - x) >> (32 - codelen);
      if (dictIdx < 0 || dictIdx >= _phrases.length) break;

      final phrase = _phrases[dictIdx];
      if (phrase.isLeaf) {
        out.add(phrase.data);
      } else {
        _decodeInto(phrase.data, out);
      }
    }
  }
}

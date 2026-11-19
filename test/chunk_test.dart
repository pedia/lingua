import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../lib/chunk/chunk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Language detection', () {
    test('detects language from class attribute', () {
      const html = '''
        <p class="en">Long live America</p>
        <p class="zh">她知道自己在一個盒子裡</p>
        <p class="es">Hola mundo maravilloso</p>
        <p class="jp">吾輩は猫である</p>
        <p class="kr">안녕하세요 세계</p>
      ''';

      final chunks = ChunkParser.parseHtml(html);
      expect(chunks.length, equals(5));
      expect(chunks[0].lang, equals(Lang.en));
      expect(chunks[0].text, equals('Long live America'));
      expect(chunks[0].spans, isEmpty);

      expect(chunks[1].lang, equals(Lang.zh));
      expect(chunks[1].text, equals('她知道自己在一個盒子裡'));

      expect(chunks[2].lang, equals(Lang.es));
      expect(chunks[3].lang, equals(Lang.jp));
      expect(chunks[4].lang, equals(Lang.kr));
    });

    test('detects script from text when class is absent', () {
      const html = '''
        <p>This is pure English language text.</p>
        <p>这是纯正的简体中文段落。</p>
        <p>日本語のひらがなと漢字のテストです。</p>
        <p>한국어 문장 분석 테스트입니다.</p>
      ''';

      final chunks = ChunkParser.parseHtml(html);
      expect(chunks[0].lang, equals(Lang.en));
      expect(chunks[1].lang, equals(Lang.zh));
      expect(chunks[2].lang, equals(Lang.jp));
      expect(chunks[3].lang, equals(Lang.kr));
    });
  });

  group('Chunk, Span, Anchor, and Image', () {
    test('extracts Anchor.link from TOC item and id on heading', () {
      const html = '''
        <li class="calibre13">
            <h4 class="calibre14"><a href="part0004.html#section_2_1">白船事故</a></h4>
        </li>
        <h3 id="section_2_1" class="calibre18">白船事故</h3>
      ''';

      final chunks = ChunkParser.parseHtml(html);
      expect(chunks.length, equals(2));

      final toc = chunks[0];
      expect(toc.strong, isTrue);
      expect(toc.spans.length, equals(1));
      final tocAnchor = toc.spans[0] as Anchor;
      expect(tocAnchor.text, equals('白船事故'));
      expect(tocAnchor.link, equals('part0004.html#section_2_1'));
      expect(tocAnchor.note, isNull);

      final heading = chunks[1];
      expect(heading.id, equals('section_2_1'));
      expect(heading.text, equals('白船事故'));
      expect(heading.strong, isTrue);
    });

    test(
      'splits mixed inline content into Span and Anchor while ignoring HTML formatting',
      () {
        const html = '''
        <p>See <a href="ch1.html#intro">Introduction</a> and <strong>key point</strong> before <a href="#fn-1">[1]</a>.</p>
        <aside epub:type="footnote" id="fn-1">Resolved footnote text.</aside>
      ''';

        final chunks = ChunkParser.parseHtml(html);
        expect(chunks.length, equals(1));

        final p = chunks[0];
        expect(p.text, isNull);
        expect(p.strong, isFalse);
        expect(p.spans.length, equals(5));

        expect(p.spans[0].text, equals('See '));
        expect(p.spans[1], isA<Anchor>());
        expect((p.spans[1] as Anchor).text, equals('Introduction'));
        expect((p.spans[1] as Anchor).link, equals('ch1.html#intro'));
        expect((p.spans[1] as Anchor).note, isNull);

        expect(p.spans[2].text, equals(' and key point before '));
        expect(p.spans[3], isA<Anchor>());
        expect((p.spans[3] as Anchor).text, equals('[1]'));
        expect((p.spans[3] as Anchor).link, equals('#fn-1'));
        expect((p.spans[3] as Anchor).note, equals('Resolved footnote text.'));
        expect(p.spans[4].text, equals('.'));
      },
    );

    test('resolves Duokan/Calibre aside & zy-footnote into Anchor.note', () {
      const html = '''
        <p>
            <span>
                <sup class="calibre16"><a epub:type="noteref" href="#footnote-4-193"> <img src="../images/image_000.png"
                            alt="Littera de le maravigliose battaglie apparse novamente in Bergamasca，引自Niccoli，Prophecy，S. 65f.。"
                            zy-footnote="Littera de le maravigliose battaglie apparse novamente in Bergamasca，引自Niccoli，Prophecy，S. 65f.。"
                            class="epub-footnote" /></a>
                </sup>
            </span>
        </p>

        <aside epub:type="footnote" id="footnote-4-276">
            <ol class="duokan-footnote-content">
                <li class="duokan-footnote-item">更多有关下述文字的源文献内容及德文译文参见Rückkehr der Götter一书的参考文献列表，引用内容见第11—13页。</li>
            </ol>
        </aside>

        <p class="calibre7">
            <span class="calibre10">当尤卡坦半岛的玛雅人1517年春第一次发现西班牙征服者们的身影：
                <sup class="calibre16"><a epub:type="noteref" href="#footnote-4-276">
                        <img src="../images/image_000.png" alt="更多有关下述文字..."
                            zy-footnote="更多有关下述文字..."
                            class="epub-footnote" /></a>
                </sup>
            </span>
        </p>
      ''';

      final chunks = ChunkParser.parseHtml(html);
      expect(chunks.length, equals(2));
      expect(chunks.whereType<Picture>(), isEmpty);

      final fn0 = chunks[0].spans[0] as Anchor;
      expect(fn0.note, contains('Littera de le maravigliose battaglie'));

      final c1 = chunks[1];
      expect(c1.spans.length, equals(2));
      expect(c1.spans[0].text, equals('当尤卡坦半岛的玛雅人1517年春第一次发现西班牙征服者们的身影：'));
      final fn1 = c1.spans[1] as Anchor;
      expect(fn1.note, contains('Rückkehr der Götter'));
    });

    test('pasfootnote', () {
      const html =
          '''<p><a class="ref" href="part02-01.xhtml#foot-1" id="back-1">1</a></p>
        <p xmlns:epub="http://www.idpf.org/2007/ops" class="footnote" epub:type="footnote" id="foot-1">
        <a href="part02-01.xhtml#back-1"><span class="no">1</span></a>
        《蔣經國日記》，一九六七年五月三日。</p>''';
      final chunks = ChunkParser.parseHtml(html);
      expect(chunks.length, equals(1));
      expect(chunks[0].spans.length, 1);
      expect(chunks[0].spans[0], isA<Anchor>());
      expect(
        (chunks[0].spans[0] as Anchor).note,
        contains('《蔣經國日記》，一九六七年五月三日'),
      );
      expect((chunks[0].spans[0] as Anchor).text, '1');
      expect((chunks[0].spans[0] as Anchor).link, 'part02-01.xhtml#foot-1');
      // TODO:
    });

    test(
      'parses non-footnote Image chunks with alt and optional dimensions',
      () {
        const html = '''
        <p>Illustration below:</p>
        <p><img src="../images/cover.png" alt="Cover Image" width="600" height="800px" /></p>
      ''';

        final chunks = ChunkParser.parseHtml(html);
        expect(chunks.length, equals(2));
        expect(chunks[1], isA<Picture>());
        final img = chunks[1] as Picture;
        expect(img.src, equals('../images/cover.png'));
        expect(img.alt, equals('Cover Image'));
        expect(img.w, equals(600.0));
        expect(img.h, equals(800.0));
      },
    );

    test('parses SVG image with xlink:href and dimensions', () {
      const html = '''
        <div id="cover-image">
          <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="100%" height="100%" viewBox="0 0 547 800" preserveAspectRatio="none">
              <image width="547" height="800" xlink:href="cover.jpeg"/>
          </svg>
        </div>
      ''';

      final chunks = ChunkParser.parseHtml(html);
      expect(chunks.length, equals(1));
      expect(chunks[0], isA<Picture>());
      final img = chunks[0] as Picture;
      expect(img.src, equals('cover.jpeg'));
      expect(img.w, equals(547.0));
      expect(img.h, equals(800.0));
    });

    test(
      'sets Chunk.strong for h1-h6 and strong tags, ignores other formatting',
      () {
        const html = '''
        <style>.x { color: red; }</style>
        <script>console.log("ignore");</script>
        <h1>Heading 1</h1>
        <strong>Standalone Strong</strong>
        <p><strong>Paragraph Strong</strong></p>
        <p><span class="a"><em>Italic</em></span> and <b>Bold</b> <u>Underline</u></p>
      ''';

        final chunks = ChunkParser.parseHtml(html);
        expect(chunks.length, equals(4));
        expect(chunks[0].strong, isTrue);
        expect(chunks[1].strong, isTrue);
        expect(chunks[2].strong, isTrue);
        expect(chunks[3].strong, isFalse);
        expect(chunks[3].text, equals('Italic and Bold Underline'));
      },
    );
  });

  group('Book and Chapter', () {
    test('parses EPUB bytes into Book and Chapter list', () {
      final archive = Archive();
      void add(String name, String content) {
        final bytes = utf8.encode(content);
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      add('META-INF/container.xml', '''
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
      ''');
      add('OEBPS/content.opf', '''
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Sample Book</dc:title>
            <dc:creator>Ada Lovelace</dc:creator>
          </metadata>
          <manifest>
            <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="ch1"/>
          </spine>
        </package>
      ''');
      add('OEBPS/ch1.xhtml', '''
        <html><body>
          <h1 id="top">Chapter One</h1>
          <p class="en">Hello world<a epub:type="noteref" href="#fn1">[1]</a></p>
          <aside epub:type="footnote" id="fn1">First note.</aside>
        </body></html>
      ''');

      final zipBytes = ZipEncoder().encode(archive)!;
      final book = ChunkParser.parseBytes(zipBytes);

      expect(book.title, equals('Sample Book'));
      expect(book.author, equals('Ada Lovelace'));
      expect(book.chapters.length, equals(1));

      final ch = book.chapters[0];
      expect(ch.title, equals('Chapter One'));
      expect(ch.chunks.length, equals(2));
      expect(ch.chunks[0].id, equals('top'));
      expect(ch.chunks[0].strong, isTrue);
      expect((ch.chunks[1].spans[1] as Anchor).note, equals('First note.'));
    });
  });

  group('MOBI, AZW, and AZW3', () {
    List<int> buildPdb({
      required String pdbName,
      required List<List<int>> records,
    }) {
      final headerLen = 78 + records.length * 8;
      final out = BytesBuilder();
      final nameBytes = utf8.encode(pdbName);
      final namePad = Uint8List(32);
      namePad.setRange(0, nameBytes.length.clamp(0, 32), nameBytes);
      out.add(namePad);
      out.add(Uint8List(28)); // attrs..modNum
      out.add(latin1.encode('BOOKMOBI'));
      out.add(Uint8List(8)); // uniqueIDSeed, nextRecordListID
      final numBuf = ByteData(2)..setUint16(0, records.length, Endian.big);
      out.add(numBuf.buffer.asUint8List());

      int offset = headerLen;
      for (int i = 0; i < records.length; i++) {
        final recEntry = ByteData(8)
          ..setUint32(0, offset, Endian.big)
          ..setUint32(4, i, Endian.big);
        out.add(recEntry.buffer.asUint8List());
        offset += records[i].length;
      }
      for (final r in records) {
        out.add(r);
      }
      return out.takeBytes();
    }

    Uint8List buildMobiRecord0({
      required int compression,
      required int textLen,
      required int textRecCount,
      int encryption = 0,
      int version = 6,
      int firstImage = 0xFFFFFFFF,
      int? fdstOffset,
      String? title,
      String? author,
      int? kf8Boundary,
    }) {
      final exthItems = <List<int>>[];
      void addExthString(int type, String val) {
        final b = utf8.encode(val);
        final item = BytesBuilder();
        item.add(
          (ByteData(4)..setUint32(0, type, Endian.big)).buffer.asUint8List(),
        );
        item.add(
          (ByteData(
            4,
          )..setUint32(0, 8 + b.length, Endian.big)).buffer.asUint8List(),
        );
        item.add(b);
        exthItems.add(item.takeBytes());
      }

      if (author != null) addExthString(100, author);
      if (title != null) addExthString(503, title);
      if (kf8Boundary != null) {
        final item = ByteData(12)
          ..setUint32(0, 121, Endian.big)
          ..setUint32(4, 12, Endian.big)
          ..setUint32(8, kf8Boundary, Endian.big);
        exthItems.add(item.buffer.asUint8List());
      }

      final mobiHeaderLen = 232;
      final exthBody = BytesBuilder();
      if (exthItems.isNotEmpty) {
        final bodyLen = exthItems.fold<int>(0, (s, e) => s + e.length);
        exthBody.add(latin1.encode('EXTH'));
        exthBody.add(
          (ByteData(
            4,
          )..setUint32(0, 12 + bodyLen, Endian.big)).buffer.asUint8List(),
        );
        exthBody.add(
          (ByteData(
            4,
          )..setUint32(0, exthItems.length, Endian.big)).buffer.asUint8List(),
        );
        for (final item in exthItems) {
          exthBody.add(item);
        }
      }

      final exthBytes = exthBody.takeBytes();
      final total = Uint8List(16 + mobiHeaderLen + exthBytes.length);
      final bd = ByteData.sublistView(total);

      bd.setUint16(0, compression, Endian.big);
      bd.setUint32(4, textLen, Endian.big);
      bd.setUint16(8, textRecCount, Endian.big);
      bd.setUint16(10, 4096, Endian.big);
      bd.setUint16(12, encryption, Endian.big);

      total.setRange(16, 20, latin1.encode('MOBI'));
      bd.setUint32(20, mobiHeaderLen, Endian.big);
      bd.setUint32(24, version >= 8 ? 248 : 2, Endian.big);
      bd.setUint32(28, 65001, Endian.big); // UTF-8
      bd.setUint32(36, version, Endian.big);
      bd.setUint32(108, firstImage, Endian.big);
      bd.setUint32(128, exthItems.isNotEmpty ? 0x40 : 0, Endian.big);
      if (fdstOffset != null) {
        bd.setUint32(192, fdstOffset, Endian.big);
      } else {
        bd.setUint32(192, 0xFFFFFFFF, Endian.big);
      }

      if (exthBytes.isNotEmpty) {
        total.setRange(16 + mobiHeaderLen, total.length, exthBytes);
      }
      return total;
    }

    test(
      'parses PalmDOC LZ77 compressed MOBI/AZW with EXTH metadata, chapters, and recindex images',
      () {
        const html =
            '<h1>Prologue</h1><p class="en">Hello WorldHello World</p>'
            '<mbp:pagebreak/>'
            '<h2>Chapter 2</h2><p class="zh">中文测试<a epub:type="noteref" href="#fn1">[1]</a></p>'
            '<p><img recindex="00001" alt="Map"/></p>'
            '<aside epub:type="footnote" id="fn1">Mobi note.</aside>';
        final raw = utf8.encode(html);

        // Encode with PalmDOC LZ77 space-char shortcuts & literal blocks
        final compressed = <int>[];
        int i = 0;
        while (i < raw.length) {
          if (raw[i] == 0x20 &&
              i + 1 < raw.length &&
              raw[i + 1] >= 0x40 &&
              raw[i + 1] <= 0x7F) {
            compressed.add(raw[i + 1] ^ 0x80);
            i += 2;
          } else if (raw[i] >= 9 && raw[i] <= 0x7F) {
            compressed.add(raw[i]);
            i++;
          } else {
            final chunk = <int>[];
            while (i < raw.length && raw[i] >= 0x80 && chunk.length < 8) {
              chunk.add(raw[i++]);
            }
            compressed.add(chunk.length);
            compressed.addAll(chunk);
          }
        }

        final rec0 = buildMobiRecord0(
          compression: 2, // PalmDOC LZ77
          textLen: raw.length,
          textRecCount: 1,
          firstImage: 2,
          title: 'Test Mobi Book',
          author: 'Jane Doe',
        );
        final fakePng = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

        final pdbBytes = buildPdb(
          pdbName: 'FallbackTitle',
          records: [rec0, compressed, fakePng],
        );

        expect(MobiParser.isMobiBytes(pdbBytes), isTrue);
        final book = ChunkParser.parseBytes(pdbBytes);
        expect(book.title, equals('Test Mobi Book'));
        expect(book.author, equals('Jane Doe'));
        expect(book.chapters.length, equals(2));

        expect(book.chapters[0].title, equals('Prologue'));
        expect(
          book.chapters[0].chunks[1].text,
          equals('Hello WorldHello World'),
        );
        expect(book.chapters[0].chunks[1].lang, equals(Lang.en));

        final ch2 = book.chapters[1];
        expect(ch2.title, equals('Chapter 2'));
        expect((ch2.chunks[1].spans[1] as Anchor).note, equals('Mobi note.'));
        final img = ch2.chunks[2] as Picture;
        expect(img.src, equals('mobi_image_00001.png'));
        expect(img.alt, equals('Map'));
      },
    );

    test('parses dual/KF8 AZW3 via BOUNDARY record and FDST Flow 0', () {
      const kf8Html =
          '<html><body><h1>AZW3 Heading</h1><p class="en">KF8 Content</p></body></html>';
      const kf8Css = 'body { color: black; }';
      final kf8Text = utf8.encode('$kf8Html$kf8Css');

      final fdst = Uint8List(20);
      final fbd = ByteData.sublistView(fdst);
      fdst.setRange(0, 4, latin1.encode('FDST'));
      fbd.setUint32(4, 12, Endian.big);
      fbd.setUint32(8, 1, Endian.big);
      fbd.setUint32(12, 0, Endian.big);
      fbd.setUint32(16, utf8.encode(kf8Html).length, Endian.big);

      final mobi6Rec0 = buildMobiRecord0(
        compression: 1,
        textLen: 5,
        textRecCount: 1,
        kf8Boundary: 2,
      );
      final kf8Rec0 = buildMobiRecord0(
        compression: 1,
        textLen: kf8Text.length,
        textRecCount: 1,
        version: 8,
        fdstOffset: 2,
        title: 'AZW3 Title',
        author: 'KF8 Author',
      );

      final azw3Bytes = buildPdb(
        pdbName: 'Combo',
        records: [
          mobi6Rec0,
          utf8.encode('old6 '),
          latin1.encode('BOUNDARY'),
          kf8Rec0,
          kf8Text,
          fdst,
        ],
      );

      final book = MobiParser.parseBytes(azw3Bytes);
      expect(book.title, equals('AZW3 Title'));
      expect(book.author, equals('KF8 Author'));
      expect(book.chapters.length, equals(1));
      expect(book.chapters[0].title, equals('AZW3 Heading'));
      expect(book.chapters[0].chunks.length, equals(2));
      expect(book.chapters[0].chunks[1].text, equals('KF8 Content'));
    });

    test('throws FormatException for DRM-encrypted MOBI/AZW', () {
      final rec0 = buildMobiRecord0(
        compression: 1,
        textLen: 10,
        textRecCount: 1,
        encryption: 2,
      );
      final pdb = buildPdb(
        pdbName: 'Locked',
        records: [rec0, utf8.encode('0123456789')],
      );
      expect(() => MobiParser.parseBytes(pdb), throwsFormatException);
    });
  });
}

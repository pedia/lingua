import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../lib/chunk/chunk.dart';
import '../lib/chunk/sample.dart';
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

    test('parses language tags via Lang.from', () {
      expect(Lang.from('en'), equals(Lang.en));
      expect(Lang.from('en-US'), equals(Lang.en));
      expect(Lang.from('zh-TW'), equals(Lang.zh));
      expect(Lang.from('ja-JP'), equals(Lang.jp));
      expect(Lang.from('ko-KR'), equals(Lang.kr));
      expect(Lang.from('es'), equals(Lang.es));
      expect(Lang.from('all'), equals(Lang.all));
      expect(Lang.from('entry'), equals(Lang.unknown));
      expect(Lang.from(null), equals(Lang.unknown));
    });
  });

  group('Chunk, Span, Anchor, and Picture', () {
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

    test('splits mixed inline content into Span and Anchor while ignoring HTML formatting', () {
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
    });

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

    test('parses non-footnote Picture chunks with alt and optional dimensions', () {
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
    });

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

    test('sets Chunk.strong for h1-h6 and strong tags, ignores other formatting', () {
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
    });

    test('parses Kobo/InDesign EPUB3 XHTML with self-closing script, koboSpans, spacer, and endnotes', () {
      const html = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="zh-TW" xml:lang="zh-TW">
  <head>
    <meta charset="UTF-8"/>
    <title>第二章　取消文化的認識論面向</title>
    <link href="css/2023.4.h.css" rel="stylesheet" type="text/css"/>
    <script xmlns="http://www.w3.org/1999/xhtml" type="text/javascript" src="../js/kobo.js"/>
    <style xmlns="http://www.w3.org/1999/xhtml" type="text/css" id="koboSpanStyle">.koboSpan { -webkit-text-combine: inherit; }</style>
  </head>
  <body id="BK7131-6">
    <div>
      <h1 id="_idParaDest-11" class="ff_serif"><span class="koboSpan" id="kobo.1.1">第二章　取消文化的認識論面向</span></h1>
      <p class="ff_serif"><span class="koboSpan" id="kobo.2.1">Erkenntnistheoretische Aspekte der Cancel Culture</span></p>
      <h2 id="_idParaDest-12" class="ff_sans"><span class="fz_0-8em"><span class="koboSpan" id="kobo.3.1">伽利略的案例</span></span></h2>
      <p class="ff_serif"><span class="koboSpan" id="kobo.4.1">在中世紀，他們先是借鑒了柏拉圖</span><span class="va_super"><span><a id="footnote-042-backlink" class="_idFootnoteLink" role="doc-noteref" epub:type="noteref" href="BK7131-6.xhtml#footnote-042"><span class="koboSpan" id="kobo.5.1">19</span></a></span></span><span class="koboSpan" id="kobo.6.1">的思想。伽利略（Galileo Galilei）在一九七</span><span lang="ja-JP" xml:lang="ja-JP"><span class="koboSpan" id="kobo.7.1">〇</span></span><span class="koboSpan" id="kobo.8.1">年代提出科學方法的反思。</span></p>
      <p class="ff_serif fz_0-6em ti_2em mg-aft_0-0em">　</p>
      <p class="ff_cursive"><span class="fw_900"><span class="koboSpan" id="kobo.9.1">本質</span></span><span class="koboSpan" id="kobo.10.1">（e</span><span class="fs_italic"><span class="koboSpan" id="kobo.11.1">ssence</span></span><span class="koboSpan" id="kobo.12.1">）</span></p>
      <hr class="HorizontalRule-1"/>
      <section class="_idFootnotes" role="doc-endnotes" epub:type="endnotes">
        <ol>
          <li id="footnote-042" class="_idFootnote">
            <p class="ta_left"><a class="_idFootnoteAnchor" role="doc-backlink" href="BK7131-6.xhtml#footnote-042-backlink"><span class="koboSpan" id="kobo.20.1">19</span></a><span class="koboSpan" id="kobo.21.1">：Augustinus : Vom Gottesstaat. </span><span class="koboSpan" id="kobo.21.2">München : dtv 2007.</span></p>
          </li>
        </ol>
      </section>
    </div>
  </body>
</html>''';

      expect(
        HtmlChunkParser.extractChapterTitle(html, 'fallback'),
        equals('第二章 取消文化的認識論面向'),
      );

      final chunks = ChunkParser.parseHtml(html);
      expect(chunks.length, equals(5));

      expect(chunks[0].id, equals('_idParaDest-11'));
      expect(chunks[0].strong, isTrue);
      expect(chunks[0].lang, equals(Lang.zh));
      expect(chunks[0].text, equals('第二章 取消文化的認識論面向'));

      expect(chunks[1].strong, isFalse);
      expect(chunks[1].lang, equals(Lang.en));
      expect(chunks[1].text, equals('Erkenntnistheoretische Aspekte der Cancel Culture'));

      expect(chunks[2].id, equals('_idParaDest-12'));
      expect(chunks[2].strong, isTrue);
      expect(chunks[2].lang, equals(Lang.zh));
      expect(chunks[2].text, equals('伽利略的案例'));

      expect(chunks[3].lang, equals(Lang.zh));
      expect(chunks[3].idx, equals(3));
      expect(chunks[3].spans.length, equals(3));
      expect(chunks[3].spans[0].text, equals('在中世紀，他們先是借鑒了柏拉圖'));
      final anchor = chunks[3].spans[1] as Anchor;
      expect(anchor.text, equals('19'));
      expect(anchor.link, equals('BK7131-6.xhtml#footnote-042'));
      expect(anchor.note, equals('Augustinus : Vom Gottesstaat. München : dtv 2007.'));
      expect(chunks[3].spans[2].text, equals('的思想。伽利略（Galileo Galilei）在一九七〇年代提出科學方法的反思。'));
      expect(
        chunks[3].speak,
        equals('在中世紀，他們先是借鑒了柏拉圖的思想。伽利略（Galileo Galilei）在一九七〇年代提出科學方法的反思。'),
      );

      expect(chunks[4].idx, equals(4));
      expect(chunks[4].lang, equals(Lang.zh));
      expect(chunks[4].text, equals('本質（essence）'));
      expect(chunks[4].speak, equals('本質（essence）'));
    });

    test('supports Chunk.idx default, copyWith, and speakable text', () {
      final base = Chunk(text: 'Hello', lang: Lang.en);
      expect(base.idx, equals(0));
      expect(base.speak, equals('Hello'));

      final copied = base.copyWith(idx: 7, strong: true);
      expect(copied.idx, equals(7));
      expect(copied.text, equals('Hello'));
      expect(copied.lang, equals(Lang.en));
      expect(copied.strong, isTrue);

      final mixed = Chunk(
        idx: 2,
        lang: Lang.en,
        spans: [
          Span('See '),
          Anchor('Chapter 2', link: 'ch2.xhtml'),
          Anchor('[1]', note: 'Footnote body'),
          Span(' for details.'),
        ],
      );
      expect(mixed.speak, equals('See Chapter 2 for details.'));

      final pic = Picture('cover.png', alt: 'Cover');
      expect(pic.idx, equals(0));
      expect(pic.speak, isEmpty);
      expect(pic.copyWith(idx: 3).idx, equals(3));
    });

    test('updates Picture.w and Picture.h via updateSize() from image headers and viewport bounds', () {
      // Minimal 800x600 PNG header
      final png = Uint8List(24)
        ..setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..setAll(12, ascii.encode('IHDR'));
      ByteData.sublistView(png)
        ..setUint32(16, 800, Endian.big)
        ..setUint32(20, 600, Endian.big);

      final pngPic = Picture('a.png', bytes: () => png);
      expect(pngPic.w, isNull);
      expect(pngPic.h, isNull);
      expect(pngPic.updateSize(maxWidth: 400), isTrue);
      expect(pngPic.w, equals(400.0));
      expect(pngPic.h, equals(300.0));

      // Minimal 1000x500 JPEG SOF0 header with explicit HTML w=200 (missing h)
      final jpg = Uint8List.fromList([
        0xFF, 0xD8,
        0xFF, 0xC0, 0x00, 0x0B, 0x08,
        0x01, 0xF4, // height = 500
        0x03, 0xE8, // width = 1000
        0x03, 0x01, 0x11, 0x00,
        0xFF, 0xD9,
      ]);
      final jpgPic = Picture('b.jpg', w: 200, bytes: () => jpg);
      expect(jpgPic.updateSize(), isTrue);
      expect(jpgPic.w, equals(200.0));
      expect(jpgPic.h, equals(100.0));

      // Minimal 320x240 GIF89a header + maxHeight constraint
      final gif = Uint8List(10)..setAll(0, ascii.encode('GIF89a'));
      ByteData.sublistView(gif)
        ..setUint16(6, 320, Endian.little)
        ..setUint16(8, 240, Endian.little);
      final gifPic = Picture('c.gif', bytes: () => gif);
      expect(gifPic.updateSize(maxHeight: 120), isTrue);
      expect(gifPic.w, equals(160.0));
      expect(gifPic.h, equals(120.0));

      // Minimal 640x480 WebP VP8L header
      final webp = Uint8List(25)
        ..setAll(0, ascii.encode('RIFF'))
        ..setAll(8, ascii.encode('WEBPVP8L'))
        ..[20] = 0x2F;
      ByteData.sublistView(webp)
        ..setUint32(21, (640 - 1) | ((480 - 1) << 14), Endian.little);
      final webpPic = Picture('d.webp', bytes: () => webp);
      expect(webpPic.updateSize(), isTrue);
      expect(webpPic.w, equals(640.0));
      expect(webpPic.h, equals(480.0));

      // SVG header with viewBox + explicit override
      final svgPic = Picture(
        'e.svg',
        bytes: () => Uint8List.fromList(utf8.encode('<svg viewBox="0 0 500 250"></svg>')),
      );
      expect(svgPic.updateSize(), isTrue);
      expect(svgPic.w, equals(500.0));
      expect(svgPic.h, equals(250.0));

      expect(svgPic.updateSize(w: 120, h: 90), isTrue);
      expect(svgPic.w, equals(120.0));
      expect(svgPic.h, equals(90.0));
    });
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
            <dc:language>en-US</dc:language>
            <dc:description>A sample EPUB book description.</dc:description>
            <meta name="cover" content="img2"/>
          </metadata>
          <manifest>
            <item id="ch1" href="Text/ch1.xhtml" media-type="application/xhtml+xml"/>
            <item id="img1" href="images/pic.png" media-type="image/png"/>
            <item id="img2" href="images/my%20cover.png" media-type="image/png"/>
          </manifest>
          <spine>
            <itemref idref="ch1"/>
          </spine>
        </package>
      ''');
      final pngBytes = [0x89, 0x50, 0x4E, 0x47, 0x01, 0x02];
      final coverBytes = [0x89, 0x50, 0x4E, 0x47, 0x03, 0x04];
      archive.addFile(ArchiveFile('OEBPS/images/pic.png', pngBytes.length, pngBytes));
      archive.addFile(ArchiveFile('OEBPS/images/my cover.png', coverBytes.length, coverBytes));
      add('OEBPS/Text/ch1.xhtml', '''
        <html><body>
          <h1 id="top">Chapter One</h1>
          <p class="en">Hello world<a epub:type="noteref" href="#fn1">[1]</a></p>
          <p><img src="../images/pic.png" alt="Pic"/></p>
          <p><img src="../images/my%20cover.png?v=1#top" alt="Cover"/></p>
          <aside epub:type="footnote" id="fn1">First note.</aside>
        </body></html>
      ''');

      final zipBytes = ZipEncoder().encode(archive)!;
      final book = ChunkParser.parseBytes(zipBytes);

      expect(book.title, equals('Sample Book'));
      expect(book.author, equals('Ada Lovelace'));
      expect(book.lang, equals('en-US'));
      expect(book.description, equals('A sample EPUB book description.'));
      expect(book.cover(), equals(coverBytes));
      expect(book.chapters.length, equals(1));

      final ch = book.chapters[0];
      expect(ch.title, equals('Chapter One'));
      expect(ch.chunks.length, equals(4));
      expect(ch.chunks[0].id, equals('top'));
      expect(ch.chunks[0].strong, isTrue);
      expect((ch.chunks[1].spans[1] as Anchor).note, equals('First note.'));

      final img = ch.chunks[2] as Picture;
      expect(img.src, equals('../images/pic.png'));
      expect(img.bytes(), equals(pngBytes));

      final img2 = ch.chunks[3] as Picture;
      expect(img2.bytes(), equals(coverBytes));
    });

    test('resolves EPUB 3 cover-image property and guide XHTML cover page', () {
      final archive = Archive();
      void add(String name, String content) {
        final bytes = utf8.encode(content);
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      final coverBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10];
      archive.addFile(ArchiveFile('cover.jpeg', coverBytes.length, coverBytes));
      add('META-INF/container.xml', '''
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
      ''');
      add('content.opf', '''
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>EPUB3 Cover</dc:title>
            <dc:language>zh-CN</dc:language>
          </metadata>
          <manifest>
            <item id="cimg" href="cover.jpeg" media-type="image/jpeg" properties="cover-image"/>
            <item id="p1" href="p1.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine><itemref idref="p1"/></spine>
        </package>
      ''');
      add('p1.xhtml', '<html><body><p>Body</p></body></html>');

      final epub3Book = EpubParser.parseBytes(ZipEncoder().encode(archive)!);
      expect(epub3Book.lang, equals('zh-CN'));
      expect(epub3Book.cover(), equals(coverBytes));

      // Now verify fallback via <guide><reference type="cover" href="cover.xhtml"/>
      final archive2 = Archive();
      void add2(String name, String content) {
        final bytes = utf8.encode(content);
        archive2.addFile(ArchiveFile(name, bytes.length, bytes));
      }
      archive2.addFile(ArchiveFile('OEBPS/Images/cover.jpeg', coverBytes.length, coverBytes));
      add2('META-INF/container.xml', '''
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
      ''');
      add2('OEBPS/content.opf', '''
        <package xmlns="http://www.idpf.org/2007/opf" version="2.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Guide Cover</dc:title>
          </metadata>
          <manifest>
            <item id="coverpage" href="Text/cover.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine><itemref idref="coverpage"/></spine>
          <guide>
            <reference type="cover" title="Cover" href="Text/cover.xhtml"/>
          </guide>
        </package>
      ''');
      add2('OEBPS/Text/cover.xhtml', '''
        <html><body>
          <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 547 800">
            <image width="547" height="800" xlink:href="../Images/cover.jpeg"/>
          </svg>
        </body></html>
      ''');

      final guideBook = EpubParser.parseBytes(ZipEncoder().encode(archive2)!);
      expect(guideBook.cover(), equals(coverBytes));
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
      int locale = 0,
      int firstImage = 0xFFFFFFFF,
      int? fdstOffset,
      String? title,
      String? author,
      String? lang,
      String? description,
      int? coverOffset,
      int? kf8Boundary,
    }) {
      final exthItems = <List<int>>[];
      void addExthString(int type, String val) {
        final b = utf8.encode(val);
        final item = BytesBuilder();
        item.add((ByteData(4)..setUint32(0, type, Endian.big)).buffer.asUint8List());
        item.add((ByteData(4)..setUint32(0, 8 + b.length, Endian.big)).buffer.asUint8List());
        item.add(b);
        exthItems.add(item.takeBytes());
      }

      void addExthUint32(int type, int val) {
        final item = ByteData(12)
          ..setUint32(0, type, Endian.big)
          ..setUint32(4, 12, Endian.big)
          ..setUint32(8, val, Endian.big);
        exthItems.add(item.buffer.asUint8List());
      }

      if (author != null) addExthString(100, author);
      if (description != null) addExthString(103, description);
      if (kf8Boundary != null) addExthUint32(121, kf8Boundary);
      if (coverOffset != null) addExthUint32(201, coverOffset);
      if (title != null) addExthString(503, title);
      if (lang != null) addExthString(524, lang);

      final mobiHeaderLen = 232;
      final exthBody = BytesBuilder();
      if (exthItems.isNotEmpty) {
        final bodyLen = exthItems.fold<int>(0, (s, e) => s + e.length);
        exthBody.add(latin1.encode('EXTH'));
        exthBody.add((ByteData(4)..setUint32(0, 12 + bodyLen, Endian.big)).buffer.asUint8List());
        exthBody.add((ByteData(4)..setUint32(0, exthItems.length, Endian.big)).buffer.asUint8List());
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
      bd.setUint32(92, locale, Endian.big);
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

    test('parses PalmDOC LZ77 compressed MOBI/AZW with EXTH metadata, chapters, and recindex images', () {
      const html = '<h1>Prologue</h1><p class="en">Hello WorldHello World</p>'
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
        lang: 'en-US',
        description: 'A PalmDOC test description.',
        coverOffset: 0,
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
      expect(book.lang, equals('en-US'));
      expect(book.description, equals('A PalmDOC test description.'));
      expect(book.cover(), equals(fakePng));
      expect(book.chapters.length, equals(2));

      expect(book.chapters[0].title, equals('Prologue'));
      expect(book.chapters[0].chunks[1].text, equals('Hello WorldHello World'));
      expect(book.chapters[0].chunks[1].lang, equals(Lang.en));

      final ch2 = book.chapters[1];
      expect(ch2.title, equals('Chapter 2'));
      expect((ch2.chunks[1].spans[1] as Anchor).note, equals('Mobi note.'));
      final img = ch2.chunks[2] as Picture;
      expect(img.src, equals('mobi_image_00001.png'));
      expect(img.alt, equals('Map'));
      expect(img.bytes(), equals(fakePng));
    });

    test('parses dual/KF8 AZW3 via BOUNDARY record and FDST Flow 0', () {
      const kf8Html = '<html><body><h1>AZW3 Heading</h1><p class="en">KF8 Content</p></body></html>';
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
        locale: 0x0409,
        fdstOffset: 2,
        title: 'AZW3 Title',
        author: 'KF8 Author',
        description: 'KF8 summary',
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
      expect(book.lang, equals('en'));
      expect(book.description, equals('KF8 summary'));
      expect(book.cover(), isNull);
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
      final pdb = buildPdb(pdbName: 'Locked', records: [rec0, utf8.encode('0123456789')]);
      expect(() => MobiParser.parseBytes(pdb), throwsFormatException);
    });
  });

  group('Sample Book', () {
    test('provides organized sample book with format, footnote, and picture chapters', () {
      final book = sampleBook;
      expect(book.title, equals('Chunk Sample Book'));
      expect(book.cover(), isNotNull);
      expect(book.chapters.length, equals(3));

      // Chapter 1: Formats & Languages
      final ch1 = book.chapters[0];
      expect(ch1.title, equals('Chapter 1: Formats and Languages'));
      final c1 = ch1.chunks;
      expect(c1.whereType<Picture>(), isEmpty);
      expect(c1.any((c) => c.strong && c.id == 'ch1-top'), isTrue);
      expect(c1.any((c) => c.text == 'Split word spans and chars merge seamlessly.'), isTrue);
      expect(c1.any((c) => c.lang == Lang.zh && (c.text ?? '').contains('Galileo Galilei')), isTrue);
      expect(c1.any((c) => c.lang == Lang.es), isTrue);
      expect(c1.any((c) => c.lang == Lang.jp), isTrue);
      expect(c1.any((c) => c.lang == Lang.kr), isTrue);
      expect(c1.every((c) => (c.text ?? c.spans.map((s) => s.text).join()).trim().isNotEmpty), isTrue);

      // Chapter 2: Footnotes & Endnotes
      final ch2 = book.chapters[1];
      expect(ch2.title, equals('Chapter 2: Footnotes and Endnotes'));
      expect(ch2.chunks.whereType<Picture>(), isEmpty);
      final notes = ch2.chunks
          .expand((c) => c.spans)
          .whereType<Anchor>()
          .where((a) => a.note != null)
          .toList();
      expect(notes.length, equals(5));
      expect(notes[0].note, equals('EPUB 3 aside footnote content.'));
      expect(notes[1].note, equals('Duokan nested ordered-list footnote content.'));
      expect(notes[2].note, equals('Inline zy-footnote attribute note.'));
      expect(notes[3].note, contains('exceeding forty characters'));
      expect(notes[4].note, equals('InDesign / Kobo endnote content with backlink stripped.'));
      expect(
        ch2.chunks.last.speak,
        equals('InDesign / Kobo endnote reference in running text.'),
      );

      // Chapter 3: Pictures
      final ch3 = book.chapters[2];
      expect(ch3.title, equals('Chapter 3: Pictures and Media'));
      final pics = ch3.chunks.whereType<Picture>().toList();
      expect(pics.length, equals(7));
      expect(pics[0].id, equals('pic-standard'));
      expect(pics[0].w, equals(640.0));
      expect(pics[0].h, equals(480.0));
      expect(pics[0].bytes(), isNotNull);
      expect(pics[1].w, isNull); // percentage width
      expect(pics[1].bytes(), isNotNull);
      expect(pics[2].bytes(), isNotNull); // URL-encoded with query/fragment
      expect(pics[3].src, startsWith('data:image/png;base64,'));
      expect(pics[3].bytes(), equals(book.cover()));
      expect(pics[4].w, equals(800.0)); // SVG viewBox + image
      expect(pics[4].h, equals(600.0));
      expect(pics[4].bytes(), isNotNull);
      expect(pics[5].src, equals('mobi_image_00001.png')); // recindex
      expect(pics[5].bytes(), isNotNull);
      expect(pics[6].id, equals('pic-inline'));
      expect(pics[6].speak, isEmpty);
    });

    test('builds Book.index map and supports normalized multi-script search', () {
      final book = sampleBook;
      final index = book.index;

      // Direct normalized keyword lookup in Book.index
      final galileoRefs = index['galileo'];
      expect(galileoRefs, isNotNull);
      expect(galileoRefs!.length, equals(1));
      expect(galileoRefs.first.chapter, equals(0));
      final galileoChunk =
          book.chapters[galileoRefs.first.chapter].chunks[galileoRefs.first.chunk];
      expect(galileoChunk.text, contains('Galileo Galilei'));

      // Case-insensitive & full-width normalization
      expect(book.search('GALILEO'), equals(galileoRefs));
      expect(book.search('Ｇａｌｉｌｅｏ'), equals(galileoRefs));

      // Multi-keyword intersection vs exactPhrase
      final splitMergeHits = book.search('split merge');
      expect(splitMergeHits.length, equals(1));
      expect(
        book.chapters[splitMergeHits.first.chapter].chunks[splitMergeHits.first.chunk].text,
        equals('Split word spans and chars merge seamlessly.'),
      );
      expect(book.search('split merge', exactPhrase: true), isEmpty);
      expect(book.search('split word spans', exactPhrase: true), equals(splitMergeHits));

      // Cross-chapter hits for shared keyword
      final footnoteRefs = index['footnote'];
      expect(footnoteRefs, isNotNull);
      expect(footnoteRefs!.map((r) => r.chapter).toSet(), equals({1}));
      expect(footnoteRefs.length, equals(3));

      // Multi-script & CJK bigram queries
      final zhHits = book.search('繁體中文');
      expect(zhHits.length, equals(2));
      expect(zhHits.every((r) => r.chapter == 0), isTrue);
      expect(book.search('español').length, equals(1));
      expect(book.search('한국어').length, equals(2));
      expect(book.search('한글').length, equals(1));
      expect(book.search('ひらがな').length, equals(1));

      // Missing term returns empty list
      expect(book.search('nonexistentkeywordxyz'), isEmpty);
      expect(book.search('   '), isEmpty);
    });
  });
}

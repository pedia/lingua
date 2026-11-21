/// Well-organized sample [Book] demonstrating all formats, footnotes, and pictures.
library chunk.sample;

import 'dart:convert';
import 'dart:typed_data';

import 'chunk.dart';

/// A valid 1×1 PNG image used for sample covers and image assets.
const String _samplePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

final Uint8List _samplePngBytes = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, // PNG Signature
  0, 0, 0, 13, 73, 72, 68, 82, // IHDR Header
  0, 0, 0, 8, 0, 0, 0, 8, // Width (8px), Height (8px)
  8, 2, 0, 0, 0, // 8-bit, TrueColor RGB, No Filter
  75, 109, 41, 220, // Validated IHDR CRC
  0, 0, 0, 20, 73, 68, 65, 84, // IDAT Header (20 bytes of data)
  120, 156, 99, 100, 96, 248, 207, 128, // Compressed image pixel payload
  13, 48, 97, 21, 29, 180, 18, 0,
  203, 67, 1, 15,
  86, 36, 140, 186, // Validated IDAT CRC
  0, 0, 0, 0, 73, 69, 78, 68, // IEND End of Image
  174, 66, 96, 130, // Validated IEND CRC
]);
// Uint8List.fromList(
//   base64Decode(_samplePngBase64),
// );

/// Prebuilt sample [Book] containing three organized chapters:
/// 1. All supported text formats, spans, headings, and languages
/// 2. All supported footnote & endnote conventions
/// 3. All supported [Picture] formats (HTML, SVG, data URI, MOBI recindex)
Book get sampleBook => buildSampleBook();

/// Creates a fresh sample [Book] instance with lazy chapters.
Book buildSampleBook() {
  final globalFootnotes = HtmlChunkParser.extractFootnotes(_chapter2Html);

  Uint8List? resolveSampleAsset(String src) {
    final clean = src.split('?').first.split('#').first;
    final decoded = Uri.decodeComponent(clean);
    if (decoded.endsWith('.png') ||
        decoded.endsWith('.jpg') ||
        decoded.endsWith('.jpeg') ||
        decoded.endsWith('.webp')) {
      return Uint8List.fromList(_samplePngBytes);
    }
    return null;
  }

  String resolveSampleRecindex(String recindex) {
    final idx = int.tryParse(recindex.trim()) ?? 1;
    return 'mobi_image_${idx.toString().padLeft(5, '0')}.png';
  }

  return Book(
    title: 'Chunk Sample Book',
    author: 'Chunk Authors',
    lang: 'mul',
    description:
        'Organized sample book showcasing text formats, languages, footnotes, and pictures.',
    cover: () => Uint8List.fromList(_samplePngBytes),
    chapters: [
      LazyChapter(
        'Coded',
        () => [Chunk(text: 'single text'), Chunk(text: 'text')],
      ),
      LazyChapter(
        HtmlChunkParser.extractChapterTitle('', 'Empty'),
        () => HtmlChunkParser.parseHtml('', footnotes: globalFootnotes),
      ),
      LazyChapter(
        HtmlChunkParser.extractChapterTitle(_chapter1Html, 'Formats'),
        () => HtmlChunkParser.parseHtml(
          _chapter1Html,
          footnotes: globalFootnotes,
        ),
      ),
      LazyChapter(
        HtmlChunkParser.extractChapterTitle(_chapter2Html, 'Footnotes'),
        () => HtmlChunkParser.parseHtml(
          _chapter2Html,
          footnotes: globalFootnotes,
        ),
      ),
      LazyChapter(
        HtmlChunkParser.extractChapterTitle(_chapter3Html, 'Pictures'),
        () => HtmlChunkParser.parseHtml(
          _chapter3Html,
          footnotes: globalFootnotes,
          resolveRecindex: resolveSampleRecindex,
          resolveImageBytes: resolveSampleAsset,
        ),
      ),
    ],
  );
}

// ============================================================================
// Chapter 1: All Kinds of Formats, Spans, Blocks, and Languages
// ============================================================================

const String _chapter1Html = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
  <head>
    <meta charset="UTF-8"/>
    <title>Chapter 1: Formats and Languages</title>
    <script type="text/javascript" src="../js/reader.js"/>
    <style type="text/css">.muted { color: #666; }</style>
  </head>
  <body>
    <h1 id="ch1-top">Chapter 1: Formats and Languages</h1>
    <h2 id="ch1-inline">Inline Formatting &amp; Whitespace</h2>

    <p>Paragraph with <em>italic</em>, <b>bold</b>, <u>underline</u>, line<br/>break, and <a href="ch2.html#fn-intro">hyperlink</a>.</p>
    <p><strong>Full paragraph wrapped in strong tag.</strong></p>
    <strong>Standalone strong block.</strong>

    <p><span class="fw_900"><span class="koboSpan">Split</span></span> <span class="koboSpan">wo</span><span class="fs_italic"><span class="koboSpan">rd</span></span> spans and <span data-wr-id="layout">char</span><span data-wr-id="layout">s</span> merge seamlessly.</p>
    <p>　</p>

    <blockquote>Blockquote sample with <strong>key phrase</strong> preserved inline.</blockquote>

    <ul>
      <li><h3 id="toc-1"><a href="#ch1-lang">Language Detection Section</a></h3></li>
      <li>Plain list item chunk.</li>
    </ul>

    <h2 id="ch1-lang">Explicit Class &amp; Auto Script Detection</h2>
    <p class="en">Explicit English class attribute.</p>
    <p class="zh">明確標記繁體中文類別屬性。</p>
    <p class="es">¡Hola mundo español!</p>
    <p class="jp">明示的な日本語クラス属性です。</p>
    <p class="kr">명시적 한국어 클래스 속성입니다.</p>

    <p>Auto-detected English paragraph without lang attribute.</p>
    <p>自動偵測繁體中文與外來詞（Galileo Galilei）以及一九七<span lang="ja-JP"><span class="koboSpan">〇</span></span>年代的混合寫法。</p>
    <p>ひらがなと漢字を含む日本語の自動判定。</p>
    <p>한글 음절을 포함한 한국어 자동 감지.</p>
  </body>
</html>''';

// ============================================================================
// Chapter 2: All Kinds of Footnotes & Endnotes
// ============================================================================

const String _chapter2Html = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="en" xml:lang="en">
  <head>
    <meta charset="UTF-8"/>
    <title>Chapter 2: Footnotes and Endnotes</title>
  </head>
  <body>
    <h1 id="ch2-top">Chapter 2: Footnotes and Endnotes</h1>

    <p>Standard EPUB 3 aside footnote reference<a epub:type="noteref" href="#fn-epub3">[1]</a> inside body prose.</p>
    <p>Duokan nested list footnote reference<a epub:type="noteref" href="#fn-duokan">[2]</a> and a <a href="https://example.org/ref">normal external link</a>.</p>
    <p>Calibre/ZhangYue attribute footnote:<sup><a epub:type="noteref" href="#fn-zy"><img src="../images/note_icon.png" alt="Footnote icon" zy-footnote="Inline zy-footnote attribute note." class="epub-footnote"/></a></sup> and icon alt fallback:<sup><a epub:type="noteref" href="#fn-alt"><img src="../images/note_icon.png" alt="Long inline footnote text stored directly inside image alt attribute exceeding forty characters." class="epub-footnote"/></a></sup>.</p>
    <p>InDesign / Kobo endnote reference<span class="va_super"><a id="fn-indesign-1-backlink" class="_idFootnoteLink" role="doc-noteref" epub:type="noteref" href="ch2.xhtml#fn-indesign-1"><span class="koboSpan">19</span></a></span> in running text.</p>

    <aside epub:type="footnote" id="fn-epub3">EPUB 3 aside footnote content.</aside>

    <aside epub:type="footnote" id="fn-duokan">
      <ol class="duokan-footnote-content">
        <li class="duokan-footnote-item">Duokan nested ordered-list footnote content.</li>
      </ol>
    </aside>

    <hr class="HorizontalRule-1"/>
    <section class="_idFootnotes" role="doc-endnotes" epub:type="endnotes">
      <ol>
        <li id="fn-indesign-1" class="_idFootnote">
          <p><a class="_idFootnoteAnchor" role="doc-backlink" href="ch2.xhtml#fn-indesign-1-backlink"><span class="koboSpan">19</span></a><span class="koboSpan">：InDesign / Kobo endnote content with backlink stripped.</span></p>
        </li>
      </ol>
    </section>
  </body>
</html>''';

// ============================================================================
// Chapter 3: All Kinds of Pictures
// ============================================================================

const String _chapter3Html =
    '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:xlink="http://www.w3.org/1999/xlink" lang="en" xml:lang="en">
  <head>
    <meta charset="UTF-8"/>
    <title>Chapter 3: Pictures and Media</title>
  </head>
  <body>
    <h1 id="ch3-top">Chapter 3: Pictures and Media</h1>

    <p><img id="pic-standard" src="../images/diagram.png" alt="Standard Raster Picture" width="640" height="480px"/></p>
    <p><img id="pic-percent" src="images/responsive.jpg" alt="Percentage Width Picture" width="100%"/></p>
    <p><img id="pic-encoded" src="../images/my%20photo.png?v=1#top" alt="URL-Encoded Path Picture"/></p>
    <p><img id="pic-data-uri" src="data:image/png;base64,$_samplePngBase64" alt="Inline Base64 Data URI Picture" width="1" height="1"/></p>

    <div id="pic-svg-wrap">
      <svg id="pic-svg" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100%" height="100%" viewBox="0 0 800 600">
        <image width="800" height="600" xlink:href="../images/vector_page.png"/>
      </svg>
    </div>

    <p><img id="pic-recindex" recindex="00001" alt="MOBI Record Index Picture"/></p>
    <p>Paragraph with caption and embedded image: <img id="pic-inline" src="../images/inline_fig.png" alt="Inline Paragraph Picture"/></p>
  </body>
</html>''';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:lingua/epub/epub.dart';

List<Chunk> extract(String html) {
  return HtmlExtractor('').extract(html_parser.parse(html).body!);
}

void main() {
  group('HtmlExtractor', () {
    test('extracts a plain paragraph', () {
      final chunks = extract('<p>Hello world.</p>');
      expect(chunks, hasLength(1));
      final block = chunks.single as TextBlock;
      expect(block.lang, '');
      expect(block.headingLevel, isNull);
      expect(block.inlines, hasLength(1));
      final span = block.inlines.single as InlineText;
      expect(span.text, 'Hello world.');
    });

    test('drops empty text and empty paragraphs', () {
      expect(extract('<p></p>'), isEmpty);
      expect(extract('   \n  '), isEmpty);
    });

    test('collapses whitespace in bare text', () {
      final chunks = extract('<div>  hello\n\n   world \t ! </div>');
      final block = chunks.single as TextBlock;
      expect((block.inlines.single as InlineText).text, 'hello world !');
    });

    test('inherits lang from ancestor elements', () {
      final chunks = extract('<div lang="en"><div><p>hi</p></div></div>');
      expect((chunks.single as TextBlock).lang, 'en');
    });

    test('prefers xml:lang over lang', () {
      final chunks = extract('<p xml:lang="zh" lang="en">hi</p>');
      expect((chunks.single as TextBlock).lang, 'zh');
    });

    test('extracts headings h1-h6 with levels', () {
      for (var i = 1; i <= 6; i++) {
        final chunks = extract('<h$i>Level $i</h$i>');
        final block = chunks.single as TextBlock;
        expect(block.headingLevel, i, reason: 'for h$i');
        expect(block.inlines.single is InlineText, isTrue);
      }
    });

    test('falls through default elements and walks children', () {
      final chunks = extract(
        '<div><section><span><p>deep</p></span></section></div>',
      );
      expect(chunks, hasLength(1));
      expect((chunks.single as TextBlock).inlines.single is InlineText, isTrue);
    });

    group('inline styles', () {
      test('bold', () {
        final chunks = extract('<p><strong>bold</strong> <b>also</b></p>');
        final spans = (chunks.single as TextBlock).inlines.cast<InlineText>();
        expect(spans, hasLength(3));
        expect(spans[0].bold, isTrue);
        expect(spans[1].bold, isFalse);
        expect(spans[2].bold, isTrue);
      });

      test('italic', () {
        final chunks = extract('<p><em>it</em> <i>also</i></p>');
        final spans = (chunks.single as TextBlock).inlines.cast<InlineText>();
        expect(spans[0].italic, isTrue);
        expect(spans[1].italic, isFalse);
        expect(spans[2].italic, isTrue);
      });

      test('underline', () {
        final chunks = extract('<p>a<u>u</u></p>');
        final spans = (chunks.single as TextBlock).inlines.cast<InlineText>();
        expect(spans[1].underline, isTrue);
      });

      test('superscript and subscript', () {
        final chunks = extract('<p>x<sup>2</sup>y<sub>3</sub></p>');
        final spans = (chunks.single as TextBlock).inlines.cast<InlineText>();
        expect(spans[1].superscript, isTrue);
        expect(spans[1].subscript, isFalse);
        expect(spans[3].subscript, isTrue);
      });

      test('nested styles propagate to children', () {
        final chunks = extract('<p><em><strong>both</strong></em></p>');
        final span = (chunks.single as TextBlock).inlines.single as InlineText;
        expect(span.bold, isTrue);
        expect(span.italic, isTrue);
      });

      test('br inside paragraph produces newline span', () {
        final chunks = extract('<p>a<br/>b</p>');
        final spans = (chunks.single as TextBlock).inlines.cast<InlineText>();
        expect(spans, hasLength(3));
        expect(spans[1].text, '\n');
      });

      test('standalone br becomes its own text block', () {
        final bare = extract('<span>top<br/>and</span>');
        expect(bare, hasLength(3));
        final newline = bare[1] as TextBlock;
        expect((newline.inlines.single as InlineText).text, '\n');
      });
    });

    group('images', () {
      test('block image keeps src, alt and id', () {
        final chunks = extract('<img src="cover.jpg" alt="Cover" id="c1" />');
        final img = chunks.single as BlockImage;
        expect(img.src, 'cover.jpg');
        expect(img.alt, 'Cover');
        expect(img.id, 'c1');
      });

      test('block image with no src is dropped', () {
        expect(extract('<img alt="no src"/>'), isEmpty);
      });

      test('image element reads xlink:href', () {
        final chunks = extract(
          '<image width="450" xlink:href="cover.jpeg"></image>',
        );
        final img = chunks.single as BlockImage;
        expect(img.src, 'cover.jpeg');
      });

      test('inline image inside paragraph', () {
        final chunks = extract(
          '<p>before <img src="a.jpg" alt="a"/> after</p>',
        );
        final inlines = (chunks.single as TextBlock).inlines;
        expect(inlines, hasLength(3));
        final inline = inlines[1] as InlineImage;
        expect(inline.src, 'a.jpg');
        expect(inline.alt, 'a');
      });

      test('figure containing image is walked through', () {
        final chunks = extract(
          '<figure><img alt=" " id="Dust" src="images/Dust.jpg"/></figure>',
        );
        final img = chunks.single as BlockImage;
        expect(img.src, 'images/dust.jpg'); // lowercase
        expect(img.alt, ' ');
        expect(img.id, 'Dust');
      });

      test('svg children are walked through', () {
        final chunks = extract('<svg><p>inside svg</p></svg>');
        expect(chunks, hasLength(1));
        expect(
          (chunks.single as TextBlock).inlines.single is InlineText,
          isTrue,
        );
      });
    });

    group('lists', () {
      test('unordered list', () {
        final chunks = extract('<ul><li>one</li><li>two</li></ul>');
        final list = chunks.single as BlockList;
        expect(list.ordered, isFalse);
        expect(list.items, hasLength(2));
        expect(list.items[1].content.single is TextBlock, isTrue);
      });

      test('ordered list', () {
        final chunks = extract('<ol><li>first</li></ol>');
        final list = chunks.single as BlockList;
        expect(list.ordered, isTrue);
      });

      test('nested lists', () {
        final chunks = extract('<ul><li>a<ul><li>b</li></ul></li></ul>');
        final list = chunks.single as BlockList;
        final inner = list.items.single.content;
        expect(inner, hasLength(2));
        expect(inner[0] is TextBlock, isTrue);
        final nested = inner[1] as BlockList;
        expect(nested.items.single.content.single is TextBlock, isTrue);
      });

      test('non-li children are ignored', () {
        final chunks = extract('<ul><p>skip</p><li>keep</li></ul>');
        final list = chunks.single as BlockList;
        expect(list.items, hasLength(1));
      });
    });

    group('tables', () {
      test('simple table with header row', () {
        final chunks = extract(
          '<table><thead><tr><th>name</th><th>age</th></tr></thead>'
          '<tbody><tr><td>Ada</td><td>36</td></tr></tbody></table>',
        );
        final table = chunks.single as Table;
        expect(table.rows, hasLength(2));
        final headerRow = table.rows[0];
        expect(headerRow.isHeader, isTrue);
        expect(headerRow.cells, hasLength(2));
        expect(headerRow.cells[0].content.single is TextBlock, isTrue);
        expect(headerRow.cells[0].colspan, 1);
        expect(table.rows[1].isHeader, isFalse);
      });

      test('detects header rows via th', () {
        final chunks = extract(
          '<table><tr><th>h</th></tr><tr><td>d</td></tr></table>',
        );
        final table = chunks.single as Table;
        expect(table.rows[0].isHeader, isTrue);
        expect(table.rows[1].isHeader, isFalse);
      });

      test('colspan and rowspan', () {
        final chunks = extract(
          '<table><tr><td colspan="2" rowspan="3">x</td><td>y</td></tr></table>',
        );
        final cell = (chunks.single as Table).rows.single.cells.first;
        expect(cell.colspan, 2);
        expect(cell.rowspan, 3);
      });

      test('invalid colspan falls back to 1', () {
        final chunks = extract(
          '<table><tr><td colspan="abc">x</td></tr></table>',
        );
        final cell = (chunks.single as Table).rows.single.cells.single;
        expect(cell.colspan, 1);
      });
    });

    group('links and anchors', () {
      test('hyperlink with href and epub:type', () {
        final chunks = extract(
          '<p><a href="ch2.html" epub:type="noteref">note</a></p>',
        );
        final link = (chunks.single as TextBlock).inlines.single as Hyperlink;
        expect(link.href, 'ch2.html');
        expect(link.epubType, 'noteref');
        expect(link.children.single is InlineText, isTrue);
      });

      test('anchor with id keeps text', () {
        final chunks = extract('<p><a id="sec1">section</a></p>');
        final inlines = (chunks.single as TextBlock).inlines;
        expect(inlines, hasLength(2));
        expect(inlines[0] is Anchor, isTrue);
        expect((inlines[0] as Anchor).id, 'sec1');
        expect((inlines[1] as InlineText).text, 'section');
      });

      test('anchor recognized via name attribute', () {
        final chunks = extract('<p><a name="top">t</a></p>');
        expect((chunks.single as TextBlock).inlines.first is Anchor, isTrue);
      });

      test('anchor with nothing just outputs children', () {
        final chunks = extract('<p><a>plain</a></p>');
        expect(
          (chunks.single as TextBlock).inlines.single is InlineText,
          isTrue,
        );
      });
    });

    group('math', () {
      test('math block captures outer html', () {
        final chunks = extract(
          '<p>x</p><math><mfrac><mn>1</mn><mn>2</mn></mfrac></math>',
        );
        final math = chunks[1] as MathBlock;
        expect(math.display, isTrue);
        expect(math.content, contains('mfrac'));
      });

      test('mjx-container is treated as math', () {
        final chunks = extract('<mjx-container>E=mc^2</mjx-container>');
        expect(chunks.single is MathBlock, isTrue);
      });
    });

    group('ignorable elements', () {
      test('script style title head are dropped', () {
        for (final tag in [
          'script',
          'style',
          'title',
          'noscript',
          'template',
        ]) {
          final chunks = extract(
            '<div><$tag>hidden</$tag><p>visible</p></div>',
          );
          expect(chunks, hasLength(1), reason: 'for $tag');
        }
      });
    });

    test('text at top level becomes a text block', () {
      final chunks = extract('<div>Trailing standalone text here.</div>');
      expect(chunks.single is TextBlock, isTrue);
    });

    test('unknown element walks into children producing chunks', () {
      final chunks = extract(
        '<article><h2>t</h2><img src="i.jpg"/>tail</article>',
      );
      expect(chunks, hasLength(3));
      expect(chunks[0] is TextBlock, isTrue);
      expect(chunks[1] is BlockImage, isTrue);
      expect(chunks[2] is TextBlock, isTrue);
    });

    group('toString', () {
      test('text block', () {
        expect(
          TextBlock([InlineText('hi')]).toString(),
          '[hi]',
        );
        expect(
          TextBlock([InlineText('hi')], headingLevel: 2).toString(),
          '[hi]',
        );
      });

      test('text span styles', () {
        expect(InlineText('x').toString(), 'x');
        expect(
          InlineText('x', bold: true, italic: true).toString(),
          '*_x_*',
        );
      });

      test('images links lists tables', () {
        expect(BlockImage('a.jpg', alt: 'b').toString(), 'BlockImage("a.jpg")');
        expect(Hyperlink('c.html').toString(), 'Hyperlink(c.html)');
        expect(
          BlockList([ListItem([])]).toString(),
          'ListBlock(ordered: false, items: 1)',
        );
        expect(Table([TableRow([])]).toString(), 'Table(rows: 1)');
      });
    });

    test('full document integration', () {
      final chunks = extract('''
        <div>
          <h1 lang="en">Title</h1>
          <p>Intro <strong>bold</strong> and <a href="#n">link</a>.</p>
          <img src="cover.jpg" alt="Cover" />
          <ul><li>one</li><li>two</li></ul>
          <table><tr><th>key</th><td>value</td></tr></table>
          <p class="TX">And of <i>course</i> he hadn’t thought to warn Navani.</p>
        </div>
      ''');
      expect(chunks, hasLength(6));
      expect((chunks[0] as TextBlock).headingLevel, 1);
      expect(chunks[1] is TextBlock, isTrue);
      expect(chunks[2] is BlockImage, isTrue);
      expect(chunks[3] is BlockList, isTrue);
      expect(chunks[4] is Table, isTrue);
      expect(chunks[5].toString(), '[And of _course_ he hadn’t thought to warn Navani.]');
    });
  });
}

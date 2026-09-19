import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../epub/epub.dart' as epub;

class DemoFrame extends StatefulWidget {
  const DemoFrame({super.key});

  @override
  State<DemoFrame> createState() => _DemoFrameState();
}

class _DemoFrameState extends State<DemoFrame> {
  Widget render(BuildContext context, List<epub.Chunk> chunks) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: ListView(
        children: chunks
            .map(
              (c) => RichText(
                text: TextSpan(children: [buildChunkSpan(c, context)]),
              ),
            )
            .toList(),
      ),
    );
  }

  InlineSpan buildChunkSpan(epub.Chunk chunk, BuildContext context) {
    return switch (chunk) {
      // 1. TextBlock behaves as a block element by injecting structural spacing
      epub.TextBlock b => WidgetSpan(
        child: Container(
          width: double.infinity, // Forces it to take up a block layout width
          padding: const EdgeInsets.symmetric(
            vertical: 6.0,
          ), // Paragraph block spacing
          child: RichText(
            text: TextSpan(
              style: _getHeadingStyle(b.headingLevel, context),
              children: b.inlines
                  .map((i) => buildInlineSpan(i, context))
                  .toList(),
            ),
          ),
        ),
      ),

      epub.BlockImage b => WidgetSpan(
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Image.memory(
            lab,
            semanticLabel: b.alt,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
          ),
        ),
      ),

      epub.BlockList b => WidgetSpan(
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 4.0, bottom: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(b.items.length, (index) {
              final prefix = b.ordered ? '${index + 1}. ' : '• ·';
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prefix, style: Theme.of(context).textTheme.bodyMedium),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: b.items[index].content
                            .map((c) => buildChunkSpan(c, context))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),

      epub.Table t => WidgetSpan(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            children: t.rows.map((row) {
              return TableRow(
                decoration: BoxDecoration(
                  color: row.isHeader ? Colors.grey.shade100 : null,
                ),
                children: row.cells.map((cell) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: RichText(
                      text: TextSpan(
                        children: cell.content
                            .map((c) => buildChunkSpan(c, context))
                            .toList(),
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),

      epub.MathBlock b => WidgetSpan(
        child: Container(
          width: double.infinity,
          alignment: b.display ? Alignment.center : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            b.content,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      ),

      epub.UnknownBlock b => WidgetSpan(
        child: Text(
          '[Unknown tag: ${b.tag}]',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    };
  }

  /// Transforms an [Inline] element into an [InlineSpan].
  InlineSpan buildInlineSpan(epub.Inline inline, BuildContext context) {
    return switch (inline) {
      epub.InlineText i => TextSpan(
        text: i.text,
        style: TextStyle(
          fontWeight: i.bold ? FontWeight.bold : null,
          fontStyle: i.italic ? FontStyle.italic : null,
          decoration: i.underline ? TextDecoration.underline : null,
          // Handle superscript and subscript using fontFeatures
          fontFeatures: [
            if (i.superscript) const FontFeature.superscripts(),
            if (i.subscript) const FontFeature.subscripts(),
          ],
        ),
      ),

      epub.InlineImage i => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Image.memory(
          lab,
          width: 20, // Inline image constraints
          height: 20,
          semanticLabel: i.alt,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),

      epub.Hyperlink h => TextSpan(
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
        // Simple tap handler setup
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            debugPrint('Navigating to: \${h.href}');
          },
        children: h.children
            .map((child) => buildInlineSpan(child, context))
            .toList(),
      ),

      epub.Anchor a => WidgetSpan(
        // Invisible target placeholder for deep-linking/scrolling targets
        child: SizedBox.shrink(key: ValueKey(a.id)),
      ),

      epub.MathInline m => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        // Substitute with your math rendering package (e.g., flutter_math_fork)
        child: Text(
          m.content,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      ),
    };
  }

  /// Helper method to style headings based on the headingLevel (1-6)
  TextStyle? _getHeadingStyle(int? level, BuildContext context) {
    if (level == null) return Theme.of(context).textTheme.bodyMedium;

    final typography = Theme.of(context).textTheme;
    return switch (level) {
      1 => typography.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
      2 => typography.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
      3 => typography.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      4 => typography.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      5 => typography.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      6 => typography.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      _ => typography.bodyMedium,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: render(context, [
        epub.TextBlock.single('Single line'),
        epub.TextBlock([
          epub.InlineText('Rich support '),
          epub.InlineText('italic', italic: true),
          epub.InlineText(' '),
          epub.InlineText('strong', bold: true),
          epub.InlineText(' in single line. And links: '),

          epub.Hyperlink(
            'https://flutter.dev',
            children: [epub.InlineText('Flutter Link')],
          ),
          epub.InlineText(' E=M·C'),
          epub.InlineText('2', superscript: true),
          epub.InlineText('3 ', subscript: true),
          epub.InlineImage(''),
        ]),
        // epub.BlockImage('src'),
        epub.BlockList([
          epub.ListItem([epub.TextBlock.single('Male')]),
          epub.ListItem([epub.TextBlock.single('Animal')]),
          epub.ListItem([epub.TextBlock.single('Boy')]),
        ]),
        epub.BlockImage('src'),
      ]),
    );
  }
}

final lab = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, // PNG Signature (8 bytes)
  0, 0, 0, 13, 73, 72, 68, 82, // IHDR chunk length & type (8 bytes)
  0, 0, 0, 1, 0, 0, 0, 1, // Width: 1, Height: 1 (8 bytes)
  1,0,0,0,0, // Bit depth (1), color type, compression, filter, interlace (5 bytes)
  55, 110, 242, 5, // IHDR CRC (4 bytes)
  0, 0, 0, 10, 73, 68, 65, 84, // IDAT chunk length & type (8 bytes)
  8, 215, 99, 96, 0, 0, 0, 2, 0, 1, // Compressed image data (10 bytes)
  226, 33, 188, 51, // IDAT CRC (4 bytes)
  0, 0, 0, 0, 73, 69, 78, 68, // IEND chunk length & type (8 bytes)
  174, 66, 96, 130, // IEND CRC (4 bytes)
]);

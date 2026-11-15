import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'chunk.dart';

// ---------------------------------------------------------
// 1. Off-Screen Pagination Calculator
// ---------------------------------------------------------
class ChunkPaginator {
  static Future<List<List<Chunk>>> paginate({
    required List<Chunk> chunks,
    required double maxWidth,
    required double maxHeight,
    required TextStyle textStyle,
    required BuildContext context,
    double paragraphSpacing = 12.0,
    double imageSpacing = 16.0,
  }) async {
    // Step A: Pre-resolve unknown image dimensions
    await _resolveAllImageDimensions(chunks, context);

    final List<List<Chunk>> pages = [];
    List<Chunk> currentPage = [];
    double remainingHeight = maxHeight;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
    );

    for (final chunk in chunks) {
      if (chunk is Picture) {
        final aspectRatio = (chunk.w != null && chunk.h != null && chunk.h! > 0)
            ? chunk.w! / chunk.h!
            : 16 / 9;
        final renderedHeight = (maxWidth / aspectRatio) + imageSpacing;

        // If image doesn't fit on current page, push to next page
        if (renderedHeight > remainingHeight && currentPage.isNotEmpty) {
          pages.add(currentPage);
          currentPage = [];
          remainingHeight = maxHeight;
        }

        currentPage.add(chunk);
        remainingHeight -= renderedHeight;
      } else {
        // Measure and split text chunks across page boundaries if needed
        String remainingText = chunk.text ?? '';

        while (remainingText.isNotEmpty) {
          textPainter.text = TextSpan(text: remainingText, style: textStyle);
          textPainter.layout(maxWidth: maxWidth);

          final totalHeight = textPainter.height + paragraphSpacing;

          if (totalHeight <= remainingHeight) {
            // Entire text fits on the current page
            currentPage.add(Chunk(text: remainingText, id: chunk.id));
            remainingHeight -= totalHeight;
            break;
          } else {
            // Find exact character index where text overflows remainingHeight
            final position = textPainter.getPositionForOffset(
              Offset(maxWidth, remainingHeight - paragraphSpacing),
            );
            int splitIndex = position.offset;

            // Avoid splitting mid-word if possible
            if (splitIndex > 0) {
              final lastSpace = remainingText.lastIndexOf(' ', splitIndex);
              if (lastSpace > 0) splitIndex = lastSpace;
            }

            if (splitIndex <= 0) {
              // Not even a single line fits -> start a fresh page
              if (currentPage.isNotEmpty) {
                pages.add(currentPage);
                currentPage = [];
                remainingHeight = maxHeight;
                continue;
              } else {
                // Force at least one character to prevent infinite loop
                splitIndex = 1;
              }
            }

            final pageSlice = remainingText
                .substring(0, splitIndex)
                .trimRight();
            if (pageSlice.isNotEmpty) {
              currentPage.add(Chunk(text: pageSlice, id: chunk.id));
            }

            pages.add(currentPage);
            currentPage = [];
            remainingHeight = maxHeight;
            remainingText = remainingText.substring(splitIndex).trimLeft();
          }
        }
      }
    }

    if (currentPage.isNotEmpty) {
      pages.add(currentPage);
    }

    return pages;
  }

  static Future<void> _resolveAllImageDimensions(
    List<Chunk> chunks,
    BuildContext context,
  ) async {
    final futures = <Future<void>>[];

    for (final chunk in chunks) {
      if (chunk is Picture && (chunk.w == null || chunk.h == null)) {
        final completer = Completer<void>();
        final stream = NetworkImage(
          chunk.src,
        ).resolve(createLocalImageConfiguration(context));

        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (ImageInfo info, bool _) {
            chunk.w = info.image.width.toDouble();
            chunk.h = info.image.height.toDouble();
            stream.removeListener(listener);
            completer.complete();
          },
          onError: (dynamic _, StackTrace? _) {
            chunk.w = 16;
            chunk.h = 9; // Fallback aspect ratio on error
            stream.removeListener(listener);
            completer.complete();
          },
        );
        stream.addListener(listener);
        futures.add(completer.future);
      }
    }

    await Future.wait(futures);
  }
}

// ---------------------------------------------------------
// 2. Single-Page Reader Screen
// ---------------------------------------------------------
class PaginatedChunkReader extends StatefulWidget {
  const PaginatedChunkReader({super.key, required this.chunks});
  final List<Chunk> chunks;

  @override
  State<PaginatedChunkReader> createState() => _PaginatedChunkReaderState();
}

class _PaginatedChunkReaderState extends State<PaginatedChunkReader> {
  List<List<Chunk>>? _pages;
  int _currentPage = 0;

  final TextStyle _bodyStyle = const TextStyle(
    fontSize: 16.0,
    color: Colors.black87,
    height: 1.5,
  );

  bool _isCalculating = false;

  Future<void> _calculatePages(BoxConstraints constraints) async {
    if (_isCalculating || _pages != null) return;
    _isCalculating = true;

    const horizontalPadding = 32.0; // 16 left + 16 right
    const verticalPadding = 32.0; // 16 top + 16 bottom

    final calculated = await ChunkPaginator.paginate(
      chunks: widget.chunks,
      maxWidth: constraints.maxWidth - horizontalPadding,
      maxHeight: constraints.maxHeight - verticalPadding,
      textStyle: _bodyStyle,
      context: context,
    );

    if (mounted) {
      setState(() {
        _pages = calculated;
        _isCalculating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pages == null
              ? 'Calculating Pages...'
              : 'Page ${_currentPage + 1} of ${_pages!.length}',
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_pages == null) {
            // Trigger calculation once viewport dimensions are known
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _calculatePages(constraints);
            });
            return const Center(child: CircularProgressIndicator());
          }

          final pageChunks = _pages![_currentPage];

          // SelectionArea enables cross-chunk selection on the active page
          return SelectionArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: pageChunks.map((chunk) {
                  if (chunk is Picture) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: AspectRatio(
                        aspectRatio: chunk.w! / chunk.h!,
                        child: Image.network(chunk.src, fit: BoxFit.cover),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: RichText(
                      text: TextSpan(
                        style: _bodyStyle,
                        children: [
                          TextSpan(text: chunk.text),
                          TextSpan(
                            text: ' [Note]',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Tapped chunk ${chunk.id}'),
                                  ),
                                );
                              },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: (_pages != null && _currentPage > 0)
                    ? () => setState(() => _currentPage--)
                    : null,
                child: const Text('Previous'),
              ),
              ElevatedButton(
                onPressed: (_pages != null && _currentPage < _pages!.length - 1)
                    ? () => setState(() => _currentPage++)
                    : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

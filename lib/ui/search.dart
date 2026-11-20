import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chunk/chunk.dart';
import '../g.dart';
import '../ui/book.dart';

class SearchService {
  int big = 0;
  bool _isCancelled = false;
  Completer<void>? _loopDoneCompleter;

  /// Requests cancellation and waits until the active loop has exited.
  Future<void> cancelAndWait() async {
    _isCancelled = true;
    final pending = _loopDoneCompleter?.future;
    if (pending != null) {
      await pending;
    }
  }

  // Async generator that searches and yields results one by one
  Stream<Result> searchStream(String query, Book book) {
    _isCancelled = true;
    debugPrint('enter $big');
    big += 1;

    late StreamController<Result> controller;

    controller = StreamController<Result>(
      onListen: () async {
        // Wait for any previous loop to exit before starting this one.
        final priorDone = _loopDoneCompleter?.future;
        if (priorDone != null) {
          await priorDone;
        }
        if (controller.isClosed) return;

        _isCancelled = false;
        final completer = Completer<void>();
        _loopDoneCompleter = completer;

        try {
          final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
          final radiusWords = 6;
          int cc = 0;
          for (int chi = 0; chi < book.chapters.length; chi++) {
            final ch = book.chapters[chi];
            for (int i = 0; i < ch.chunks.length; i++) {
              if (_isCancelled || controller.isClosed) {
                debugPrint('canceled $big');
                return;
              }

              final c = ch.chunks[i];
              if (c is Picture) {
                continue;
              }

              final text = c.text!;

              for (final match in pattern.allMatches(c.text!)) {
                final winStart = _expandLeftByWords(
                  text,
                  match.start,
                  radiusWords,
                );
                final winEnd = _expandRightByWords(
                  text,
                  match.end,
                  radiusWords,
                );

                final prefix = winStart > 0 ? '... ' : '';
                final suffix = winEnd < text.length ? ' ...' : '';
                final snippet =
                    '$prefix${text.substring(winStart, winEnd)}$suffix';

                debugPrint(
                  '<$cc {$query} $snippet ${match.start} ${match.end}',
                );
                // final ss = [
                // snippet.substring(0 + prefix.length, match.start + prefix.length),
                // '[red]',
                // snippet.substring(
                //   match.start + prefix.length,
                //   match.end + prefix.length,
                // ),
                // '[/red]',
                // snippet.substring(match.end + prefix.length),
                // ];
                // clog(ss.join(''));
                cc += 1;
                if (!controller.isClosed) {
                  controller.add(
                    Result(
                      chapterIndex: chi,
                      chunkIndex: i,
                      start: match.start,
                      end: match.end,
                      snippet: snippet,
                    ),
                  );
                }
              }
            }
          }
        } finally {
          if (!completer.isCompleted) {
            completer.complete();
          }
          if (identical(_loopDoneCompleter, completer)) {
            _loopDoneCompleter = null;
          }
          if (!controller.isClosed) {
            await controller.close();
          }
        }
      },
      onCancel: () {
        debugPrint('got cancel $big');
        _isCancelled = true;
      },
    );
    return controller.stream;
  }
}

class Result {
  Result({
    required this.chapterIndex,
    required this.chunkIndex,
    required this.start,
    required this.end,
    required this.snippet,
  });
  final int chapterIndex;
  final int chunkIndex;
  final int start;
  final int end;
  final String snippet;
}

bool _isBoundaryChar(int codeUnit) {
  // ASCII whitespace, fullwidth space (U+3000), and CJK ideographic space
  if (codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D ||
      codeUnit == 0x3000) {
    return true;
  }

  // CJK Symbols and Punctuation (U+3000..U+303F) and
  // Halfwidth and Fullwidth Forms punctuation (U+FF01..U+FF0F, U+FF1A..U+FF20, etc.)
  if ((codeUnit >= 0x3001 && codeUnit <= 0x303F) ||
      (codeUnit >= 0xFF01 && codeUnit <= 0xFF0F) ||
      (codeUnit >= 0xFF1A && codeUnit <= 0xFF20) ||
      (codeUnit >= 0xFF3B && codeUnit <= 0xFF40) ||
      (codeUnit >= 0xFF5B && codeUnit <= 0xFF65)) {
    return true;
  }

  // Common ASCII and typographic punctuation
  final ch = String.fromCharCode(codeUnit);
  return const {
    '.', ',', '!', '?', ';', ':', '"', "'", '(', ')', '[', ']', '{', '}', //
    '—', '–', '-', '…', '“', '”', '‘', '’',
  }.contains(ch);
}

int _expandLeftByWords(String text, int index, int wordCount) {
  int pos = max(0, min(index, text.length));
  int wordsFound = 0;

  // Move left past trailing spaces/punctuation at match start
  while (pos > 0 && _isBoundaryChar(text.codeUnitAt(pos - 1))) {
    pos--;
  }

  while (pos > 0 && wordsFound < wordCount) {
    while (pos > 0 && !_isBoundaryChar(text.codeUnitAt(pos - 1))) {
      pos--;
    }
    wordsFound++;
    if (wordsFound < wordCount) {
      while (pos > 0 && _isBoundaryChar(text.codeUnitAt(pos - 1))) {
        pos--;
      }
    }
  }
  return pos;
}

int _expandRightByWords(String text, int index, int wordCount) {
  int pos = max(0, min(index, text.length));
  int wordsFound = 0;

  // Move right past trailing characters of the matched term itself
  while (pos < text.length && !_isBoundaryChar(text.codeUnitAt(pos))) {
    pos++;
  }

  while (pos < text.length && wordsFound < wordCount) {
    while (pos < text.length && _isBoundaryChar(text.codeUnitAt(pos))) {
      pos++;
    }
    if (pos >= text.length) break;
    while (pos < text.length && !_isBoundaryChar(text.codeUnitAt(pos))) {
      pos++;
    }
    wordsFound++;
  }
  return pos;
}

class SearchFrame extends ConsumerStatefulWidget {
  const SearchFrame({
    required this.id,
    required this.book,
    this.cache,
    super.key,
  });
  final int id;
  final Book book;
  final CacheResult? cache;

  @override
  ConsumerState<SearchFrame> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchFrame> {
  final _input = TextEditingController();
  final SearchService _searchService = SearchService();
  final List<Result> _searchResults = [];
  StreamSubscription<Result>? _subscription;
  bool _isSearching = false;

  /// search via input change
  bool _alive = false;

  @override
  void initState() {
    if (widget.cache != null) {
      setState(() {
        _input.text = widget.cache!.query;
        _searchResults.addAll(widget.cache!.results);
      });
    }
    super.initState();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _input.dispose();

    box.put('search-history', _recentQueries);
    super.dispose();
  }

  void _search(String q, {bool recordHistory = false}) async {
    _subscription?.cancel();
    await _searchService.cancelAndWait();

    q = q.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    if (recordHistory) {
      _recordRecentQuery(q);
    }
    setState(() {
      _searchResults.clear();
      _isSearching = true;
    });

    _subscription = _searchService
        .searchStream(q, widget.book)
        .listen(
          (result) {
            setState(() => _searchResults.add(result));
          },
          onDone: () {
            setState(() => _isSearching = false);
          },
          onError: (error) {
            setState(() => _isSearching = false);
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // The result argument contains the pop result that is defined in `_PageTwo`.
      onPopInvokedWithResult: (bool didPop, result) async {
        if (didPop) {
          return;
        }
        Navigator.pop(context, CacheResult(_input.text, _searchResults));
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Search')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: CupertinoSearchTextField(
                    controller: _input,
                    placeholder: 'Input...',
                    style: TextStyle(fontFamily: '.osdefault'),
                    onChanged: _alive ? (query) => _search(query) : null,
                    onSubmitted: (query) {
                      debugPrint('submit $query');
                      _search(query, recordHistory: true);
                    },
                    onSuffixTap: () async {
                      _subscription?.cancel();
                      await _searchService.cancelAndWait();
                      setState(() {
                        _searchResults.clear();
                        _isSearching = false;
                        _input.clear();
                      });
                    },
                  ),
                ),
                CupertinoSwitch(
                  value: _alive,
                  onChanged: (value) => setState(() => _alive = value),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            if (!_isSearching) _buildRecentQueriesPanel(),
            if (_isSearching) const LinearProgressIndicator(),
            if (_searchResults.isNotEmpty)
              Text(' Found ${_searchResults.length}'),
            Expanded(
              child: _searchResults.isEmpty
                  ? const Center(
                      child: Text(
                        'No results found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final e = _searchResults[index];
                        return ListTile(
                          title: Text(e.snippet), // TODO: make query highlight
                          subtitle: Text(
                            widget.book.chapters[e.chapterIndex].title,
                          ),
                          onTap: () {
                            // jump to chapter
                            ref
                                .read(isp(widget.id).notifier)
                                .update(readChapterIndex: e.chapterIndex);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  final List<String> _recentQueries = box.get('search-history') ?? [];
  static const int _maxRecentQueries = 8;

  void _recordRecentQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _recentQueries.removeWhere(
        (q) => q.toLowerCase() == trimmed.toLowerCase(),
      );
      _recentQueries.insert(0, trimmed);
      if (_recentQueries.length > _maxRecentQueries) {
        _recentQueries.removeLast();
      }
    });
  }

  void _removeRecentQuery(String query) {
    setState(() {
      _recentQueries.remove(query);
    });
  }

  void _clearRecentQueries() {
    setState(() {
      _recentQueries.clear();
    });
  }

  void _selectRecentQuery(String query) {
    _input.text = query;
    _input.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _search(query, recordHistory: true);
  }

  Widget _buildRecentQueriesPanel() {
    if (_recentQueries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent searches',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: _clearRecentQueries,
                child: const Text('Clear'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _recentQueries.map((item) {
              return InputChip(
                label: Text(item),
                onPressed: () => _selectRecentQuery(item),
                onDeleted: () => _removeRecentQuery(item),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class CacheResult {
  CacheResult(this.query, this.results);
  final String query;
  final List<Result> results;

  Future<CacheResult?> show(BuildContext context, int id, Book book) {
    return Navigator.push<CacheResult?>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchFrame(id: id, book: book, cache: this),
      ),
    );
  }
}

const Map<String, String> _ansiColors = {
  'black': '\x1B[30m',
  'red': '\x1B[31m',
  'green': '\x1B[32m',
  'yellow': '\x1B[33m',
  'blue': '\x1B[34m',
  'magenta': '\x1B[35m',
  'cyan': '\x1B[36m',
  'white': '\x1B[37m',
  'brightRed': '\x1B[91m',
  'brightGreen': '\x1B[92m',
  'brightYellow': '\x1B[93m',
  'brightBlue': '\x1B[94m',
};

const String _ansiReset = '\x1B[0m';

/// Converts markup like `xx[red]xx[/red]` into ANSI escape sequences.
String colorizeAnsi(String input) {
  final tagPattern = RegExp(r'\[([a-zA-Z]+)\](.*?)\[/\1\]', dotAll: true);

  return input.replaceAllMapped(tagPattern, (match) {
    final colorName = match.group(1)!;
    final content = match.group(2)!;
    final ansiCode = _ansiColors[colorName];

    if (ansiCode == null) return match.group(0)!;
    return '$ansiCode$content$_ansiReset';
  });
}

void clog(String message) {
  debugPrint(colorizeAnsi(message));
}

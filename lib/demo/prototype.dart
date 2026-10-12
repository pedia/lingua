import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookProgress {
  final String bookId;
  final int currentChapter;
  final int currentLine;

  const BookProgress({
    required this.bookId,
    this.currentChapter = 0,
    this.currentLine = 0,
  });

  BookProgress copyWith({int? currentChapter, int? currentLine}) {
    return BookProgress(
      bookId: bookId,
      currentChapter: currentChapter ?? this.currentChapter,
      currentLine: currentLine ?? this.currentLine,
    );
  }
}

class BookProgressNotifier
    extends AutoDisposeFamilyAsyncNotifier<BookProgress, String> {
  @override
  Future<BookProgress> build(String bookId) async {
    // 1. Fetch saved progress asynchronously from DB / SharedPreferences / API
    return await _loadBookProgressFromStorage(bookId);
  }

  // Update Chapter
  Future<void> updateChapter(int chapterIndex) async {
    final currentState = state.value;
    if (currentState == null) return;

    final updated = currentState.copyWith(
      currentChapter: chapterIndex,
      currentLine: 0,
    );
    state = AsyncData(updated);

    // Save asynchronously to DB/Storage
    await _saveProgressToStorage(updated);
  }

  // Update Reading Line
  Future<void> updateLine(int lineIndex) async {
    final currentState = state.value;
    if (currentState == null) return;

    final updated = currentState.copyWith(currentLine: lineIndex);
    state = AsyncData(updated);

    // Save asynchronously to DB/Storage
    await _saveProgressToStorage(updated);
  }

  // Mock persistence helpers
  Future<BookProgress> _loadBookProgressFromStorage(String id) async {
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Simulate async DB read
    return BookProgress(bookId: id, currentChapter: 1, currentLine: 42);
  }

  Future<void> _saveProgressToStorage(BookProgress progress) async {
    // Save to local DB/API
  }
}

// Global Provider Definition
final bookProgressProvider = AsyncNotifierProvider.autoDispose
    .family<BookProgressNotifier, BookProgress, String>(
      BookProgressNotifier.new,
    );

class TestProviderScreen extends ConsumerWidget {
  final String bookId;

  const TestProviderScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch async progress for this specific book
    final progressAsync = ref.watch(bookProgressProvider(bookId));

    return Scaffold(
      appBar: AppBar(title: Text('Reading Book $bookId')),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Error loading progress: $err')),
        data: (progress) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Chapter: ${progress.currentChapter}'),
              Text('Line: ${progress.currentLine}'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Call update line action
                  ref
                      .read(bookProgressProvider(bookId).notifier)
                      .updateLine(progress.currentLine + 1);
                },
                child: const Text('Next Line'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Call update line action
                  ref
                      .read(bookProgressProvider(bookId).notifier)
                      .updateChapter(progress.currentChapter + 1);
                },
                child: const Text('Next Chapter'),
              ),
            ],
          );
        },
      ),
    );
  }
}

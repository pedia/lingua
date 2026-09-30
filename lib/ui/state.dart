import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../epub/epub.dart' as epub;
// import '../data/model.dart';

typedef ReadProgress = (int, int);

//
class ReadState {
  ReadState({required this.id, required this.book, required this.progress});
  final int id;
  final epub.Book book;
  final ReadProgress progress;

  ReadState copyWith({int? id, epub.Book? book, ReadProgress? progress}) =>
      ReadState(
        id: id ?? this.id,
        book: book ?? this.book,
        progress: progress ?? this.progress,
      );
}

class ReadNotifier extends Notifier<ReadState> {
  @override
  ReadState build() {
    return ReadState(id: 0, book: epub.Book.empty(), progress: (0, 0));
  }

  void update({ReadProgress? progress}) {
    state = state.copyWith(progress: progress);
  }
}

final readp = NotifierProvider<ReadNotifier, ReadState>(ReadNotifier.new);

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
}

class ReadNotifier extends Notifier<ReadProgress> {
  @override
  ReadProgress build() {
    return (0, 0);
  }
}

// Read progress
final readpp = NotifierProvider<ReadNotifier, ReadProgress>(ReadNotifier.new);

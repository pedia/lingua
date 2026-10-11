/// list.imap((index, e){ ... })
extension IndexedMapExtension<T> on Iterable<T> {
  Iterable<R> imap<R>(R Function(int index, T element) f) sync* {
    for (final (index, element) in indexed) {
      yield f(index, element);
    }
  }
}

import '../lib/epub/epub.dart';
import '../lib/data/sample.dart';

void main(List<String> argv) {
  for (final c in HtmlExtractor('foo/bar/a.html').extract(complex.body!)) {
    print(c);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lingua/epub/text_splitter.dart' as text;

void main() {
  test('detects language and collapses whitespace', () {
    expect(text.collapseWhitespace('  a   b '), 'a b');
    expect(text.detectLanguage('Hello there'), 'en');
    expect(text.detectLanguage('这是中文测试文本'), 'zh');

    expect({} == {}, isFalse);
  });
}

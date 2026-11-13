import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/src/widgets/binding.dart';
import 'package:lingua/epub/lang.dart';
import 'package:flutter_open_chinese_convert/flutter_open_chinese_convert.dart';
import 'package:opencc/opencc.dart' show ZhConverter;

class ChineseTextUtility {
  // 1. Check if a string consists entirely of Chinese characters
  static bool isChinese(String text) {
    if (text.isEmpty) return false;
    // Matches common and extension CJK blocks
    final chineseRegExp = RegExp(r'^[\u4e00-\u9fff\u3400-\u4dbf]+$');
    return chineseRegExp.hasMatch(text);
  }

  // Alternatively, check if a string contains *any* Chinese characters
  static bool containsChinese(String text) {
    final chineseRegExp = RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf]');
    return chineseRegExp.hasMatch(text);
  }

  // 2. Convert Simplified Chinese (or mixed text) to Traditional Chinese
  static Future<String> convertToTraditional(String input) async {
    // Uses OpenCC Simplified to Traditional (S2T) conversion
    return await ChineseConverter.convert(input, S2T());
  }

  // 3. Normalize and Compare two Chinese strings
  static Future<bool> compareChineseStrings(
    String string1,
    String string2,
  ) async {
    // Validate both strings contain Chinese text
    if (!containsChinese(string1) || !containsChinese(string2)) {
      print('One or both strings do not contain Chinese characters.');
      return false;
    }

    // Convert both to a unified Traditional format before comparing
    String traditional1 = await convertToTraditional(string1);
    String traditional2 = await convertToTraditional(string2);

    return traditional1 == traditional2;
  }
}

void main() {
  test('lang', () {
    String input =
        "Hello, Dart! 你好，世界：这里是2026年——欢迎来到编程的世界。《测试》[括号]（括号）...123-abc_xyz word?？";
    String result = input.replaceAll(RegExp(r'[\p{P}]', unicode: true), '');
    expect(result, 'Hello Dart 你好世界这里是2026年欢迎来到编程的世界测试括号括号123abcxyz word');
    expect(detectLang(input), Lang.zh);
    String result2 = input.replaceAll(RegExp(r'[\p{P}0-9]', unicode: true), '');
    expect(result2, 'Hello Dart 你好世界这里是年欢迎来到编程的世界测试括号括号abcxyz word');
    expect(detectLang('1 中文'), Lang.zh);
    expect(detectLang('1'), Lang.en);
    expect(detectLang('这我就不知道了。'), Lang.zh);
  });
  WidgetsFlutterBinding.ensureInitialized();
  test('aopencc', () async {
    String simplifiedText = "汉字"; // Simplified for "Chinese characters"
    String traditionalText = "漢字"; // Traditional for "Chinese characters"

    // Check if it's Chinese
    print(
      'Is "$simplifiedText" Chinese? ${ChineseTextUtility.isChinese(simplifiedText)}',
    ); // true

    // Convert and Compare
    bool areEqual = await ChineseTextUtility.compareChineseStrings(
      simplifiedText,
      traditionalText,
    );
    print('Are both strings identical after conversion? $areEqual'); // true
  });

  test('opencc', () {
    final zh = ZhConverter('s2t');
    expect(zh.convert('汉字'), '漢字');
  });
}

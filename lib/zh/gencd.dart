// Generate compact dict source code
import 'sc2tc.dart';

String codepoint(String c) {
  return '0x${c.runes.first.toRadixString(16).toUpperCase()}';
}

void main() {
  final sorted = sc2tcmap.entries.toList()
    ..sort((a, b) => a.key.runes.first.compareTo(b.key.runes.first));

  print('''import 'package:collection/collection.dart';

class CompactDict {
  static final List<int> _keys = [''');
  for (int i = 0; i < sorted.length; i++) {
    print('    ${codepoint(sorted[i].key)}, // ${sorted[i].key}');
  }
  print('''  ];''');

  print('''
  static final List<int> _values = [''');
  for (int i = 0; i < sorted.length; i++) {
    print('    ${codepoint(sorted[i].value)}, // ${sorted[i].value}');
  }
  print('''  ];
  
  static String convert(String input) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      int code = input.codeUnitAt(i);
      
      // Fast binary search on primitive integers
      int index = binarySearch(_keys, code);
      if (index != -1) {
        buffer.writeCharCode(_values[index]);
      } else {
        buffer.write(input[i]);
      }
    }
    return buffer.toString();
  }
}  
  ''');
}

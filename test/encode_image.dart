import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

void main(List<String> args) {
  if (args.isEmpty) return;
  final f = File(args[0])..open();

  f.readAsBytes().then((bs) {
    var i = 0;
    for (var b in bs) {
      if (i++ % 10 == 0) print('//');
      stdout.write('$b,');
    }
    print('');
  });
}

Future<String> imageToBase64(File imageFile) async {
  // 1. Read the image file as bytes (Uint8List)
  Uint8List imageBytes = await imageFile.readAsBytes();

  // 2. Base64 encode the bytes
  String base64String = base64Encode(imageBytes);

  return base64String;
}

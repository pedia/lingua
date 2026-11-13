import 'dart:io';
import 'package:lingua/data/sample.dart';

void main(List<String> argv) async {
  File("1.png").writeAsBytes(note);
}

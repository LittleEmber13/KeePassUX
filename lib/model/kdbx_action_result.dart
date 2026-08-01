import 'dart:typed_data';
import 'db_root.dart';

class KdbxActionResult {
  final DbRoot root;
  final Uint8List savedBytes;
  KdbxActionResult({required this.root, required this.savedBytes});
}
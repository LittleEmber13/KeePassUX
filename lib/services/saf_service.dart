import 'package:flutter/services.dart';

class SafService {
  static const _channel = MethodChannel('com.example.keepassux/saf');

  Future<void> takePersistablePermission(String uri) async {
    try {
      await _channel.invokeMethod('takePersistableUriPermission', {'uri': uri});
    } catch (_) {}
  }

  Future<String?> openDocument() async {
    try {
      return await _channel.invokeMethod<String>('openDocument');
    } catch (_) {
      return null;
    }
  }

  Future<String?> createDocument(String fileName) async {
    try {
      return await _channel.invokeMethod<String>('createDocument', {
        'fileName': fileName,
      });
    } catch (_) {
      return null;
    }
  }
}

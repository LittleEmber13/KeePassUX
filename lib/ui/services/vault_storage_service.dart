import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:content_resolver/content_resolver.dart';
import 'package:uri_content/uri_content.dart';

class VaultWriteException implements Exception {
  VaultWriteException(this.message, {required this.rolledBack});

  final String message;
  final bool rolledBack;

  @override
  String toString() => 'VaultWriteException($message, rolledBack: $rolledBack)';
}

typedef VaultBytesWriter = Future<void> Function(String uri, Uint8List bytes);
typedef VaultBytesReader = Future<Uint8List> Function(String uri);

class VaultStorageService {
  VaultStorageService({
    VaultBytesWriter? writeBytes,
    VaultBytesReader? readBytes,
  }) : _writeBytes = writeBytes ?? _writeContent,
       _readBytes = readBytes ?? _readContent;

  static const Duration _verifyRetryDelay = Duration(milliseconds: 150);
  static const ListEquality<int> _bytesEqual = ListEquality<int>();

  final VaultBytesWriter _writeBytes;
  final VaultBytesReader _readBytes;

  String? _baselineUri;
  Uint8List? _baseline;

  Uint8List? get baseline => _baseline;

  void rememberBaseline(String uri, Uint8List bytes) {
    if (uri.isEmpty || bytes.isEmpty) return;
    _baselineUri = uri;
    _baseline = bytes;
  }

  void forgetBaseline() {
    _baselineUri = null;
    _baseline = null;
  }

  Future<void> save(String uri, Uint8List bytes) async {
    Object failure;
    try {
      await _writeBytes(uri, bytes);
      if (await _verify(uri, bytes)) {
        rememberBaseline(uri, bytes);
        return;
      }
      failure = StateError('written content does not match');
    } catch (e) {
      failure = e;
    }
    throw VaultWriteException('$uri: $failure', rolledBack: await _rollback(uri));
  }

  Future<bool> _rollback(String uri) async {
    final previous = _baselineUri == uri ? _baseline : null;
    if (previous == null) return false;
    try {
      await _writeBytes(uri, previous);
      return await _verify(uri, previous);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _verify(String uri, Uint8List bytes) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_verifyRetryDelay);
      try {
        if (_bytesEqual.equals(await _readBytes(uri), bytes)) return true;
      } catch (_) {}
    }
    return false;
  }

  static Future<void> _writeContent(String uri, Uint8List bytes) =>
      ContentResolver.writeContent(uri, bytes);

  static Future<Uint8List> _readContent(String uri) =>
      UriContent().from(Uri.parse(uri));
}

final VaultStorageService vaultStorage = VaultStorageService();

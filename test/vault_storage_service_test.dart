import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepassux/error/vault_write_exception.dart';
import 'package:keepassux/services/vault_storage_service.dart';

const String _uri = 'content://com.android.providers.downloads/document/42';

class _FakeDocument {
  Uint8List? content;
  Uint8List? staleRead;
  Object? failNextWrite;
  bool failEveryWrite = false;
  final List<Uint8List> writes = <Uint8List>[];

  Future<void> write(String uri, Uint8List bytes) async {
    writes.add(Uint8List.fromList(bytes));
    final failure = failNextWrite;
    if (failure != null || failEveryWrite) {
      failNextWrite = null;
      content = Uint8List.fromList(bytes.sublist(0, bytes.length ~/ 2));
      throw failure ?? Exception('write rejected');
    }
    content = Uint8List.fromList(bytes);
  }

  Future<Uint8List> read(String uri) async {
    final stale = staleRead;
    if (stale != null) {
      staleRead = null;
      return stale;
    }
    final current = content;
    if (current == null) throw StateError('no content');
    return current;
  }
}

Uint8List _bytes(int seed, {int length = 64}) =>
    Uint8List.fromList(List<int>.generate(length, (i) => (seed + i) % 256));

void main() {
  late _FakeDocument document;
  late VaultStorageService storage;

  setUp(() {
    document = _FakeDocument();
    storage = VaultStorageService(
      writeBytes: document.write,
      readBytes: document.read,
    );
  });

  group('save', () {
    test('writes the document and adopts the verified bytes as baseline', () async {
      final payload = _bytes(1);

      await storage.save(_uri, payload);

      expect(document.content, payload);
      expect(storage.baseline, payload);
    });

    test('rolls the document back when the write throws', () async {
      final good = _bytes(1);
      await storage.save(_uri, good);

      document.failNextWrite = Exception('provider is gone');

      await expectLater(
        storage.save(_uri, _bytes(2)),
        throwsA(
          isA<VaultWriteException>().having((e) => e.rolledBack, 'rolledBack', true),
        ),
      );
      expect(document.content, good);
      expect(storage.baseline, good);
    });

    test('rolls the document back when verification fails', () async {
      final good = _bytes(1);
      await storage.save(_uri, good);

      storage = VaultStorageService(
        writeBytes: document.write,
        readBytes: (uri) async => _bytes(99),
      );
      storage.rememberBaseline(_uri, good);

      await expectLater(
        storage.save(_uri, _bytes(2)),
        throwsA(isA<VaultWriteException>()),
      );
      expect(document.content, good);
    });

    test('reports an unrecoverable failure when the rollback also fails', () async {
      storage.rememberBaseline(_uri, _bytes(1));
      document.failEveryWrite = true;

      await expectLater(
        storage.save(_uri, _bytes(2)),
        throwsA(
          isA<VaultWriteException>().having(
            (e) => e.rolledBack,
            'rolledBack',
            false,
          ),
        ),
      );
    });

    test('accepts a stale read on the first verification attempt', () async {
      final payload = _bytes(3);
      document.staleRead = _bytes(99);

      await storage.save(_uri, payload);

      expect(document.content, payload);
      expect(storage.baseline, payload);
      expect(document.writes, hasLength(1));
    });

    test('keeps the previous baseline when the save fails', () async {
      final good = _bytes(1);
      await storage.save(_uri, good);

      document.failNextWrite = Exception('interrupted');
      await expectLater(
        storage.save(_uri, _bytes(2)),
        throwsA(isA<VaultWriteException>()),
      );

      expect(storage.baseline, good);
    });

    test('does not roll back to a baseline belonging to another vault', () async {
      storage.rememberBaseline('content://other/9', _bytes(1));
      document.failNextWrite = Exception('no permission');

      await expectLater(
        storage.save(_uri, _bytes(2)),
        throwsA(
          isA<VaultWriteException>().having(
            (e) => e.rolledBack,
            'rolledBack',
            false,
          ),
        ),
      );
      expect(document.writes, hasLength(1));
    });
  });

  group('baseline', () {
    test('ignores an empty uri or empty content', () {
      storage.rememberBaseline('', _bytes(1));
      expect(storage.baseline, isNull);

      storage.rememberBaseline(_uri, Uint8List(0));
      expect(storage.baseline, isNull);
    });

    test('forgetBaseline drops the retained bytes', () async {
      await storage.save(_uri, _bytes(1));
      expect(storage.baseline, isNotNull);

      storage.forgetBaseline();

      expect(storage.baseline, isNull);
    });
  });
}

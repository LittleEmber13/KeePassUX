import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keepassux/model/db_root.dart';
import 'package:keepassux/model/kdbx_action_result.dart';
import 'package:keepassux/utils/kdbx_command.dart';
import 'package:keepassux/utils/kdbx_isolate.dart';

const String _password = 'correct horse battery staple';

Future<Uint8List> _cheapVault() async {
  final format = KdbxFormat();
  final file = format.create(
    Credentials(ProtectedValue.fromString(_password)),
    'serialization-test',
  );
  file.header.writeKdfParameters(
    argon2KdfParams(
      file.header.readKdfParameters,
      memoryBytes: 1024 * 1024,
      iterations: 1,
      parallelism: 1,
    ),
  );
  return file.save();
}

void main() {
  test('rollback restores the previous state after a failed save', () async {
    final bytes = await _cheapVault();
    final isolate = KdbxIsolate();
    await isolate.init();
    addTearDown(isolate.dispose);

    final root = await isolate.send<DbRoot>(
      LoadDatabaseCmd(bytes: bytes, password: _password),
    );

    final mutated = await isolate.send<KdbxActionResult>(
      AddEntryCmd(
        groupUuid: root.rootGroup.uuid,
        title: 'never persisted',
        userName: '',
        url: '',
        notes: '',
        password: '',
      ),
    );
    expect(mutated.root.rootGroup.entries, hasLength(1));

    final restored = await isolate.send<DbRoot>(RollbackCmd(bytes: bytes));

    expect(restored.rootGroup.entries, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('rollback after a master password change uses the old password', () async {
    final bytes = await _cheapVault();
    final isolate = KdbxIsolate();
    await isolate.init();
    addTearDown(isolate.dispose);

    await isolate.send<DbRoot>(
      LoadDatabaseCmd(bytes: bytes, password: _password),
    );
    await isolate.send<KdbxActionResult>(
      ChangeMasterPasswordCmd(
        oldPassword: _password,
        newPassword: 'a brand new secret',
      ),
    );

    final restored = await isolate.send<DbRoot>(
      RollbackCmd(bytes: bytes, password: _password),
    );

    expect(restored.rootGroup.uuid, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

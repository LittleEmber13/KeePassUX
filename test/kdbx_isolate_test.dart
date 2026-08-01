import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keepassux/model/db_group.dart';
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

  test('restoring an entry sends it back to the group it was deleted from',
      () async {
    final (:isolate, :root) = await _loadedIsolate();
    final withGroup = await isolate.send<KdbxActionResult>(
      AddGroupCmd(parentUuid: root.uuid, name: 'Trabajo'),
    );
    final workUuid = withGroup.root.rootGroup.groups
        .firstWhere((g) => g.name == 'Trabajo')
        .uuid;

    final withEntry = await isolate.send<KdbxActionResult>(
      AddEntryCmd(
        groupUuid: workUuid,
        title: 'nomina',
        userName: '',
        url: '',
        notes: '',
        password: '',
      ),
    );
    final entryUuid = withEntry.root.rootGroup
        .findByUuid(workUuid)!
        .entries
        .single
        .uuid;

    final deleted = await isolate.send<KdbxActionResult>(
      DeleteEntryCmd(entryUuid: entryUuid),
    );
    expect(deleted.root.rootGroup.findByUuid(workUuid)!.entries, isEmpty);

    await isolate.send<DbRoot>(ReloadDatabaseCmd(bytes: deleted.savedBytes));

    final restored = await isolate.send<KdbxActionResult>(
      RestoreEntryCmd(entryUuid: entryUuid),
    );

    expect(
      restored.root.rootGroup.findGroupOfEntry(entryUuid)?.uuid,
      workUuid,
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('restoring falls back to the root when the previous group is trash',
      () async {
    final (:isolate, :root) = await _loadedIsolate();
    final withEntry = await isolate.send<KdbxActionResult>(
      AddEntryCmd(
        groupUuid: root.uuid,
        title: 'suelta',
        userName: '',
        url: '',
        notes: '',
        password: '',
      ),
    );
    final entryUuid = withEntry.root.rootGroup.entries.single.uuid;

    final deleted = await isolate.send<KdbxActionResult>(
      DeleteEntryCmd(entryUuid: entryUuid),
    );
    final trash = deleted.root.rootGroup.groups.firstWhere((g) => g.isRecycleBin);

    final withTrashFolder = await isolate.send<KdbxActionResult>(
      AddGroupCmd(parentUuid: trash.uuid, name: 'dentro'),
    );
    final innerUuid = withTrashFolder.root.rootGroup
        .findByUuid(trash.uuid)!
        .groups
        .firstWhere((g) => g.name == 'dentro')
        .uuid;
    await isolate.send<KdbxActionResult>(
      MoveEntryCmd(
        entryUuid: entryUuid,
        fromGroupUuid: trash.uuid,
        toGroupUuid: innerUuid,
      ),
    );

    final restored = await isolate.send<KdbxActionResult>(
      RestoreEntryCmd(entryUuid: entryUuid),
    );

    expect(
      restored.root.rootGroup.findGroupOfEntry(entryUuid)?.uuid,
      restored.root.rootGroup.uuid,
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('restoring a group sends it back to its previous parent', () async {
    final (:isolate, :root) = await _loadedIsolate();
    final withParent = await isolate.send<KdbxActionResult>(
      AddGroupCmd(parentUuid: root.uuid, name: 'Personal'),
    );
    final parentUuid = withParent.root.rootGroup.groups
        .firstWhere((g) => g.name == 'Personal')
        .uuid;

    final withChild = await isolate.send<KdbxActionResult>(
      AddGroupCmd(parentUuid: parentUuid, name: 'Bancos'),
    );
    final childUuid = withChild.root.rootGroup
        .findByUuid(parentUuid)!
        .groups
        .single
        .uuid;

    await isolate.send<KdbxActionResult>(DeleteGroupCmd(groupUuid: childUuid));

    final restored = await isolate.send<KdbxActionResult>(
      RestoreGroupCmd(groupUuid: childUuid),
    );

    expect(restored.root.rootGroup.findParentOf(childUuid)?.uuid, parentUuid);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<({KdbxIsolate isolate, DbGroup root})> _loadedIsolate() async {
  final bytes = await _cheapVault();
  final isolate = KdbxIsolate();
  await isolate.init();
  addTearDown(isolate.dispose);
  final loaded = await isolate.send<DbRoot>(
    LoadDatabaseCmd(bytes: bytes, password: _password),
  );
  return (isolate: isolate, root: loaded.rootGroup);
}

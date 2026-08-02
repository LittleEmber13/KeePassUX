import 'dart:async';
import 'dart:isolate';
import 'package:argon2_ffi_base/argon2_ffi_base.dart';
import 'package:collection/collection.dart';
import 'package:kdbx/kdbx.dart';
import 'package:kdbx/src/kdbx_var_dictionary.dart' show VarDictionary;

import '../error/kdbx_isolate_error.dart';
import 'cached_argon2.dart';
import 'kdbx_command.dart';
import '../model/db_entry.dart';
import '../model/db_group.dart';
import '../model/db_root.dart';
import '../model/kdbx_action_result.dart';
import '../model/kdf_info.dart';

const int kDefaultArgon2MemoryBytes = 64 * 1024 * 1024;
const int kDefaultArgon2Iterations = 3;
const int kDefaultArgon2Parallelism = 1;

class KdbxIsolate {
  Isolate? _isolate;
  SendPort? _sendPort;
  final Completer<void> _initCompleter = Completer<void>();

  Future<void> init() async {
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(kdbxIsolateEntryPoint, receivePort.sendPort);
    _sendPort = await receivePort.first as SendPort;
    _initCompleter.complete();
  }

  Future<T> send<T>(KdbxCommand command) async {
    await _initCompleter.future;
    final responsePort = ReceivePort();
    _sendPort!.send([command, responsePort.sendPort]);
    final result = await responsePort.first;
    if (result is KdbxIsolateError) {
      throw Exception(result.message);
    }
    return result as T;
  }

  void dispose() {
    _isolate?.kill();
    _isolate = null;
    _sendPort = null;
  }
}

VarDictionary argon2KdfParams(
  VarDictionary current, {
  required int memoryBytes,
  required int iterations,
  required int parallelism,
}) {
  final secretKey = KdfField.secretKey.read(current);
  final assocData = KdfField.assocData.read(current);
  return VarDictionary([
    KdfField.uuid.item(KdfField.uuid.read(current)!),
    KdfField.salt.item(KdfField.salt.read(current)!),
    KdfField.version.item(KdfField.version.read(current)!),
    KdfField.memory.item(memoryBytes),
    KdfField.iterations.item(iterations),
    KdfField.parallelism.item(parallelism),
    if (secretKey != null) KdfField.secretKey.item(secretKey),
    if (assocData != null) KdfField.assocData.item(assocData),
  ]);
}

KdbxFormat _createKdbxFormat() {
  try {
    return KdbxFormat(CachedArgon2(Argon2FfiFlutter()));
  } catch (_) {
    return KdbxFormat();
  }
}

void kdbxIsolateEntryPoint(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  KdbxFormat? format;
  KdbxFile? kdbx;
  Future<void> pending = Future<void>.value();

  Future<void> handle(dynamic message) async {
    final List<dynamic> parts = message;
    final KdbxCommand command = parts[0] as KdbxCommand;
    final SendPort replyPort = parts[1] as SendPort;

    try {
      if (command is LoadDatabaseCmd) {
        final credentials = Credentials(
          ProtectedValue.fromString(command.password),
        );
        format ??= _createKdbxFormat();
        kdbx = await format!.read(command.bytes, credentials);
        replyPort.send(_serializeRoot(kdbx!));
      } else if (command is ReloadDatabaseCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        kdbx = await format!.read(command.bytes, kdbx!.credentials);
        replyPort.send(_serializeRoot(kdbx!));
      } else if (command is RollbackCmd) {
        if (format == null) throw Exception('No database loaded');
        final password = command.password;
        if (kdbx == null && password == null) {
          throw Exception('No database loaded');
        }
        kdbx = await format!.read(
          command.bytes,
          password != null
              ? Credentials(ProtectedValue.fromString(password))
              : kdbx!.credentials,
        );
        replyPort.send(_serializeRoot(kdbx!));
      } else if (command is LockDatabaseCmd) {
        kdbx = null;
        format = null;
        replyPort.send(true);
      } else if (command is AddEntryCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final group = _findGroup(kdbx!, command.groupUuid);
        final entry = KdbxEntry.create(kdbx!, group);
        group.addEntry(entry);
        entry.setString(KdbxKeyCommon.TITLE, PlainValue(command.title));
        entry.setString(KdbxKeyCommon.USER_NAME, PlainValue(command.userName));
        entry.setString(KdbxKeyCommon.URL, PlainValue(command.url));
        entry.setString(KdbxKey('Notes'), PlainValue(command.notes));
        entry.setString(
          KdbxKeyCommon.PASSWORD,
          ProtectedValue.fromString(command.password),
        );
        entry.icon.set(KdbxIcon.values[command.icon]);
        if (command.customIconData != null) {
          entry.customIcon = KdbxCustomIcon(
            uuid: KdbxUuid.random(),
            data: command.customIconData!,
          );
        }
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is UpdateEntryCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final entry = _findEntry(kdbx!, command.entryUuid);
        entry.setString(KdbxKeyCommon.TITLE, PlainValue(command.title));
        entry.setString(KdbxKeyCommon.USER_NAME, PlainValue(command.userName));
        entry.setString(KdbxKeyCommon.URL, PlainValue(command.url));
        entry.setString(KdbxKey('Notes'), PlainValue(command.notes));
        entry.setString(
          KdbxKeyCommon.PASSWORD,
          ProtectedValue.fromString(command.password),
        );
        entry.icon.set(KdbxIcon.values[command.icon]);
        if (command.customIconData != null) {
          entry.customIcon = KdbxCustomIcon(
            uuid: KdbxUuid.random(),
            data: command.customIconData!,
          );
        } else {
          entry.customIcon = null;
        }
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is AddGroupCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final parentGroup = _findGroup(kdbx!, command.parentUuid);
        final newGroup = KdbxGroup.create(
          ctx: kdbx!.ctx,
          parent: parentGroup,
          name: command.name,
        );
        parentGroup.addGroup(newGroup);
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is MoveEntryCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final entry = _findEntry(kdbx!, command.entryUuid);
        final toGroup = _findGroup(kdbx!, command.toGroupUuid);
        kdbx!.move(entry, toGroup);
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is MoveGroupCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final groupToMove = _findGroup(kdbx!, command.groupUuid);
        final toParent = _findGroup(kdbx!, command.toGroupUuid);
        final descendants = groupToMove.getAllGroups().map((g) => g.uuid.uuid).toList();
        if (descendants.contains(toParent.uuid.uuid)) {
          throw Exception('Cannot move group into its own descendant');
        }
        kdbx!.move(groupToMove, toParent);
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is MoveItemsCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final toGroup = _findGroup(kdbx!, command.toGroupUuid);
        for (final groupUuid in command.groupUuids) {
          final groupToMove = _findGroup(kdbx!, groupUuid);
          if (groupToMove.uuid.uuid == toGroup.uuid.uuid) continue;
          if (groupToMove.parent?.uuid.uuid == toGroup.uuid.uuid) continue;
          final descendants =
              groupToMove.getAllGroups().map((g) => g.uuid.uuid).toList();
          if (descendants.contains(toGroup.uuid.uuid)) {
            throw Exception('Cannot move group into its own descendant');
          }
          kdbx!.move(groupToMove, toGroup);
        }
        for (final entryUuid in command.entryUuids) {
          final entry = _findEntry(kdbx!, entryUuid);
          if (entry.parent?.uuid.uuid == toGroup.uuid.uuid) continue;
          kdbx!.move(entry, toGroup);
        }
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is DeleteItemsCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        for (final groupUuid in command.groupUuids) {
          final group = _findGroup(kdbx!, groupUuid);
          kdbx!.deleteGroup(group);
        }
        for (final entryUuid in command.entryUuids) {
          final entry = _findEntry(kdbx!, entryUuid);
          kdbx!.deleteEntry(entry);
        }
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is CopyItemsCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final toGroup = _findGroup(kdbx!, command.toGroupUuid);
        for (final groupUuid in command.groupUuids) {
          final source = _findGroup(kdbx!, groupUuid);
          if (source.uuid.uuid == toGroup.uuid.uuid ||
              source
                  .getAllGroups()
                  .any((g) => g.uuid.uuid == toGroup.uuid.uuid)) {
            throw Exception('Cannot copy group into its own descendant');
          }
          _cloneGroup(kdbx!, source, toGroup);
        }
        for (final entryUuid in command.entryUuids) {
          _cloneEntry(kdbx!, _findEntry(kdbx!, entryUuid), toGroup);
        }
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is UpdateGroupCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final group = _findGroup(kdbx!, command.groupUuid);
        group.name.set(command.name);
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is DeleteEntryCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final entry = _findEntry(kdbx!, command.entryUuid);
        kdbx!.deleteEntry(entry);
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is DeleteGroupCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final group = _findGroup(kdbx!, command.groupUuid);
        kdbx!.deleteGroup(group);
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is RestoreEntryCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final entry = _findEntry(kdbx!, command.entryUuid);
        kdbx!.move(entry, _restoreTarget(kdbx!, entry));
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is RestoreGroupCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final group = _findGroup(kdbx!, command.groupUuid);
        kdbx!.move(group, _restoreTarget(kdbx!, group));
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is DeleteEntryPermanentlyCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final entry = _findEntry(kdbx!, command.entryUuid);
        kdbx!.deletePermanently(entry);
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is DeleteGroupPermanentlyCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final group = _findGroup(kdbx!, command.groupUuid);
        kdbx!.deletePermanently(group);
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is AssociateAppCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final entry = _findEntry(kdbx!, command.entryUuid);
        _addAssociation(entry, command.association);
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is CreateDatabaseCmd) {
        format ??= _createKdbxFormat();
        kdbx = format!.create(
          Credentials(ProtectedValue.fromString(command.password)),
          'KeepassUX',
        );
        kdbx!.header.writeKdfParameters(
          argon2KdfParams(
            kdbx!.header.readKdfParameters,
            memoryBytes: kDefaultArgon2MemoryBytes,
            iterations: kDefaultArgon2Iterations,
            parallelism: kDefaultArgon2Parallelism,
          ),
        );
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is GetKdfParametersCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final kdfParams = kdbx!.header.readKdfParameters;
        final kdfTypeName =
            KeyEncrypterKdf.kdfTypeFor(kdfParams) == KdfType.Aes
                ? 'aes'
                : 'argon2';
        replyPort.send(
          KdfInfo(
            kdfType: kdfTypeName,
            memoryBytes: KdfField.memory.read(kdfParams) ?? 0,
            iterations: KdfField.iterations.read(kdfParams) ?? 0,
            parallelism: KdfField.parallelism.read(kdfParams) ?? 0,
          ),
        );
      } else if (command is ChangeKdfParametersCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final kdfParams = kdbx!.header.readKdfParameters;
        if (KeyEncrypterKdf.kdfTypeFor(kdfParams) != KdfType.Argon2) {
          throw Exception('Unsupported KDF type');
        }
        kdbx!.header.writeKdfParameters(
          argon2KdfParams(
            kdfParams,
            memoryBytes: command.memoryBytes,
            iterations: command.iterations,
            parallelism: command.parallelism,
          ),
        );
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      } else if (command is ChangeMasterPasswordCmd) {
        if (kdbx == null) throw Exception('No database loaded');
        final oldCredentials = Credentials(
          ProtectedValue.fromString(command.oldPassword),
        );
        final matches = const ListEquality<int>().equals(
          oldCredentials.getHash(),
          kdbx!.credentials.getHash(),
        );
        if (!matches) {
          throw Exception('Invalid current password');
        }
        kdbx!.credentials = Credentials(
          ProtectedValue.fromString(command.newPassword),
        );
        final bytes = await kdbx!.save();
        replyPort.send(
          KdbxActionResult(root: _serializeRoot(kdbx!), savedBytes: bytes),
        );
      }
    } catch (e) {
      replyPort.send(KdbxIsolateError(e.toString()));
    }
  }

  receivePort.listen((dynamic message) {
    pending = pending.then((_) => handle(message)).catchError((_) {});
  });
}

KdbxGroup _findGroup(KdbxFile kdbx, String uuid) {
  final allGroups = kdbx.body.rootGroup.getAllGroups();
  final group = allGroups.firstWhereOrNull((g) => g.uuid.uuid == uuid);
  if (group == null) throw Exception('Group not found: $uuid');
  return group;
}

KdbxGroup _restoreTarget(KdbxFile kdbx, KdbxObject object) {
  final root = kdbx.body.rootGroup;
  final previousUuid = object.previousParentGroup.get()?.uuid;
  if (previousUuid == null) return root;

  final candidate = root.getAllGroups().firstWhereOrNull(
    (g) => g.uuid.uuid == previousUuid,
  );
  if (candidate == null) return root;

  final recycleBinUuid = kdbx.recycleBin?.uuid;
  if (candidate.uuid == recycleBinUuid || candidate.isInRecycleBin()) {
    return root;
  }
  if (object is KdbxGroup &&
      (candidate.uuid == object.uuid || candidate.isInGroup(object))) {
    return root;
  }
  return candidate;
}

KdbxEntry _findEntry(KdbxFile kdbx, String uuid) {
  final allGroups = kdbx.body.rootGroup.getAllGroups();
  for (final group in allGroups) {
    for (final entry in group.entries) {
      if (entry.uuid.uuid == uuid) return entry;
    }
  }
  for (final entry in kdbx.body.rootGroup.entries) {
    if (entry.uuid.uuid == uuid) return entry;
  }
  throw Exception('Entry not found: $uuid');
}

KdbxEntry _cloneEntry(KdbxFile kdbx, KdbxEntry source, KdbxGroup target) {
  final copy = KdbxEntry.create(kdbx, target);
  target.addEntry(copy);
  for (final field in source.stringEntries) {
    if (field.value != null) {
      copy.setString(field.key, field.value);
    }
  }
  final icon = source.icon.get();
  if (icon != null) copy.icon.set(icon);
  if (source.customIcon != null) copy.customIcon = source.customIcon;
  return copy;
}

KdbxGroup _cloneGroup(KdbxFile kdbx, KdbxGroup source, KdbxGroup targetParent) {
  final copy = KdbxGroup.create(
    ctx: kdbx.ctx,
    parent: targetParent,
    name: source.name.get() ?? '',
  );
  targetParent.addGroup(copy);
  final icon = source.icon.get();
  if (icon != null) copy.icon.set(icon);
  if (source.customIcon != null) copy.customIcon = source.customIcon;
  for (final entry in source.entries.toList()) {
    _cloneEntry(kdbx, entry, copy);
  }
  for (final child in source.groups.toList()) {
    _cloneGroup(kdbx, child, copy);
  }
  return copy;
}

DbRoot _serializeRoot(KdbxFile kdbx) {
  final recycleBinUuid = kdbx.recycleBin?.uuid.uuid;
  return DbRoot(rootGroup: _serializeGroup(kdbx.body.rootGroup, recycleBinUuid));
}

DbGroup _serializeGroup(KdbxGroup group, String? recycleBinUuid) {
  return DbGroup(
    uuid: group.uuid.uuid,
    name: group.name.get() ?? '',
    icon: group.icon.get()?.index ?? 0,
    customIconData: group.customIcon?.data,
    groups: group.groups.map((g) => _serializeGroup(g, recycleBinUuid)).toList(),
    entries: group.entries.map(_serializeEntry).toList(),
    isRecycleBin: group.uuid.uuid == recycleBinUuid,
  );
}

DbEntry _serializeEntry(KdbxEntry entry) {
  return DbEntry(
    uuid: entry.uuid.uuid,
    label: entry.label ?? '',
    userName: entry.getString(KdbxKeyCommon.USER_NAME)?.getText() ?? '',
    password: entry.getString(KdbxKeyCommon.PASSWORD)?.getText() ?? '',
    url: entry.getString(KdbxKeyCommon.URL)?.getText() ?? '',
    notes: entry.getString(KdbxKey('Notes'))?.getText() ?? '',
    icon: entry.icon.get()?.index ?? 0,
    customIconData: entry.customIcon?.data,
    additionalUrls: _readAdditionalUrls(entry),
  );
}

List<String> _readAdditionalUrls(KdbxEntry entry) {
  final urls = <String>[];
  for (final e in entry.stringEntries) {
    if (e.key.key.startsWith('KP2A_URL')) {
      final value = e.value?.getText();
      if (value != null && value.isNotEmpty) urls.add(value);
    }
  }
  return urls;
}

void _addAssociation(KdbxEntry entry, String association) {
  final mainUrl = entry.getString(KdbxKeyCommon.URL)?.getText() ?? '';
  final existing = <String>[
    mainUrl,
    ..._readAdditionalUrls(entry),
  ].map((u) => u.toLowerCase()).toList();
  if (existing.contains(association.toLowerCase())) return;

  if (mainUrl.isEmpty) {
    entry.setString(KdbxKeyCommon.URL, PlainValue(association));
    return;
  }
  var n = 1;
  while (entry.getString(KdbxKey('KP2A_URL_$n')) != null) {
    n++;
  }
  entry.setString(KdbxKey('KP2A_URL_$n'), PlainValue(association));
}
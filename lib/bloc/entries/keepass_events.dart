import 'dart:typed_data';

abstract class KeePassEvent {}

class LoadDatabase extends KeePassEvent {
  final Uint8List bytes;
  final String password;

  LoadDatabase({required this.bytes, required this.password});
}

class CreateDatabase extends KeePassEvent {
  final String uri;
  final String password;

  CreateDatabase({required this.uri, required this.password});
}

class GetRootGroup extends KeePassEvent {
  GetRootGroup();
}

class ReloadDatabase extends KeePassEvent {
  ReloadDatabase();
}

class LockDatabase extends KeePassEvent {
  LockDatabase();
}

class AddEntry extends KeePassEvent {
  final String? uuidGroup;
  final String title;
  final String? userName;
  final String? url;
  final String? notes;
  final String password;
  final int? icon;
  final Uint8List? customIconData;

  AddEntry({
    this.uuidGroup,
    required this.title,
    this.userName,
    this.url,
    this.notes,
    required this.password,
    this.icon,
    this.customIconData,
  });
}

class AddGroup extends KeePassEvent {
  final String? uuidGroup;
  final String title;

  AddGroup({
    this.uuidGroup,
    required this.title,
  });
}

class MoveEntry extends KeePassEvent {
  final String entryUuid;
  final String fromGroupUuid;
  final String toGroupUuid;

  MoveEntry({
    required this.entryUuid,
    required this.fromGroupUuid,
    required this.toGroupUuid,
  });
}

class MoveGroup extends KeePassEvent {
  final String groupUuid;
  final String fromGroupUuid;
  final String toGroupUuid;

  MoveGroup({
    required this.groupUuid,
    required this.fromGroupUuid,
    required this.toGroupUuid,
  });
}

class MoveItems extends KeePassEvent {
  final List<String> entryUuids;
  final List<String> groupUuids;
  final String toGroupUuid;

  MoveItems({
    required this.entryUuids,
    required this.groupUuids,
    required this.toGroupUuid,
  });
}

class CopyItems extends KeePassEvent {
  final List<String> entryUuids;
  final List<String> groupUuids;
  final String toGroupUuid;

  CopyItems({
    required this.entryUuids,
    required this.groupUuids,
    required this.toGroupUuid,
  });
}

class DeleteItems extends KeePassEvent {
  final List<String> entryUuids;
  final List<String> groupUuids;

  DeleteItems({required this.entryUuids, required this.groupUuids});
}

class UpdateEntry extends KeePassEvent {
  final String entryUuid;
  final String title;
  final String? userName;
  final String? url;
  final String? notes;
  final String password;
  final int? icon;
  final Uint8List? customIconData;

  UpdateEntry({
    required this.entryUuid,
    required this.title,
    this.userName,
    this.url,
    this.notes,
    required this.password,
    this.icon,
    this.customIconData,
  });
}

class UpdateGroup extends KeePassEvent {
  final String groupUuid;
  final String name;

  UpdateGroup({
    required this.groupUuid,
    required this.name,
  });
}

class DeleteEntry extends KeePassEvent {
  final String entryUuid;

  DeleteEntry({required this.entryUuid});
}

class DeleteGroup extends KeePassEvent {
  final String groupUuid;

  DeleteGroup({required this.groupUuid});
}

class RestoreEntry extends KeePassEvent {
  final String entryUuid;

  RestoreEntry({required this.entryUuid});
}

class RestoreGroup extends KeePassEvent {
  final String groupUuid;

  RestoreGroup({required this.groupUuid});
}

class DeleteEntryPermanently extends KeePassEvent {
  final String entryUuid;

  DeleteEntryPermanently({required this.entryUuid});
}

class DeleteGroupPermanently extends KeePassEvent {
  final String groupUuid;

  DeleteGroupPermanently({required this.groupUuid});
}

class RestoreItems extends KeePassEvent {
  final List<String> entryUuids;
  final List<String> groupUuids;

  RestoreItems({required this.entryUuids, required this.groupUuids});
}

class DeleteItemsPermanently extends KeePassEvent {
  final List<String> entryUuids;
  final List<String> groupUuids;

  DeleteItemsPermanently({required this.entryUuids, required this.groupUuids});
}

class ChangeMasterPassword extends KeePassEvent {
  final String oldPassword;
  final String newPassword;

  ChangeMasterPassword({required this.oldPassword, required this.newPassword});
}

class GetKdfParameters extends KeePassEvent {
  GetKdfParameters();
}

class ChangeKdfParameters extends KeePassEvent {
  final int memoryBytes;
  final int iterations;
  final int parallelism;

  ChangeKdfParameters({
    required this.memoryBytes,
    required this.iterations,
    required this.parallelism,
  });
}

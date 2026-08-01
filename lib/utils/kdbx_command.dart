import 'dart:typed_data';

abstract class KdbxCommand {}

class LoadDatabaseCmd extends KdbxCommand {
  final Uint8List bytes;
  final String password;
  LoadDatabaseCmd({required this.bytes, required this.password});
}

class ReloadDatabaseCmd extends KdbxCommand {
  final Uint8List bytes;
  ReloadDatabaseCmd({required this.bytes});
}

class RollbackCmd extends KdbxCommand {
  final Uint8List bytes;
  final String? password;
  RollbackCmd({required this.bytes, this.password});
}

class AddEntryCmd extends KdbxCommand {
  final String groupUuid;
  final String title;
  final String userName;
  final String url;
  final String notes;
  final String password;
  final int icon;
  final Uint8List? customIconData;
  AddEntryCmd({
    required this.groupUuid,
    required this.title,
    required this.userName,
    required this.url,
    required this.notes,
    required this.password,
    this.icon = 0,
    this.customIconData,
  });
}

class UpdateEntryCmd extends KdbxCommand {
  final String entryUuid;
  final String title;
  final String userName;
  final String url;
  final String notes;
  final String password;
  final int icon;
  final Uint8List? customIconData;
  UpdateEntryCmd({
    required this.entryUuid,
    required this.title,
    required this.userName,
    required this.url,
    required this.notes,
    required this.password,
    required this.icon,
    this.customIconData,
  });
}

class AddGroupCmd extends KdbxCommand {
  final String parentUuid;
  final String name;
  AddGroupCmd({required this.parentUuid, required this.name});
}

class MoveEntryCmd extends KdbxCommand {
  final String entryUuid;
  final String fromGroupUuid;
  final String toGroupUuid;
  MoveEntryCmd({
    required this.entryUuid,
    required this.fromGroupUuid,
    required this.toGroupUuid,
  });
}

class MoveGroupCmd extends KdbxCommand {
  final String groupUuid;
  final String fromGroupUuid;
  final String toGroupUuid;
  MoveGroupCmd({
    required this.groupUuid,
    required this.fromGroupUuid,
    required this.toGroupUuid,
  });
}

class MoveItemsCmd extends KdbxCommand {
  final List<String> entryUuids;
  final List<String> groupUuids;
  final String toGroupUuid;
  MoveItemsCmd({
    required this.entryUuids,
    required this.groupUuids,
    required this.toGroupUuid,
  });
}

class CopyItemsCmd extends KdbxCommand {
  final List<String> entryUuids;
  final List<String> groupUuids;
  final String toGroupUuid;
  CopyItemsCmd({
    required this.entryUuids,
    required this.groupUuids,
    required this.toGroupUuid,
  });
}

class DeleteItemsCmd extends KdbxCommand {
  final List<String> entryUuids;
  final List<String> groupUuids;
  DeleteItemsCmd({required this.entryUuids, required this.groupUuids});
}

class UpdateGroupCmd extends KdbxCommand {
  final String groupUuid;
  final String name;
  UpdateGroupCmd({required this.groupUuid, required this.name});
}

class DeleteEntryCmd extends KdbxCommand {
  final String entryUuid;
  DeleteEntryCmd({required this.entryUuid});
}

class DeleteGroupCmd extends KdbxCommand {
  final String groupUuid;
  DeleteGroupCmd({required this.groupUuid});
}

class RestoreEntryCmd extends KdbxCommand {
  final String entryUuid;
  RestoreEntryCmd({required this.entryUuid});
}

class RestoreGroupCmd extends KdbxCommand {
  final String groupUuid;
  RestoreGroupCmd({required this.groupUuid});
}

class DeleteEntryPermanentlyCmd extends KdbxCommand {
  final String entryUuid;
  DeleteEntryPermanentlyCmd({required this.entryUuid});
}

class DeleteGroupPermanentlyCmd extends KdbxCommand {
  final String groupUuid;
  DeleteGroupPermanentlyCmd({required this.groupUuid});
}

class CreateDatabaseCmd extends KdbxCommand {
  final String password;
  CreateDatabaseCmd({required this.password});
}

class ChangeMasterPasswordCmd extends KdbxCommand {
  final String oldPassword;
  final String newPassword;
  ChangeMasterPasswordCmd({required this.oldPassword, required this.newPassword});
}

class GetKdfParametersCmd extends KdbxCommand {}

class ChangeKdfParametersCmd extends KdbxCommand {
  final int memoryBytes;
  final int iterations;
  final int parallelism;
  ChangeKdfParametersCmd({
    required this.memoryBytes,
    required this.iterations,
    required this.parallelism,
  });
}

class AssociateAppCmd extends KdbxCommand {
  final String entryUuid;
  final String association;
  AssociateAppCmd({required this.entryUuid, required this.association});
}

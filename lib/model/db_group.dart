import 'dart:typed_data';
import 'db_entry.dart';

class DbGroup {
  final String uuid;
  final String name;
  final int icon;
  final Uint8List? customIconData;
  final List<DbGroup> groups;
  final List<DbEntry> entries;
  final bool isRecycleBin;

  DbGroup({
    required this.uuid,
    required this.name,
    required this.icon,
    this.customIconData,
    required this.groups,
    required this.entries,
    this.isRecycleBin = false,
  });

  List<DbGroup> getAllGroups() {
    final result = <DbGroup>[];
    for (final group in groups) {
      result.add(group);
      result.addAll(group.getAllGroups());
    }
    return result;
  }

  DbGroup? findByUuid(String uuid) {
    if (this.uuid == uuid) return this;
    for (final child in groups) {
      final found = child.findByUuid(uuid);
      if (found != null) return found;
    }
    return null;
  }

  DbGroup? findParentOf(String childUuid) {
    for (final child in groups) {
      if (child.uuid == childUuid) return this;
      final found = child.findParentOf(childUuid);
      if (found != null) return found;
    }
    return null;
  }

  bool isDescendantOf(String ancestorUuid) {
    if (uuid == ancestorUuid) return true;
    final ancestor = findByUuid(ancestorUuid);
    if (ancestor == null) return false;
    final descendants = ancestor.getAllGroups().map((g) => g.uuid).toList();
    return descendants.contains(uuid);
  }
}
enum DragType { entry, group }

class DragItem {
  final DragType type;
  final String uuid;
  final String sourceGroupUuid;

  const DragItem({
    required this.type,
    required this.uuid,
    required this.sourceGroupUuid,
  });
}

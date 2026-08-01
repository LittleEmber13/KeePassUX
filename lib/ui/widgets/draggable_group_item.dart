import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:keepassux/model/drag_item.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/widgets/custom_app_scroll.dart';
import 'package:keepassux/ui/widgets/hold_detector.dart';

class DraggableGroupItem extends StatelessWidget {
  const DraggableGroupItem({
    required this.group,
    required this.sourceGroupUuid,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onAccept,
    required this.isDescendantOf,
    this.selectionEnabled = false,
    this.isSelected = false,
    this.isTinted = false,
    this.isFaded = false,
    this.onSelectionTap,
    this.onHoldSelect,
    super.key,
  });

  final dynamic group;
  final String sourceGroupUuid;
  final VoidCallback? onTap;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;
  final void Function(DragItem draggedItem) onAccept;
  final bool Function(String ancestorUuid, String descendantUuid) isDescendantOf;

  final bool selectionEnabled;
  final bool isSelected;
  final bool isTinted;
  final bool isFaded;
  final VoidCallback? onSelectionTap;

  final VoidCallback? onHoldSelect;

  BoxDecoration _itemDecoration(BuildContext context, bool isHovering) {
    var decoration = cardDecoration(context);
    if (selectionEnabled && isSelected) {
      return decoration.copyWith(
        color: isTinted
            ? Color.alphaBlend(
                Colors.lightBlueAccent.withValues(alpha: 0.12),
                context.appColors.cardBackground,
              )
            : null,
        border: Border.all(color: Colors.lightBlueAccent, width: 2),
      );
    }
    return decoration.copyWith(
      border: isHovering
          ? Border.all(color: Colors.lightBlueAccent, width: 2)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: isFaded ? 0.5 : 1.0,
        child: LongPressDraggable<DragItem>(
          data: DragItem(
            type: DragType.group,
            uuid: group.uuid,
            sourceGroupUuid: sourceGroupUuid,
          ),
          delay: onHoldSelect != null
              ? kSelectionDragHoldDelay
              : kLongPressTimeout,
          onDragStarted: onDragStarted,
          onDragUpdate: (details) =>
              DragAutoScroll.of(context)?.onDragUpdate(details.globalPosition),
          onDragEnd: (_) {
            DragAutoScroll.of(context)?.onDragEnd();
            onDragEnd?.call();
          },
          feedback: _buildDragFeedback(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              decoration: BoxDecoration(
                color: context.appColors.cardBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Icon(FontAwesomeIcons.folder),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.appColors.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Text(group.name),
                    ),
                  ),
                ],
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.4,
            child: Row(
              children: [
                Icon(FontAwesomeIcons.folder),
                SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: cardDecoration(context),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(group.name),
                    ),
                  ),
                ),
              ],
            ),
          ),
          child: HoldDetector(
            onHold: onHoldSelect,
            child: DragTarget<DragItem>(
              onWillAccept: (draggedItem) {
                if (draggedItem == null) return false;
                if (draggedItem.type == DragType.group &&
                    draggedItem.uuid == group.uuid) {
                  return false;
                }
                if (draggedItem.type == DragType.group &&
                    isDescendantOf(draggedItem.uuid, group.uuid)) {
                  return false;
                }
                return true;
              },
              onAccept: (draggedItem) {
                final currentGroupUuid = group.uuid;
                if (draggedItem.type == DragType.entry) {
                  onAccept(DragItem(
                    type: DragType.entry,
                    uuid: draggedItem.uuid,
                    sourceGroupUuid: draggedItem.sourceGroupUuid,
                  ));
                } else {
                  if (draggedItem.uuid == currentGroupUuid) return;
                  onAccept(DragItem(
                    type: DragType.group,
                    uuid: draggedItem.uuid,
                    sourceGroupUuid: draggedItem.sourceGroupUuid,
                  ));
                }
              },
              builder: (context, candidateData, rejectedData) {
                final isHovering = candidateData.isNotEmpty;
                return Row(
                  children: [
                    Icon(FontAwesomeIcons.folder),
                    SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: selectionEnabled ? onSelectionTap : onTap,
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          decoration: _itemDecoration(context, isHovering),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(group.name),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragFeedback({required Widget child}) {
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.85,
        child: Transform.scale(
          scale: 1.05,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

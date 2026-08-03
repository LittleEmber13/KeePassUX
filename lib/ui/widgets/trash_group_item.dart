import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/model/drag_item.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/widgets/custom_app_scroll.dart';
import 'package:keepassux/ui/widgets/hold_detector.dart';
import 'package:keepassux/ui/widgets/trash_actions_sheet.dart';

class TrashGroupItem extends StatelessWidget {
  const TrashGroupItem({
    required this.group,
    required this.sourceGroupUuid,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onRestore,
    required this.onDelete,
    this.rootGroup,
    this.selectionEnabled = false,
    this.isSelected = false,
    this.onSelectionTap,
    this.onHoldSelect,
    super.key,
  });

  final dynamic group;
  final String sourceGroupUuid;
  final VoidCallback? onTap;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final dynamic rootGroup;

  final bool selectionEnabled;
  final bool isSelected;
  final VoidCallback? onSelectionTap;
  final VoidCallback? onHoldSelect;

  void _showActionsSheet(BuildContext context) {
    TrashActionsSheet.show(
      context,
      name: group.name,
      isEntry: false,
      onRestore: onRestore,
      onDelete: onDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
          child: _buildDropTarget(context),
        ),
      ),
    );
  }

  Widget _buildDropTarget(BuildContext context) {
    return DragTarget<DragItem>(
      onWillAcceptWithDetails: (details) {
        final draggedItem = details.data;
        if (draggedItem.type == DragType.group &&
            draggedItem.uuid == group.uuid) {
          return false;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        final draggedItem = details.data;
        final currentGroupUuid = group.uuid;
        if (draggedItem.type == DragType.entry) {
          context.read<KeePassBloc>().add(
            MoveEntry(
              entryUuid: draggedItem.uuid,
              fromGroupUuid: draggedItem.sourceGroupUuid,
              toGroupUuid: currentGroupUuid,
            ),
          );
        } else {
          if (draggedItem.uuid == currentGroupUuid) return;
          context.read<KeePassBloc>().add(
            MoveGroup(
              groupUuid: draggedItem.uuid,
              fromGroupUuid: draggedItem.sourceGroupUuid,
              toGroupUuid: currentGroupUuid,
            ),
          );
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
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  decoration: cardDecoration(context).copyWith(
                    border: isHovering || isSelected
                        ? Border.all(
                            color: Colors.lightBlueAccent,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(group.name),
                  ),
                ),
              ),
            ),
            if (!selectionEnabled) ...[
              const SizedBox(width: 8),
              TrashOptionsButton(onTap: () => _showActionsSheet(context)),
            ],
          ],
        );
      },
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

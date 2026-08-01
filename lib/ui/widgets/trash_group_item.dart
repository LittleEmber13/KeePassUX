import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/model/drag_item.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/widgets/custom_app_scroll.dart';

class TrashGroupItem extends StatelessWidget {
  const TrashGroupItem({
    required this.group,
    required this.sourceGroupUuid,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onDelete,
    this.rootGroup,
    super.key,
  });

  final dynamic group;
  final String sourceGroupUuid;
  final VoidCallback? onTap;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;
  final VoidCallback onDelete;
  final dynamic rootGroup;

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("trash.delete")),
        content: Text(tr("trash.confirm_delete_group")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr("delete.cancel")),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: Text(
              tr("trash.delete"),
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ],
      ),
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
        child: DragTarget<DragItem>(
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
                    onTap: onTap,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      decoration: cardDecoration(context).copyWith(
                        border: isHovering
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
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showDeleteDialog(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.appColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: context.appColors.danger,
                      size: 20,
                    ),
                  ),
                ),
              ],
            );
          },
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

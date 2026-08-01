import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/model/db_entry.dart';
import 'package:keepassux/model/drag_item.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/widgets/custom_app_scroll.dart';
import 'package:keepassux/ui/widgets/entry_data.dart';
import 'package:keepassux/ui/widgets/kdbx_icon_widget.dart';
import 'package:keepassux/ui/widgets/loading_overlay.dart';

class TrashEntryItem extends StatelessWidget {
  const TrashEntryItem({
    required this.entry,
    required this.sourceGroupUuid,
    required this.onDragStarted,
    required this.onDragEnd,
    super.key,
  });

  final DbEntry entry;
  final String sourceGroupUuid;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("trash.delete")),
        content: Text(tr("trash.confirm_delete_entry")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr("delete.cancel")),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<KeePassBloc>().add(
                DeleteEntryPermanently(entryUuid: entry.uuid),
              );
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
          type: DragType.entry,
          uuid: entry.uuid,
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
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            child: _buildEntryItem(context),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: _buildEntryItem(context),
        ),
        child: InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              isScrollControlled: true,
              builder: (BuildContext ctx) {
                return SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: BlocBuilder<KeePassBloc, KeePassState>(
                    builder: (context, state) {
                      return Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: EntryData(entry: entry, showDelete: false),
                          ),
                          LoadingOverlay(isLoading: state is KeePassLoading),
                        ],
                      );
                    },
                  ),
                );
              },
            );
          },
          child: _buildEntryItem(context),
        ),
      ),
    );
  }

  Widget _buildEntryItem(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: cardDecoration(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  KDBXIconWidget(
                    icon: entry.icon,
                    customIconData: entry.customIconData,
                    size: 24,
                    color: Colors.lightBlueAccent,
                  ),
                  const SizedBox(width: 16),
                  Text(entry.label),
                ],
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

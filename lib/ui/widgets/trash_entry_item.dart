import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/model/db_entry.dart';
import 'package:keepassux/model/drag_item.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/widgets/custom_app_scroll.dart';
import 'package:keepassux/ui/widgets/entry_data.dart';
import 'package:keepassux/ui/widgets/hold_detector.dart';
import 'package:keepassux/ui/widgets/kdbx_icon_widget.dart';
import 'package:keepassux/ui/widgets/loading_overlay.dart';
import 'package:keepassux/ui/widgets/trash_actions_sheet.dart';

class TrashEntryItem extends StatelessWidget {
  const TrashEntryItem({
    required this.entry,
    required this.sourceGroupUuid,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onRestore,
    required this.onDelete,
    this.selectionEnabled = false,
    this.isSelected = false,
    this.onSelectionTap,
    this.onHoldSelect,
    super.key,
  });

  final DbEntry entry;
  final String sourceGroupUuid;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  final bool selectionEnabled;
  final bool isSelected;
  final VoidCallback? onSelectionTap;
  final VoidCallback? onHoldSelect;

  void _showActionsSheet(BuildContext context) {
    TrashActionsSheet.show(
      context,
      name: entry.label,
      isEntry: true,
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
          type: DragType.entry,
          uuid: entry.uuid,
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
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            child: _buildEntryItem(context),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: _buildEntryItem(context),
        ),
        child: HoldDetector(
          onHold: onHoldSelect,
          child: InkWell(
            onTap: selectionEnabled
                ? onSelectionTap
                : () => _showEntryDetails(context),
            child: _buildEntryItem(context),
          ),
        ),
      ),
    );
  }

  void _showEntryDetails(BuildContext context) {
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
  }

  Widget _buildEntryItem(BuildContext context) {
    var decoration = cardDecoration(context);
    if (isSelected) {
      decoration = decoration.copyWith(
        border: Border.all(color: Colors.lightBlueAccent, width: 2),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: decoration,
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
        if (!selectionEnabled) ...[
          const SizedBox(width: 8),
          TrashOptionsButton(onTap: () => _showActionsSheet(context)),
        ],
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

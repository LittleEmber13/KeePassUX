import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/services/selection_mode_controller.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/widgets/selection_bar.dart';

class MoveModeBar extends StatelessWidget {
  const MoveModeBar({required this.currentGroupUuid, super.key});

  final String? currentGroupUuid;

  void _onPaste(BuildContext context) {
    final controller = SelectionModeController.instance;
    final bloc = context.read<KeePassBloc>();
    final rootGroup = bloc.currentRoot;
    final target = currentGroupUuid ?? rootGroup?.uuid;
    if (target == null) return;

    for (final groupUuid in controller.groupUuids) {
      final selected = rootGroup?.findByUuid(groupUuid);
      if (groupUuid == target || selected?.findByUuid(target) != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr("move_mode.invalid_target")),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    final entryUuids = controller.entryUuids.toList();
    final groupUuids = controller.groupUuids.toList();
    if (controller.isCut) {
      bloc.add(
        MoveItems(
          entryUuids: entryUuids,
          groupUuids: groupUuids,
          toGroupUuid: target,
        ),
      );
    } else {
      bloc.add(
        CopyItems(
          entryUuids: entryUuids,
          groupUuids: groupUuids,
          toGroupUuid: target,
        ),
      );
    }
    controller.cancel();
  }

  void _confirmDelete(BuildContext context) {
    final controller = SelectionModeController.instance;
    final bloc = context.read<KeePassBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr("delete.title")),
        content: Text(tr("move_mode.confirm_delete")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr("delete.cancel")),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              bloc.add(
                DeleteItems(
                  entryUuids: controller.entryUuids.toList(),
                  groupUuids: controller.groupUuids.toList(),
                ),
              );
              controller.cancel();
            },
            child: Text(
              tr("delete.delete"),
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = SelectionModeController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SelectionBar(
          children: [
            if (controller.isSelecting) ...[
              SelectionBarAction(
                icon: Icons.content_copy,
                label: tr("move_mode.copy"),
                onTap: controller.hasSelection
                    ? () => controller.arm(SelectionAction.copy)
                    : null,
              ),
              SelectionBarAction(
                icon: Icons.content_cut,
                label: tr("move_mode.cut"),
                onTap: controller.hasSelection
                    ? () => controller.arm(SelectionAction.cut)
                    : null,
              ),
              SelectionBarAction(
                icon: Icons.delete_outline,
                label: tr("move_mode.delete"),
                onTap: controller.hasSelection
                    ? () => _confirmDelete(context)
                    : null,
              ),
            ] else ...[
              SelectionBarAction(
                icon: Icons.arrow_back,
                onTap: controller.disarm,
              ),
              SelectionBarAction(
                icon: Icons.content_paste,
                label: tr("move_mode.paste"),
                onTap: () => _onPaste(context),
              ),
            ],
          ],
        );
      },
    );
  }
}

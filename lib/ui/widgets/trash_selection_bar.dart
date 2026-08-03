import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/services/selection_mode_controller.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/widgets/selection_bar.dart';

class TrashSelectionBar extends StatelessWidget {
  const TrashSelectionBar({this.onRestore, super.key});

  final VoidCallback? onRestore;

  void _restore(BuildContext context) {
    final controller = SelectionModeController.instance;
    context.read<KeePassBloc>().add(
      RestoreItems(
        entryUuids: controller.entryUuids.toList(),
        groupUuids: controller.groupUuids.toList(),
      ),
    );
    controller.cancel();
    onRestore?.call();
  }

  void _confirmDelete(BuildContext context) {
    final controller = SelectionModeController.instance;
    final bloc = context.read<KeePassBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr("trash.delete")),
        content: Text(tr("trash.confirm_delete_items")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr("delete.cancel")),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              bloc.add(
                DeleteItemsPermanently(
                  entryUuids: controller.entryUuids.toList(),
                  groupUuids: controller.groupUuids.toList(),
                ),
              );
              controller.cancel();
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
    final controller = SelectionModeController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SelectionBar(
          children: [
            SelectionBarAction(
              icon: Icons.restore,
              label: tr("trash.restore"),
              onTap: controller.hasSelection ? () => _restore(context) : null,
            ),
            SelectionBarAction(
              icon: Icons.delete_forever,
              label: tr("trash.delete_short"),
              color: context.appColors.danger,
              onTap: controller.hasSelection
                  ? () => _confirmDelete(context)
                  : null,
            ),
          ],
        );
      },
    );
  }
}

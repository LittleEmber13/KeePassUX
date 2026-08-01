import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:keepassux/ui/theme/theme.dart';

class TrashOptionsButton extends StatelessWidget {
  const TrashOptionsButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.appColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.more_horiz,
          color: context.appColors.secondaryText,
          size: 20,
        ),
      ),
    );
  }
}

class TrashActionsSheet extends StatelessWidget {
  const TrashActionsSheet({
    required this.name,
    required this.isEntry,
    required this.onRestore,
    required this.onDelete,
    super.key,
  });

  final String name;
  final bool isEntry;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  static void show(
    BuildContext context, {
    required String name,
    required bool isEntry,
    required VoidCallback onRestore,
    required VoidCallback onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TrashActionsSheet(
        name: name,
        isEntry: isEntry,
        onRestore: onRestore,
        onDelete: onDelete,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr("trash.delete")),
        content: Text(
          isEntry
              ? tr("trash.confirm_delete_entry")
              : tr("trash.confirm_delete_group"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr("delete.cancel")),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onRestore();
                },
                icon: const Icon(Icons.restore),
                label: Text(
                  tr("trash.restore"),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.appColors.danger,
                  side: BorderSide(color: context.appColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  tr("trash.delete"),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

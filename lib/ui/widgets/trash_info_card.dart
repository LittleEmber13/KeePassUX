import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:keepassux/ui/theme/theme.dart';

class TrashInfoCard extends StatelessWidget {
  const TrashInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.appColors.infoCardBackground,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: context.appColors.cardShadow,
            blurRadius: 5,
            spreadRadius: 1,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInstruction(
              icon: Icons.info_outline,
              iconColor: context.appColors.secondaryText,
              text: tr("trash.info_content"),
            ),
            const SizedBox(height: 8),
            _buildInstruction(
              icon: Icons.more_horiz,
              iconColor: Colors.orange,
              text: tr("trash.info_options"),
            ),
            const SizedBox(height: 8),
            _buildInstruction(
              icon: Icons.delete_forever_outlined,
              iconColor: context.appColors.danger,
              text: tr("trash.info_permanent"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:keepassux/ui/theme/theme.dart';

class GroupAppBar extends StatelessWidget {
  const GroupAppBar({
    super.key,
    required this.onTapExit,
    required this.title,
    this.onTapEdit,
    this.onTapDelete,
    this.onTapMove,
    this.moveActive = false,
    bool? hideExit,
  }) : hideExit = hideExit ?? moveActive;

  final Function() onTapExit;
  final String title;
  final Function()? onTapEdit;
  final Function()? onTapDelete;
  final Function()? onTapMove;
  final bool moveActive;
  final bool hideExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          IgnorePointer(
            ignoring: hideExit,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: hideExit ? 0.0 : 1.0,
              child: InkWell(
                onTap: onTapExit,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.appColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: context.appColors.cardShadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTapMove != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onTapMove,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.appColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: context.appColors.cardShadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  moveActive ? Icons.close : FontAwesomeIcons.hand,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 20,
                ),
              ),
            ),
          ],
          if (onTapEdit != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onTapEdit,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.appColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: context.appColors.cardShadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.edit,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 20,
                ),
              ),
            ),
          ],
          if (onTapDelete != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onTapDelete,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.appColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: context.appColors.cardShadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 20,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

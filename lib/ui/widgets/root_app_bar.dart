import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:keepassux/ui/theme/theme.dart';

class RootAppBar extends StatelessWidget {
  const RootAppBar({
    super.key,
    required this.onTapExit,
    required this.isExit,
    required this.title,
    this.onTapDelete,
    this.onTapCloseSelection,
    this.selectionActive = false,
  });

  final Function() onTapExit;
  final bool isExit;
  final String title;
  final Function()? onTapDelete;

  final Function()? onTapCloseSelection;
  final bool selectionActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IgnorePointer(
          ignoring: selectionActive,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: selectionActive ? 0.0 : 1.0,
            child: InkWell(
              onTap: onTapExit,
              child: Container(
                decoration: cardDecoration(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: Icon(
                    isExit ? FeatherIcons.logOut : Icons.arrow_back,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                title,
                key: ValueKey(title),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        if (onTapCloseSelection != null) ...[
          SizedBox(width: 8),
          InkWell(
            onTap: onTapCloseSelection,
            child: Container(
              decoration: cardDecoration(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                child: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
        if (onTapDelete != null) ...[
          SizedBox(width: 8),
          InkWell(
            onTap: onTapDelete,
            child: Container(
              decoration: cardDecoration(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

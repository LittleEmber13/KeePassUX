import 'package:flutter/material.dart';
import 'package:keepassux/ui/theme/theme.dart';

class SelectionBar extends StatelessWidget {
  const SelectionBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Container(
          decoration: cardDecoration(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class SelectionBarAction extends StatelessWidget {
  const SelectionBarAction({
    required this.icon,
    required this.onTap,
    this.label,
    this.color,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onTap == null
        ? context.appColors.secondaryText
        : (color ?? Theme.of(context).colorScheme.onSurface);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: effectiveColor),
            if (label != null) ...[
              SizedBox(height: 4),
              Text(
                label!,
                style: TextStyle(color: effectiveColor, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:keepassux/model/alert_item.dart';
import 'package:keepassux/ui/theme/theme.dart';

class AlertStack extends StatefulWidget {
  const AlertStack({required this.alerts, this.onDismiss, super.key});

  final List<AlertItem> alerts;
  final Function(String alertId)? onDismiss;

  @override
  State<AlertStack> createState() => _AlertStackState();
}

class _AlertStackState extends State<AlertStack>
    with SingleTickerProviderStateMixin {
  static const double _peekOffset = 8.0;

  late AnimationController _controller;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(AlertStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dismissing && widget.alerts != oldWidget.alerts) {
      _dismissing = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasCurrent => widget.alerts.isNotEmpty;

  bool get _hasNext => widget.alerts.length > 1;

  bool get _hasAfterNext => widget.alerts.length > 2;

  void _dismiss() {
    if (!_hasCurrent || _controller.isAnimating || _dismissing) return;
    _dismissing = true;
    final alertId = widget.alerts.first.id;
    _controller.forward(from: 0.0).then((_) {
      widget.onDismiss?.call(alertId);
    });
  }

  Widget _buildAlertCard(
    BuildContext context,
    AlertItem alert, {
    VoidCallback? onClose,
  }) {
    return Container(
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    alert.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(alert.text),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCurrent) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final isActive = _controller.isAnimating || _dismissing;
        final nextTop = isActive ? t * (_hasAfterNext ? _peekOffset : 0.0) : 0.0;

        final nextCard = _hasNext
            ? Transform.scale(
                scale: isActive ? (0.95 + t * 0.05) : 0.95,
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: isActive ? (0.7 + t * 0.3) : 0.7,
                  child: _buildAlertCard(context, widget.alerts[1]),
                ),
              )
            : null;

        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          alignment: Alignment.topCenter,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (_hasAfterNext)
                Positioned(
                  top: isActive ? (_peekOffset - t * _peekOffset) : _peekOffset,
                  left: 0,
                  right: 0,
                  child: Transform.scale(
                    scale: 0.95,
                    alignment: Alignment.topCenter,
                    child: Opacity(
                      opacity: isActive ? (0.5 + t * 0.2) : 0.5,
                      child: _buildAlertCard(context, widget.alerts[2]),
                    ),
                  ),
                ),
              if (nextCard != null)
                isActive
                    ? Padding(
                        padding: EdgeInsets.only(top: nextTop),
                        child: nextCard,
                      )
                    : Positioned(
                        top: nextTop,
                        left: 0,
                        right: 0,
                        child: nextCard,
                      ),
              Padding(
                padding: EdgeInsets.only(top: _hasNext ? _peekOffset : 0.0),
                child: Opacity(
                  opacity: isActive ? (1.0 - t) : 1.0,
                  child: _buildAlertCard(
                    context,
                    widget.alerts.first,
                    onClose: _dismiss,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

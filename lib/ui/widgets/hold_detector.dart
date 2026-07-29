import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

const Duration kSelectionHoldDelay = Duration(milliseconds: 500);

const Duration kSelectionDragHoldDelay = Duration(milliseconds: 1000);

class HoldDetector extends StatefulWidget {
  const HoldDetector({
    required this.child,
    this.onHold,
    this.delay = kSelectionHoldDelay,
    super.key,
  });

  final Widget child;
  final VoidCallback? onHold;
  final Duration delay;

  @override
  State<HoldDetector> createState() => _HoldDetectorState();
}

class _HoldDetectorState extends State<HoldDetector> {
  Timer? _timer;
  int? _pointer;
  Offset _origin = Offset.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.onHold == null || _pointer != null) return;
    _pointer = event.pointer;
    _origin = event.position;
    _timer = Timer(widget.delay, _fire);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if ((event.position - _origin).distance > kTouchSlop) _reset();
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _reset();
  }

  void _fire() {
    _reset();
    widget.onHold?.call();
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _pointer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: widget.child,
    );
  }
}

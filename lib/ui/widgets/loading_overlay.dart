import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingOverlay extends StatefulWidget {
  const LoadingOverlay({super.key, required this.isLoading});

  final bool isLoading;

  static const showDelay = Duration(milliseconds: 500);
  static const fadeDuration = Duration(milliseconds: 250);

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> {
  bool _visible = false;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) _scheduleShow();
  }

  @override
  void didUpdateWidget(covariant LoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading == oldWidget.isLoading) return;
    if (widget.isLoading) {
      _scheduleShow();
    } else {
      _delayTimer?.cancel();
      if (_visible) setState(() => _visible = false);
    }
  }

  void _scheduleShow() {
    _delayTimer?.cancel();
    _delayTimer = Timer(LoadingOverlay.showDelay, () {
      if (mounted && widget.isLoading) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: LoadingOverlay.fadeDuration,
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: Center(
            child: Lottie.asset(
              'assets/animations/loading_keyhole_spinner.json',
              width: 96,
              height: 96,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:keepassux/ui/theme/theme.dart';

class DragAutoScroll extends InheritedWidget {
  const DragAutoScroll({
    required this.onDragUpdate,
    required this.onDragEnd,
    required super.child,
    super.key,
  });

  final void Function(Offset globalPosition) onDragUpdate;
  final VoidCallback onDragEnd;

  static DragAutoScroll? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DragAutoScroll>();

  @override
  bool updateShouldNotify(DragAutoScroll oldWidget) => false;
}

class CustomAppScroll extends StatefulWidget {
  const CustomAppScroll({
    required this.children,
    this.horizontalPadding = 24,
    super.key,
  });

  final List<Widget> children;
  final double horizontalPadding;

  @override
  State<CustomAppScroll> createState() => _CustomAppScrollState();
}

class _CustomAppScrollState extends State<CustomAppScroll>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _viewportKey = GlobalKey();

  bool _exceedsHeight = false;

  static const double _hotZone = 90;
  static const double _maxSpeed = 1100;

  late final Ticker _ticker;
  double _autoScrollVelocity = 0;
  Duration? _lastTick;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    final double dt =
        _lastTick == null ? 1 / 60 : (elapsed - _lastTick!).inMicroseconds / 1e6;
    _lastTick = elapsed;

    if (_autoScrollVelocity == 0 || !_scrollController.hasClients) return;

    final position = _scrollController.position;
    final double newOffset = (_scrollController.offset + _autoScrollVelocity * dt)
        .clamp(0.0, position.maxScrollExtent);
    if (newOffset != _scrollController.offset) {
      _scrollController.jumpTo(newOffset);
    }
  }

  void _handleDragUpdate(Offset globalPosition) {
    final RenderBox? box =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _stopAutoScroll();
      return;
    }

    final Rect rect = box.localToGlobal(Offset.zero) & box.size;
    final double y = globalPosition.dy;
    double velocity = 0;

    if (y < rect.top + _hotZone) {
      final double intensity =
          ((rect.top + _hotZone - y) / _hotZone).clamp(0.0, 1.0);
      velocity = -_maxSpeed * intensity;
    } else if (y > rect.bottom - _hotZone) {
      final double intensity =
          ((y - (rect.bottom - _hotZone)) / _hotZone).clamp(0.0, 1.0);
      velocity = _maxSpeed * intensity;
    }

    _autoScrollVelocity = velocity;
    if (velocity != 0 && !_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    } else if (velocity == 0 && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _stopAutoScroll() {
    _autoScrollVelocity = 0;
    _lastTick = null;
    if (_ticker.isActive) _ticker.stop();
  }

  void _checkIfExceedsHeight(BoxConstraints constraints) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? contentBox =
          _contentKey.currentContext?.findRenderObject() as RenderBox?;
      if (contentBox != null) {
        final double contentHeight = contentBox.size.height;
        final double maxHeight = constraints.maxHeight;
        final bool newValue = contentHeight > maxHeight;
        if (newValue != _exceedsHeight) {
          setState(() {
            _exceedsHeight = newValue;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DragAutoScroll(
        onDragUpdate: _handleDragUpdate,
        onDragEnd: _stopAutoScroll,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _checkIfExceedsHeight(constraints);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
              child: NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (_) {
                  _checkIfExceedsHeight(constraints);
                  return false;
                },
                child: Stack(
                  key: _viewportKey,
                  alignment: Alignment.topRight,
                  children: [
                    if (_exceedsHeight)
                      Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: 8,
                              decoration: BoxDecoration(
                                color: context.appColors.secondaryText.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ],
                      ),
                    RawScrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      thickness: 8.0,
                      trackVisibility: false,
                      thumbColor: context.appColors.cardBackground,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(99)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(right: _exceedsHeight ? 24 : 0),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.vertical,
                          child: SizeChangedLayoutNotifier(
                            child: Column(
                              key: _contentKey,
                              children: [...widget.children],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

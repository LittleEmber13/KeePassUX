class AutoLockController {
  AutoLockController({this.timeout = const Duration(minutes: 5)});

  static const Duration checkInterval = Duration(seconds: 15);

  final Duration timeout;

  DateTime? _lastInteraction;

  bool get isArmed => _lastInteraction != null;

  void arm([DateTime? now]) {
    _lastInteraction = now ?? DateTime.now();
  }

  void disarm() {
    _lastInteraction = null;
  }

  void registerInteraction([DateTime? now]) {
    if (_lastInteraction == null) return;
    _lastInteraction = now ?? DateTime.now();
  }

  bool isExpired([DateTime? now]) {
    final last = _lastInteraction;
    if (last == null) return false;
    return (now ?? DateTime.now()).difference(last) >= timeout;
  }
}

final AutoLockController autoLock = AutoLockController();

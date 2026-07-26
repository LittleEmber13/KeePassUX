import 'package:flutter/foundation.dart';

enum SelectionPhase { inactive, selecting, pasting }

enum SelectionAction { none, copy, cut }

class SelectionModeController extends ChangeNotifier {
  SelectionModeController._();

  static final SelectionModeController instance = SelectionModeController._();

  SelectionPhase _phase = SelectionPhase.inactive;
  SelectionAction _action = SelectionAction.none;
  String? _sourceGroupUuid;
  final Set<String> _entryUuids = {};
  final Set<String> _groupUuids = {};

  SelectionPhase get phase => _phase;
  SelectionAction get action => _action;
  bool get isActive => _phase != SelectionPhase.inactive;
  bool get isSelecting => _phase == SelectionPhase.selecting;
  bool get isPasting => _phase == SelectionPhase.pasting;
  bool get isCut => _action == SelectionAction.cut;
  bool get hasSelection => _entryUuids.isNotEmpty || _groupUuids.isNotEmpty;
  String? get sourceGroupUuid => _sourceGroupUuid;
  Set<String> get entryUuids => Set.unmodifiable(_entryUuids);
  Set<String> get groupUuids => Set.unmodifiable(_groupUuids);

  bool isEntrySelected(String uuid) => _entryUuids.contains(uuid);
  bool isGroupSelected(String uuid) => _groupUuids.contains(uuid);

  void start(String sourceGroupUuid) {
    _phase = SelectionPhase.selecting;
    _action = SelectionAction.none;
    _sourceGroupUuid = sourceGroupUuid;
    _entryUuids.clear();
    _groupUuids.clear();
    notifyListeners();
  }

  void toggleEntry(String uuid) {
    if (!_entryUuids.remove(uuid)) {
      _entryUuids.add(uuid);
    }
    notifyListeners();
  }

  void toggleGroup(String uuid) {
    if (!_groupUuids.remove(uuid)) {
      _groupUuids.add(uuid);
    }
    notifyListeners();
  }

  void arm(SelectionAction action) {
    if (!hasSelection || action == SelectionAction.none) return;
    _action = action;
    _phase = SelectionPhase.pasting;
    notifyListeners();
  }

  void disarm() {
    if (!isPasting) return;
    _action = SelectionAction.none;
    _phase = SelectionPhase.selecting;
    notifyListeners();
  }

  void cancel() {
    _phase = SelectionPhase.inactive;
    _action = SelectionAction.none;
    _sourceGroupUuid = null;
    _entryUuids.clear();
    _groupUuids.clear();
    notifyListeners();
  }
}

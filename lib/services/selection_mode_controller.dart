import 'package:flutter/foundation.dart';

enum SelectionPhase { inactive, selecting, pasting }

enum SelectionAction { none, copy, cut }

class SelectionModeController extends ChangeNotifier {
  SelectionModeController._();

  static final SelectionModeController instance = SelectionModeController._();

  SelectionPhase _phase = SelectionPhase.inactive;
  SelectionAction _action = SelectionAction.none;
  String? _sourceGroupUuid;
  bool _isTrash = false;
  final Set<String> _entryUuids = {};
  final Set<String> _groupUuids = {};

  String? _activationUuid;

  SelectionPhase get phase => _phase;
  SelectionAction get action => _action;
  bool get isActive => _phase != SelectionPhase.inactive;
  bool get isSelecting => _phase == SelectionPhase.selecting;
  bool get isPasting => _phase == SelectionPhase.pasting;
  bool get isCut => _action == SelectionAction.cut;
  bool get isTrash => _isTrash;
  bool get hasSelection => _entryUuids.isNotEmpty || _groupUuids.isNotEmpty;
  String? get sourceGroupUuid => _sourceGroupUuid;
  Set<String> get entryUuids => Set.unmodifiable(_entryUuids);
  Set<String> get groupUuids => Set.unmodifiable(_groupUuids);

  bool isEntrySelected(String uuid) => _entryUuids.contains(uuid);
  bool isGroupSelected(String uuid) => _groupUuids.contains(uuid);

  void start(
    String sourceGroupUuid, {
    String? entryUuid,
    String? groupUuid,
    bool isTrash = false,
  }) {
    _phase = SelectionPhase.selecting;
    _action = SelectionAction.none;
    _sourceGroupUuid = sourceGroupUuid;
    _isTrash = isTrash;
    _entryUuids.clear();
    _groupUuids.clear();
    if (entryUuid != null) _entryUuids.add(entryUuid);
    if (groupUuid != null) _groupUuids.add(groupUuid);
    _activationUuid = entryUuid ?? groupUuid;
    notifyListeners();
  }

  void toggleEntry(String uuid) {
    if (_consumeActivation(uuid)) return;
    if (!_entryUuids.remove(uuid)) {
      _entryUuids.add(uuid);
    } else if (!hasSelection) {
      cancel();
      return;
    }
    notifyListeners();
  }

  void toggleGroup(String uuid) {
    if (_consumeActivation(uuid)) return;
    if (!_groupUuids.remove(uuid)) {
      _groupUuids.add(uuid);
    } else if (!hasSelection) {
      cancel();
      return;
    }
    notifyListeners();
  }

  bool _consumeActivation(String uuid) {
    if (_activationUuid == null) return false;
    final isActivationItem = _activationUuid == uuid;
    _activationUuid = null;
    return isActivationItem;
  }

  void arm(SelectionAction action) {
    if (!hasSelection || action == SelectionAction.none) return;
    _activationUuid = null;
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
    _isTrash = false;
    _activationUuid = null;
    _entryUuids.clear();
    _groupUuids.clear();
    notifyListeners();
  }
}

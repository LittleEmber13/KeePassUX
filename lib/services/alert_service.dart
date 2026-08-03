import 'package:easy_localization/easy_localization.dart';
import 'package:keepassux/model/alert_item.dart';
import 'package:keepassux/model/db_group.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertService {
  static final bool persistDismissals = false;

  static const Map<String, String> _dismissedKeys = {
    'empty': 'alert_dismissed_empty',
    'selection': 'alert_dismissed_selection',
    'drag': 'alert_dismissed_drag',
    'biometric': 'alert_dismissed_biometric',
    'autofill': 'alert_dismissed_autofill',
    'feedback': 'alert_dismissed_feedback',
  };

  static final Set<String> _sessionDismissed = <String>{};

  bool _isDismissed(SharedPreferences prefs, String id) {
    if (_sessionDismissed.contains(id)) return true;
    if (!persistDismissals) return false;
    final key = _dismissedKeys[id];
    if (key == null) return false;
    return prefs.getBool(key) ?? false;
  }

  Future<List<AlertItem>> getAlerts({
    required bool hasBiometrics,
    required bool biometricLoginEnabled,
    required DbGroup? rootGroup,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final alerts = <AlertItem>[];

    void add(String id) {
      if (_isDismissed(prefs, id)) return;
      alerts.add(AlertItem(
        id: id,
        title: tr("alerts.${id}_title"),
        text: tr("alerts.${id}_text"),
      ));
    }

    if (rootGroup != null &&
        rootGroup.entries.isEmpty &&
        rootGroup.groups.isEmpty) {
      add('empty');
    }

    add('selection');
    add('drag');

    if (hasBiometrics && !biometricLoginEnabled) {
      add('biometric');
    }

    add('autofill');
    add('feedback');

    return alerts;
  }

  Future<void> dismissAlert(String id) async {
    _sessionDismissed.add(id);
    if (!persistDismissals) return;
    final key = _dismissedKeys[id];
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }
}

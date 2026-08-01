import 'package:easy_localization/easy_localization.dart';
import 'package:keepassux/model/alert_item.dart';
import 'package:keepassux/model/db_group.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertService {
  static const _biometricDismissedKey = 'alert_dismissed_biometric';
  static const _dragDismissedKey = 'alert_dismissed_drag';

  Future<List<AlertItem>> getAlerts({
    required bool hasBiometrics,
    required bool biometricLoginEnabled,
    required DbGroup? rootGroup,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final alerts = <AlertItem>[];

    if (hasBiometrics && !biometricLoginEnabled) {
      final dismissed = prefs.getBool(_biometricDismissedKey) ?? false;
      if (!dismissed) {
        alerts.add(AlertItem(
          id: 'biometric',
          title: tr("alerts.biometric_title"),
          text: tr("alerts.biometric_text"),
        ));
      }
    }

    final dragDismissed = prefs.getBool(_dragDismissedKey) ?? false;
    if (!dragDismissed) {
      alerts.add(AlertItem(
        id: 'drag',
        title: tr("alerts.drag_title"),
        text: tr("alerts.drag_text"),
      ));
    }

    if (rootGroup != null &&
        rootGroup.entries.isEmpty &&
        rootGroup.groups.isEmpty) {
      alerts.add(AlertItem(
        id: 'empty',
        title: tr("alerts.empty_title"),
        text: tr("alerts.empty_text"),
      ));
    }

    return alerts;
  }

  Future<void> dismissAlert(String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == 'biometric') {
      await prefs.setBool(_biometricDismissedKey, true);
    } else if (id == 'drag') {
      await prefs.setBool(_dragDismissedKey, true);
    }
  }
}

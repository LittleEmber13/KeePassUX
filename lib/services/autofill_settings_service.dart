import 'package:flutter_autofill_service/flutter_autofill_service.dart';

class AutofillSettingsService {
  Future<bool> get isSupported => AutofillService().hasAutofillServicesSupport;

  Future<bool> get isEnabled async =>
      (await AutofillService().status) == AutofillServiceStatus.enabled;

  Future<bool> requestEnable() => AutofillService().requestSetAutofillService();

  Future<void> disable() => AutofillService().disableAutofillServices();
}

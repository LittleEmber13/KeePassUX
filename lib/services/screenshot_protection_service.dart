import 'dart:io';

import 'package:flutter/services.dart';

class ScreenshotProtectionService {
  static const _channel = MethodChannel('com.cinderfall.keepassux/saf');

  Future<void> enableProtection() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('setFlagSecure', {'enabled': true});
    }
  }

  Future<void> disableProtection() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('setFlagSecure', {'enabled': false});
    }
  }
}

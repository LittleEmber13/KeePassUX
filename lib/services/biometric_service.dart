import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  static const _secureStorage = FlutterSecureStorage();

  Future<bool> canAuthenticate() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasSavedPassword(String uri) async {
    if (uri.isEmpty) return false;
    final saved = await _secureStorage.read(key: 'kdbx_password_$uri');
    return saved != null && saved.isNotEmpty;
  }

  Future<String?> authenticateAndRetrievePassword(String uri) async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Autentícate para abrir tu base de datos',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (!authenticated) return null;

      return await _secureStorage.read(key: 'kdbx_password_$uri');
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> savePassword(String uri, String password) async {
    await _secureStorage.write(key: 'kdbx_password_$uri', value: password);
  }

  Future<void> deleteSavedPassword(String uri) async {
    await _secureStorage.delete(key: 'kdbx_password_$uri');
  }
}

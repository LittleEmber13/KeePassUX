import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepassux/services/biometric_service.dart';

const String _uri = 'content://test/vault';
const String _key = 'kdbx_password_$_uri';
const MethodChannel _channel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> store;
  late BiometricService service;

  setUp(() {
    store = <String, String>{};
    service = BiometricService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          final arguments = (call.arguments as Map).cast<String, dynamic>();
          switch (call.method) {
            case 'write':
              store[arguments['key'] as String] = arguments['value'] as String;
              return null;
            case 'read':
              return store[arguments['key'] as String];
            case 'delete':
              store.remove(arguments['key'] as String);
              return null;
            case 'containsKey':
              return store.containsKey(arguments['key'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('a rejected biometric preference never stores the master password',
      () async {
    await service.syncSavedPassword(_uri, enabled: false, password: 'master');

    expect(store, isEmpty);
    expect(await service.hasSavedPassword(_uri), isFalse);
  });

  test('an accepted biometric preference stores the master password', () async {
    await service.syncSavedPassword(_uri, enabled: true, password: 'master');

    expect(store[_key], 'master');
    expect(await service.hasSavedPassword(_uri), isTrue);
  });

  test('turning the preference off deletes an already stored password',
      () async {
    await service.syncSavedPassword(_uri, enabled: true, password: 'master');
    await service.syncSavedPassword(_uri, enabled: false, password: 'master');

    expect(store.containsKey(_key), isFalse);
    expect(await service.hasSavedPassword(_uri), isFalse);
  });

  test('turning the preference on without a session password keeps storage '
      'untouched', () async {
    await service.syncSavedPassword(_uri, enabled: true, password: null);
    await service.syncSavedPassword(_uri, enabled: true, password: '');

    expect(store, isEmpty);
  });

  test('an empty uri is ignored', () async {
    await service.syncSavedPassword('', enabled: true, password: 'master');

    expect(store, isEmpty);
  });
}

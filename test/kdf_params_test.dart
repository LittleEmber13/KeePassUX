import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kdbx/kdbx.dart';
import 'package:kdbx/src/kdbx_var_dictionary.dart';
import 'package:kdbx/src/utils/byte_utils.dart';
import 'package:keepassux/utils/kdbx_isolate.dart';

VarDictionary _initialParams() {
  return VarDictionary([
    KdfField.uuid.item(
      KeyEncrypterKdf.kdfUuidForType(KdfType.Argon2).toBytes(),
    ),
    KdfField.salt.item(Uint8List.fromList(List.filled(32, 7))),
    KdfField.version.item(0x13),
    KdfField.memory.item(64 * 1024 * 1024),
    KdfField.iterations.item(20),
    KdfField.parallelism.item(2),
  ]);
}

VarDictionary _roundTrip(VarDictionary dict) {
  return VarDictionary.read(ReaderHelper(dict.write()));
}

void main() {
  test('KdfField.write mutations are lost on serialization (upstream bug)',
      () {
    final params = _initialParams();
    KdfField.memory.write(params, 32 * 1024 * 1024);
    expect(KdfField.memory.read(params), 32 * 1024 * 1024);
    expect(KdfField.memory.read(_roundTrip(params)), 64 * 1024 * 1024);
  });

  test('argon2KdfParams survives the serialization round trip', () {
    final updated = argon2KdfParams(
      _initialParams(),
      memoryBytes: 32 * 1024 * 1024,
      iterations: 5,
      parallelism: 4,
    );
    final reread = _roundTrip(updated);

    expect(KdfField.memory.read(reread), 32 * 1024 * 1024);
    expect(KdfField.iterations.read(reread), 5);
    expect(KdfField.parallelism.read(reread), 4);
    expect(KdfField.version.read(reread), 0x13);
    expect(KdfField.salt.read(reread), List.filled(32, 7));
    expect(KeyEncrypterKdf.kdfTypeFor(reread), KdfType.Argon2);
  });
}

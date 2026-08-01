import 'dart:typed_data';

import 'package:argon2_ffi_base/argon2_ffi_base.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepassux/utils/cached_argon2.dart';

class _CountingArgon2 extends Argon2 {
  int calls = 0;

  @override
  bool get isFfi => false;

  @override
  bool get isImplemented => true;

  @override
  Uint8List argon2(Argon2Arguments args) {
    calls++;
    final sum =
        args.key.fold<int>(0, (a, b) => a + b) +
        args.salt.fold<int>(0, (a, b) => a + b) +
        args.memory +
        args.iterations;
    return Uint8List.fromList(List.filled(32, sum % 256));
  }

  @override
  Future<Uint8List> argon2Async(Argon2Arguments args) async => argon2(args);
}

Argon2Arguments _args({
  List<int> key = const [1, 2, 3],
  List<int> salt = const [9, 9, 9],
  int memory = 65536,
  int iterations = 3,
  int parallelism = 1,
}) {
  return Argon2Arguments(
    Uint8List.fromList(key),
    Uint8List.fromList(salt),
    memory,
    iterations,
    32,
    parallelism,
    0,
    0x13,
  );
}

void main() {
  test('repeated derivation with same arguments hits the cache', () async {
    final inner = _CountingArgon2();
    final cached = CachedArgon2(inner);

    final first = await cached.argon2Async(_args());
    final second = await cached.argon2Async(_args());

    expect(inner.calls, 1);
    expect(second, first);
  });

  test('changing password recomputes', () async {
    final inner = _CountingArgon2();
    final cached = CachedArgon2(inner);

    await cached.argon2Async(_args(key: [1, 2, 3]));
    await cached.argon2Async(_args(key: [4, 5, 6]));

    expect(inner.calls, 2);
  });

  test('changing salt or KDF parameters recomputes', () async {
    final inner = _CountingArgon2();
    final cached = CachedArgon2(inner);

    await cached.argon2Async(_args());
    await cached.argon2Async(_args(salt: [1, 1, 1]));
    await cached.argon2Async(_args(salt: [1, 1, 1], memory: 32768));
    await cached.argon2Async(_args(salt: [1, 1, 1], memory: 32768));

    expect(inner.calls, 3);
  });

  test('cached result is a defensive copy', () async {
    final inner = _CountingArgon2();
    final cached = CachedArgon2(inner);

    final first = await cached.argon2Async(_args());
    first[0] = first[0] ^ 0xFF;
    final second = await cached.argon2Async(_args());

    expect(inner.calls, 1);
    expect(second[0], isNot(first[0]));
  });
}

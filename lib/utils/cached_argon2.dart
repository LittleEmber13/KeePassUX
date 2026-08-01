import 'dart:typed_data';

import 'package:argon2_ffi_base/argon2_ffi_base.dart';
import 'package:collection/collection.dart';

class CachedArgon2 extends Argon2 {
  CachedArgon2(this._inner);

  final Argon2 _inner;

  Argon2Arguments? _lastArgs;
  Uint8List? _lastResult;

  static const _bytesEq = ListEquality<int>();

  @override
  bool get isFfi => _inner.isFfi;

  @override
  bool get isImplemented => _inner.isImplemented;

  bool _sameArgs(Argon2Arguments a, Argon2Arguments b) =>
      a.memory == b.memory &&
      a.iterations == b.iterations &&
      a.parallelism == b.parallelism &&
      a.length == b.length &&
      a.type == b.type &&
      a.version == b.version &&
      _bytesEq.equals(a.key, b.key) &&
      _bytesEq.equals(a.salt, b.salt);

  Uint8List? _lookup(Argon2Arguments args) {
    final last = _lastArgs;
    if (last != null && _sameArgs(last, args)) {
      return Uint8List.fromList(_lastResult!);
    }
    return null;
  }

  void _store(Argon2Arguments args, Uint8List result) {
    _lastArgs = Argon2Arguments(
      Uint8List.fromList(args.key),
      Uint8List.fromList(args.salt),
      args.memory,
      args.iterations,
      args.length,
      args.parallelism,
      args.type,
      args.version,
    );
    _lastResult = Uint8List.fromList(result);
  }

  @override
  Uint8List argon2(Argon2Arguments args) {
    final cached = _lookup(args);
    if (cached != null) return cached;
    final result = _inner.argon2(args);
    _store(args, result);
    return result;
  }

  @override
  Future<Uint8List> argon2Async(Argon2Arguments args) async {
    final cached = _lookup(args);
    if (cached != null) return cached;
    final result = await _inner.argon2Async(args);
    _store(args, result);
    return result;
  }
}

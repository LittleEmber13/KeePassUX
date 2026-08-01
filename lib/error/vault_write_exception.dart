class VaultWriteException implements Exception {
  VaultWriteException(this.message, {required this.rolledBack});

  final String message;
  final bool rolledBack;

  @override
  String toString() => 'VaultWriteException($message, rolledBack: $rolledBack)';
}

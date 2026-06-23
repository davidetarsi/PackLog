/// Famiglia di eccezioni legate alla cifratura del DB locale.
abstract class EncryptionException implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const EncryptionException(
    this.message, {
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() =>
      '$runtimeType: $message'
      '${originalError != null ? ' (${originalError.toString()})' : ''}';
}

/// Impossibile leggere/scrivere la passphrase nel secure storage.
/// Non recuperabile lato app: l'utente deve reinstallare o ripristinare via cloud sync.
class PassphraseUnavailableException extends EncryptionException {
  const PassphraseUnavailableException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

/// La migrazione plaintext → encrypted è fallita.
class EncryptionMigrationException extends EncryptionException {
  const EncryptionMigrationException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

/// Impossibile aprire il DB cifrato (es. passphrase errata, file corrotto).
class EncryptedDatabaseOpenException extends EncryptionException {
  const EncryptedDatabaseOpenException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

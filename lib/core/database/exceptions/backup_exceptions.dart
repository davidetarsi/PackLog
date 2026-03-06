library;

/// Custom exceptions per operazioni di backup e restore del database.
/// 
/// Fornisce exception specifiche per ogni tipo di fallimento,
/// permettendo una gestione degli errori più granulare e user-friendly.

/// Base exception per tutte le operazioni di backup.
abstract class BackupException implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const BackupException(
    this.message, {
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'BackupException: $message'
      '${originalError != null ? ' (${originalError.toString()})' : ''}';
}

/// Exception lanciata quando l'export del database fallisce.
class ExportFailedException extends BackupException {
  const ExportFailedException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() => 'ExportFailedException: $message'
      '${originalError != null ? ' (${originalError.toString()})' : ''}';
}

/// Exception lanciata quando l'import del database fallisce.
class ImportFailedException extends BackupException {
  const ImportFailedException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() => 'ImportFailedException: $message'
      '${originalError != null ? ' (${originalError.toString()})' : ''}';
}

/// Exception lanciata quando la validazione del file di backup fallisce.
class ImportValidationException extends BackupException {
  const ImportValidationException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() => 'ImportValidationException: $message'
      '${originalError != null ? ' (${originalError.toString()})' : ''}';
}

/// Exception lanciata quando il database non può essere chiuso correttamente.
class DatabaseCloseException extends BackupException {
  const DatabaseCloseException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() => 'DatabaseCloseException: $message'
      '${originalError != null ? ' (${originalError.toString()})' : ''}';
}

/// Exception lanciata quando il rollback del backup fallisce.
/// Questa è l'exception più critica perché significa che siamo in uno stato inconsistente.
class BackupRollbackException extends BackupException {
  const BackupRollbackException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() => 'BackupRollbackException: $message'
      '${originalError != null ? ' (${originalError.toString()})' : ''}';
}

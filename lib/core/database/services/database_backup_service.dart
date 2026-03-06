import 'dart:io';

/// Abstract interface per servizi di backup e restore del database.
/// 
/// Definisce il contratto per operazioni di export/import del database,
/// permettendo diverse implementazioni (SQLite fisica, JSON serialization, cloud, ecc).
abstract interface class DatabaseBackupService {
  /// Esporta il database corrente in un file.
  /// 
  /// **Parametri:**
  /// - [destinationPath]: Percorso completo dove salvare il file esportato
  /// 
  /// **Returns:**
  /// - [File]: Il file esportato
  /// 
  /// **Throws:**
  /// - [ExportFailedException]: Se l'export fallisce per qualsiasi motivo
  /// - [DatabaseCloseException]: Se il database non può essere chiuso
  Future<File> exportData(String destinationPath);

  /// Importa un database da un file, sostituendo quello corrente.
  /// 
  /// **IMPORTANTE**: Questa operazione è distruttiva!
  /// - Sovrascrive completamente il database corrente
  /// - Deve essere chiamato solo dopo aver creato un safety backup
  /// - Deve validare il file prima dell'import
  /// 
  /// **Parametri:**
  /// - [sourcePath]: Percorso completo del file da importare
  /// 
  /// **Returns:**
  /// - [void]: Completa silenziosamente se successful
  /// 
  /// **Throws:**
  /// - [ImportValidationException]: Se il file non è un database SQLite valido
  /// - [ImportFailedException]: Se l'import fallisce
  /// - [DatabaseCloseException]: Se il database non può essere chiuso
  Future<void> importData(String sourcePath);

  /// Valida che un file sia un database SQLite valido.
  /// 
  /// **Parametri:**
  /// - [filePath]: Percorso del file da validare
  /// 
  /// **Returns:**
  /// - [bool]: true se il file è un database SQLite valido e non corrotto
  Future<bool> validateDatabaseFile(String filePath);
}

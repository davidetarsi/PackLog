import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database.dart';
import '../exceptions/backup_exceptions.dart';
import 'database_backup_service.dart';

/// Implementazione concreta di [DatabaseBackupService] per SQLite.
/// 
/// Gestisce l'export e import del file SQLite fisico, rispettando:
/// - **WAL (Write-Ahead Logging)**: Chiude sempre il DB prima di operazioni sul file
/// - **Clean Wipe**: Elimina .sqlite, .sqlite-wal, .sqlite-shm prima di import
/// - **Validation**: Verifica che il file sia un database SQLite valido
/// 
/// **CRITICAL**: Questa classe NON gestisce l'invalidazione del provider.
/// È responsabilità del chiamante (BackupController) invalidare [databaseProvider]
/// dopo import/restore per ricreare una connessione fresca.
class SqliteBackupService implements DatabaseBackupService {
  static const String _dbFileName = 'stuff_tracker.db';
  
  final AppDatabase _database;

  const SqliteBackupService(this._database);

  /// Ottiene il percorso del file database principale
  Future<String> _getDatabasePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, _dbFileName);
  }

  /// Ottiene tutti i file associati al database (main, WAL, SHM)
  Future<List<String>> _getAllDatabaseFilePaths() async {
    final dbPath = await _getDatabasePath();
    return [
      dbPath,                   // db.sqlite
      '$dbPath-wal',           // db.sqlite-wal (Write-Ahead Log)
      '$dbPath-shm',           // db.sqlite-shm (Shared Memory)
    ];
  }

  /// Chiude il database e attende che tutte le operazioni in sospeso siano completate.
  /// 
  /// **CRITICAL**: Questo flush il WAL al file principale e rilascia tutti i lock.
  Future<void> _closeDatabaseSafely() async {
    try {
      debugPrint('[SqliteBackup] 🔒 Chiusura database in corso...');
      debugPrint('[SqliteBackup]   - Flushing WAL to main file...');
      debugPrint('[SqliteBackup]   - Rilascio lock...');
      await _database.close();
      debugPrint('[SqliteBackup] ✅ Database chiuso correttamente');
    } catch (e, stack) {
      debugPrint('[SqliteBackup] ❌ Impossibile chiudere database: $e');
      throw DatabaseCloseException(
        'Impossibile chiudere il database',
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  @override
  Future<File> exportData(String destinationPath) async {
    try {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('[SqliteBackup] 📤 INIZIO EXPORT');
      debugPrint('[SqliteBackup] 📂 Destinazione: $destinationPath');
      debugPrint('═══════════════════════════════════════════════════');

      // STEP 1: Chiudi il database per flusare il WAL
      debugPrint('[SqliteBackup] ➤ STEP 1: Chiusura database...');
      await _closeDatabaseSafely();
      debugPrint('[SqliteBackup] ✅ Database chiuso, WAL flushed');

      // STEP 2: Ottieni il percorso del file database principale
      debugPrint('');
      debugPrint('[SqliteBackup] ➤ STEP 2: Verifica file sorgente...');
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);
      debugPrint('[SqliteBackup] 📂 Path DB: $dbPath');

      // STEP 3: Verifica che il database esista
      if (!await dbFile.exists()) {
        debugPrint('[SqliteBackup] ❌ File database non trovato');
        throw ExportFailedException(
          'File database non trovato: $dbPath',
        );
      }
      
      final sourceStat = await dbFile.stat();
      debugPrint('[SqliteBackup] ✅ File trovato (${sourceStat.size} bytes)');

      // STEP 4: Verifica che il database sia valido
      debugPrint('');
      debugPrint('[SqliteBackup] ➤ STEP 3: Validazione database...');
      final isValid = await validateDatabaseFile(dbPath);
      if (!isValid) {
        debugPrint('[SqliteBackup] ❌ Database corrotto o non valido');
        throw ExportFailedException(
          'Il database da esportare non è valido o è corrotto',
        );
      }
      debugPrint('[SqliteBackup] ✅ Database valido (SQLite format 3)');

      // STEP 5: Copia il file database alla destinazione
      debugPrint('');
      debugPrint('[SqliteBackup] ➤ STEP 4: Copia file...');
      final exportedFile = await dbFile.copy(destinationPath);
      debugPrint('[SqliteBackup] ✅ File copiato');

      // STEP 6: Verifica che il file esportato esista e abbia dimensione > 0
      debugPrint('');
      debugPrint('[SqliteBackup] ➤ STEP 5: Verifica file esportato...');
      if (!await exportedFile.exists()) {
        debugPrint('[SqliteBackup] ❌ File esportato non trovato');
        throw ExportFailedException(
          'File esportato non creato correttamente',
        );
      }

      final stat = await exportedFile.stat();
      if (stat.size == 0) {
        debugPrint('[SqliteBackup] ❌ File esportato vuoto');
        // Cleanup file vuoto
        await exportedFile.delete();
        throw ExportFailedException(
          'File esportato è vuoto',
        );
      }

      debugPrint('[SqliteBackup] ✅ File esportato valido (${stat.size} bytes)');
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('[SqliteBackup] 🎉 EXPORT COMPLETATO CON SUCCESSO');
      debugPrint('[SqliteBackup] 📊 Dimensione: ${stat.size} bytes');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('');
      
      return exportedFile;
    } catch (e, stack) {
      if (e is BackupException) rethrow;
      
      throw ExportFailedException(
        'Export fallito',
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  @override
  Future<void> importData(String sourcePath) async {
    try {
      debugPrint('');
      debugPrint('[SqliteBackup] 📥 Inizio import fisico da: ${p.basename(sourcePath)}');

      final sourceFile = File(sourcePath);

      // STEP 1: Verifica che il file sorgente esista
      debugPrint('[SqliteBackup] ➤ Sub-step 1: Verifica esistenza file...');
      if (!await sourceFile.exists()) {
        debugPrint('[SqliteBackup] ❌ File sorgente non trovato');
        throw ImportFailedException(
          'File sorgente non trovato: $sourcePath',
        );
      }
      
      final sourceStat = await sourceFile.stat();
      debugPrint('[SqliteBackup] ✅ File trovato (${sourceStat.size} bytes)');

      // STEP 2: Valida che il file sia un database SQLite valido
      debugPrint('[SqliteBackup] ➤ Sub-step 2: Validazione SQLite...');
      final isValid = await validateDatabaseFile(sourcePath);
      if (!isValid) {
        debugPrint('[SqliteBackup] ❌ File non valido');
        throw ImportValidationException(
          'Il file da importare non è un database SQLite valido',
        );
      }
      debugPrint('[SqliteBackup] ✅ File SQLite valido');

      // STEP 3: Chiudi il database corrente per rilasciare tutti i lock
      debugPrint('');
      debugPrint('[SqliteBackup] ➤ Sub-step 3: Chiusura database corrente...');
      await _closeDatabaseSafely();
      debugPrint('[SqliteBackup] ✅ Database corrente chiuso, lock rilasciati');

      // STEP 4: Clean Wipe - Elimina tutti i file del database esistente
      debugPrint('');
      debugPrint('[SqliteBackup] ➤ Sub-step 4: Clean Wipe files esistenti...');
      await _cleanWipeDatabaseFiles();
      debugPrint('[SqliteBackup] ✅ Clean Wipe completato');

      // STEP 5: Copia il file sorgente nella posizione del database
      debugPrint('');
      debugPrint('[SqliteBackup] ➤ Sub-step 5: Copia nuovo database...');
      final dbPath = await _getDatabasePath();
      await sourceFile.copy(dbPath);
      debugPrint('[SqliteBackup] ✅ File copiato in: ${p.basename(dbPath)}');

      // STEP 6: Verifica che il nuovo database sia stato copiato correttamente
      debugPrint('');
      debugPrint('[SqliteBackup] ➤ Sub-step 6: Verifica finale...');
      final newDbFile = File(dbPath);
      if (!await newDbFile.exists()) {
        debugPrint('[SqliteBackup] ❌ Database non trovato dopo copia');
        throw ImportFailedException(
          'Database importato non trovato dopo la copia',
        );
      }

      final stat = await newDbFile.stat();
      debugPrint('[SqliteBackup] ✅ Database importato e verificato (${stat.size} bytes)');
      debugPrint('[SqliteBackup] 🎉 Import fisico completato');
      debugPrint('');
    } catch (e, stack) {
      if (e is BackupException) rethrow;
      
      throw ImportFailedException(
        'Import fallito',
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  /// Elimina completamente tutti i file del database (main, WAL, SHM).
  /// 
  /// Questa è l'operazione "Clean Wipe" richiesta prima di ogni import.
  Future<void> _cleanWipeDatabaseFiles() async {
    try {
      final dbFiles = await _getAllDatabaseFilePaths();
      
      debugPrint('[SqliteBackup] 🧹 Clean Wipe in corso...');
      for (final filePath in dbFiles) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('[SqliteBackup]   ✓ Eliminato: ${p.basename(filePath)}');
        } else {
          debugPrint('[SqliteBackup]   - Non esiste: ${p.basename(filePath)}');
        }
      }
      debugPrint('[SqliteBackup] ✅ Clean Wipe completato');
    } catch (e, stack) {
      debugPrint('[SqliteBackup] ❌ Clean Wipe fallito: $e');
      throw ImportFailedException(
        'Impossibile eliminare i file del database esistente',
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  @override
  Future<bool> validateDatabaseFile(String filePath) async {
    try {
      final file = File(filePath);

      // Verifica esistenza
      if (!await file.exists()) {
        debugPrint('[SqliteBackup] File non esiste: $filePath');
        return false;
      }

      // Verifica dimensione > 0
      final stat = await file.stat();
      if (stat.size == 0) {
        debugPrint('[SqliteBackup] File vuoto: $filePath');
        return false;
      }

      // Verifica SQLite magic bytes (primi 16 bytes devono essere "SQLite format 3\0")
      final bytes = await file.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes.take(16));
      
      final isValid = header.startsWith('SQLite format 3');
      
      if (!isValid) {
        debugPrint('[SqliteBackup] File non è un database SQLite valido');
      }
      
      return isValid;
    } catch (e) {
      debugPrint('[SqliteBackup] Errore durante validazione: $e');
      return false;
    }
  }
}

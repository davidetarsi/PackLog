import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pack_log/shared/constants/app_constants.dart';
import '../database_provider.dart';
import '../exceptions/backup_exceptions.dart';
import '../services/backup_service.dart';
import '../services/database_backup_service.dart';
import '../services/sqlite_backup_service.dart';

part 'backup_controller.g.dart';

/// Risultato di un'operazione di export
class ExportResult {
  final File exportedFile;
  final String path;
  final int sizeBytes;

  const ExportResult({
    required this.exportedFile,
    required this.path,
    required this.sizeBytes,
  });
}

/// Risultato di un'operazione di import
class ImportResult {
  final bool success;
  final String? errorMessage;

  const ImportResult.success() : success = true, errorMessage = null;

  const ImportResult.failure(this.errorMessage) : success = false;
}

/// Provider per il servizio di backup SQLite
@riverpod
DatabaseBackupService databaseBackupService(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return SqliteBackupService(database);
}

/// Provider per il servizio di backup automatico legacy
@riverpod
BackupService backupService(Ref ref) {
  return BackupService();
}

/// Controller per orchestrare le operazioni di backup e restore.
///
/// Gestisce:
/// - Export del database con chiusura WAL
/// - Import con disaster recovery automatico
/// - Safety backup prima di import
/// - Rollback automatico se import fallisce
/// - Invalidazione del database provider per ricreare connessione fresca
///
/// **USAGE EXAMPLE:**
/// ```dart
/// // Export
/// final result = await ref.read(backupControllerProvider.notifier).exportDatabase('/path/to/export.db');
///
/// // Import
/// final result = await ref.read(backupControllerProvider.notifier).importDatabase('/path/to/import.db');
/// ```
@riverpod
class BackupController extends _$BackupController {
  @override
  FutureOr<void> build() {
    // Stato iniziale: nessuna operazione in corso
  }

  /// Esporta il database corrente in un file specifico.
  ///
  /// **Flow:**
  /// 1. Chiude il database (flush WAL)
  /// 2. Copia il file .sqlite
  /// 3. Invalida il provider per ricreare connessione
  ///
  /// **Returns:**
  /// - [ExportResult]: Informazioni sul file esportato
  ///
  /// **Throws:**
  /// - [ExportFailedException]: Se l'export fallisce
  Future<ExportResult> exportDatabase(String destinationPath) async {
    try {
      debugPrint('[BackupController] Inizio export database');

      final backupService = ref.read(databaseBackupServiceProvider);

      // Export fisico del database
      final exportedFile = await backupService.exportData(destinationPath);

      // Invalida il database provider: la cascata Riverpod propaga
      // automaticamente l'invalidazione a tutti i repository provider
      // (che lo watchano) e quindi a tutti i notifier feature (che
      // watchano i repository). Nessuna invalidazione manuale necessaria.
      debugPrint('[BackupController] 🔄 Invalidazione database provider...');
      ref.invalidate(appDatabaseProvider);
      debugPrint('[BackupController] ✅ Database provider invalidato');

      final stat = await exportedFile.stat();

      debugPrint('[BackupController] ✅ Export completato: ${stat.size} bytes');

      return ExportResult(
        exportedFile: exportedFile,
        path: exportedFile.path,
        sizeBytes: stat.size,
      );
    } catch (e) {
      debugPrint('[BackupController] ❌ Export fallito: $e');

      // Invalida comunque il provider per ripristinare la connessione.
      ref.invalidate(appDatabaseProvider);
      rethrow;
    }
  }

  static const String _dbFileName = 'stuff_tracker.db';
  static const String _safetyBackupPrefix = 'safety-backup-';
  static const int _maxSafetyBackups = 5;

  /// Percorso del file database principale nell'app documents directory.
  Future<String> _getDatabasePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, _dbFileName);
  }

  /// Verifica che un file sia un database SQLite valido (magic bytes).
  Future<bool> _validateSqliteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      final stat = await file.stat();
      if (stat.size == 0) return false;
      final bytes = await file.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes.take(16));
      return header.startsWith('SQLite format 3');
    } catch (_) {
      return false;
    }
  }

  /// Sostituisce il database corrente con un file sorgente.
  ///
  /// Esegue clean wipe di .db, .db-wal, .db-shm e copia il sorgente.
  /// NON chiude nessuna connessione Drift — il chiamante è responsabile
  /// di aver già chiuso il DB (tramite export o invalidazione provider).
  Future<void> _replaceDatabase(String sourcePath) async {
    final dbPath = await _getDatabasePath();

    debugPrint('[BackupController] 🧹 Clean wipe files esistenti...');
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$dbPath$suffix');
      if (await file.exists()) {
        await file.delete();
        debugPrint('  ✓ Eliminato: ${p.basename('$dbPath$suffix')}');
      }
    }

    debugPrint('[BackupController] 📋 Copia nuovo database...');
    final sourceFile = File(sourcePath);
    await sourceFile.copy(dbPath);

    final newDb = File(dbPath);
    if (!await newDb.exists()) {
      throw ImportFailedException('Database non trovato dopo la copia');
    }
    final stat = await newDb.stat();
    if (stat.size == 0) {
      throw ImportFailedException('Database vuoto dopo la copia');
    }
    debugPrint(
      '[BackupController] ✅ Database sostituito con successo (${stat.size} bytes)',
    );
  }

  /// Ritorna il percorso della cartella dove vengono salvati i safety backup.
  ///
  /// Su Android 11+ le sottocartelle di Download non sono affidabili
  /// (Scoped Storage impedisce indicizzazione MediaStore e visibilità nel
  /// file manager), quindi i safety backup sono nella root di Download,
  /// stessa cartella degli export manuali.
  Future<String> getBackupDirectoryPath() async {
    final dir = await _resolveDownloadsDirectory();
    return dir?.path ?? (await getApplicationDocumentsDirectory()).path;
  }

  /// Crea immediatamente un backup di sicurezza del database corrente.
  ///
  /// Salva il backup direttamente nella cartella Download (stessa degli
  /// export manuali). Su Android 11+ le sottocartelle di Download non sono
  /// affidabili (Scoped Storage), quindi usiamo la root con un prefisso
  /// `safety-backup-` per distinguerli.
  ///
  /// Dopo il salvataggio, elimina automaticamente i backup più vecchi
  /// mantenendo solo i [_maxSafetyBackups] più recenti.
  ///
  /// **IMPORTANTE**: dopo questa chiamata il database viene chiuso e
  /// [appDatabaseProvider] viene invalidato.
  Future<String> createSafetyBackup() async {
    debugPrint('[BackupController] 🛡️ Creazione safety backup preventivo...');

    final backupDir = await _resolveDownloadsDirectory();
    if (backupDir == null) {
      throw ExportFailedException('backup.downloads_unavailable'.tr());
    }

    final now = DateTime.now();
    final ts =
        '${now.day.toString().padLeft(2, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.year}'
        '-${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final fileName =
        '$_safetyBackupPrefix${AppConstants.backupFilePrefix}-$ts'
        '${AppConstants.databaseFileExtension}';
    final destPath = p.join(backupDir.path, fileName);

    debugPrint('[BackupController] 📂 Destinazione: $destPath');

    final backupService = ref.read(databaseBackupServiceProvider);
    final backupFile = await backupService.exportData(destPath);

    debugPrint(
      '[BackupController] ✅ Safety backup creato: ${p.basename(backupFile.path)}',
    );

    // exportData() ha chiuso il DB. Invalidiamo il provider perché il
    // prossimo accesso crei una connessione fresca.
    ref.invalidate(appDatabaseProvider);

    // Pulizia asincrona dei backup più vecchi (fire-and-forget, non blocca l'import)
    _cleanOldSafetyBackups(backupDir).catchError((e) {
      debugPrint('[BackupController] ⚠️ Pulizia backup fallita: $e');
    });

    return backupFile.path;
  }

  /// Elimina i safety backup più vecchi, mantenendo solo i
  /// [_maxSafetyBackups] più recenti.
  Future<void> _cleanOldSafetyBackups(Directory backupDir) async {
    try {
      final safetyFiles = await backupDir
          .list()
          .where(
            (entity) =>
                entity is File &&
                p.basename(entity.path).startsWith(_safetyBackupPrefix),
          )
          .cast<File>()
          .toList();

      if (safetyFiles.length <= _maxSafetyBackups) return;

      // Ordina per data di modifica (più recente prima)
      safetyFiles.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      final toDelete = safetyFiles.sublist(_maxSafetyBackups);
      for (final file in toDelete) {
        await file.delete();
        debugPrint(
          '[BackupController] 🗑️ Backup eliminato: ${p.basename(file.path)}',
        );
      }
      debugPrint(
        '[BackupController] ✅ Pulizia completata: '
        '${toDelete.length} backup rimossi, $_maxSafetyBackups mantenuti',
      );
    } catch (e) {
      debugPrint('[BackupController] ⚠️ Errore pulizia backup: $e');
    }
  }

  /// Importa un database da un file esterno, sostituendo quello corrente.
  ///
  /// Se [preCreatedBackupPath] è fornito, salta la creazione del safety
  /// backup (già fatto da [createSafetyBackup]). In questo caso il DB è
  /// già CHIUSO e [appDatabaseProvider] è già invalidato.
  ///
  /// **ARCHITETTURA**: non usa [SqliteBackupService.importData] perché
  /// quel metodo tenta di chiudere la connessione Drift interna, ma dopo
  /// [createSafetyBackup] il vecchio DB è già chiuso e il provider
  /// invalidato — creare un nuovo [SqliteBackupService] produce un
  /// database MAI aperto il cui `.close()` lancia un'eccezione.
  /// Operiamo direttamente sui file (clean wipe + copy) per evitare
  /// qualsiasi interazione con Drift durante la sostituzione.
  Future<ImportResult> importDatabase(
    String sourcePath, {
    String? preCreatedBackupPath,
  }) async {
    String? safetyBackupPath = preCreatedBackupPath;

    try {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('[BackupController] 🚀 INIZIO IMPORT DATABASE');
      debugPrint('[BackupController] 📂 File sorgente: $sourcePath');
      debugPrint('═══════════════════════════════════════════════════');

      // STEP 0: Valida il nome del file
      debugPrint('[BackupController] ➤ STEP 0: Validazione nome file...');
      if (!validateImportFileName(sourcePath)) {
        throw ImportValidationException(
          'backup.invalid_filename'.tr(args: [AppConstants.backupFilePrefix]),
        );
      }
      debugPrint('[BackupController] ✅ Nome file valido');

      // STEP 1: Safety backup
      if (safetyBackupPath != null) {
        debugPrint('');
        debugPrint(
          '[BackupController] ✅ STEP 1: Safety backup già creato: '
          '${p.basename(safetyBackupPath)}',
        );
      } else {
        debugPrint('');
        debugPrint('[BackupController] ➤ STEP 1: Creazione safety backup...');
        safetyBackupPath = await createSafetyBackup();
      }

      // STEP 2: Valida il file sorgente (lettura header, no connessione DB)
      debugPrint('');
      debugPrint('[BackupController] ➤ STEP 2: Validazione file SQLite...');
      final isValid = await _validateSqliteFile(sourcePath);
      if (!isValid) {
        debugPrint('[BackupController] ❌ File non valido');
        throw ImportValidationException('backup.invalid_sqlite_file'.tr());
      }
      debugPrint('[BackupController] ✅ File SQLite valido');

      // STEP 3: Sostituzione diretta dei file (NO Drift, NO .close())
      debugPrint('');
      debugPrint('[BackupController] ➤ STEP 3: Sostituzione database...');
      await _replaceDatabase(sourcePath);

      // STEP 4: Invalida il database provider.
      // La cascata Riverpod propaga automaticamente l'invalidazione
      // a tutti i repository provider e ai notifier feature senza
      // che il controller debba conoscerli (Open-Closed Principle).
      debugPrint('');
      debugPrint(
        '[BackupController] ➤ STEP 4: Invalidazione database provider...',
      );
      ref.invalidate(appDatabaseProvider);
      debugPrint('[BackupController] ✅ Database provider invalidato');

      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('[BackupController] 🎉 IMPORT COMPLETATO CON SUCCESSO');
      debugPrint('═══════════════════════════════════════════════════');

      return const ImportResult.success();
    } catch (e) {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('[BackupController] ❌ IMPORT FALLITO: $e');
      debugPrint('═══════════════════════════════════════════════════');

      if (safetyBackupPath != null) {
        debugPrint('[BackupController] 🔄 ROLLBACK AUTOMATICO...');
        try {
          await _replaceDatabase(safetyBackupPath);
          ref.invalidate(appDatabaseProvider);
          debugPrint('[BackupController] ✅ ROLLBACK COMPLETATO');
        } catch (rollbackError) {
          debugPrint('[BackupController] 🔥 ROLLBACK FALLITO: $rollbackError');
          return ImportResult.failure('backup.critical_error'.tr());
        }
      }

      return ImportResult.failure(
        e is ImportValidationException
            ? 'backup.import_validation_failed'.tr()
            : 'backup.import_failed'.tr(),
      );
    }
  }

  /// Esporta il database nella cartella Download dell'utente.
  ///
  /// Tenta di salvare nella **cartella Download pubblica** del dispositivo
  /// (visibile nel file manager) usando [_resolveDownloadsDirectory].
  /// Se non è accessibile in scrittura (Android 11+ senza permessi), ricade
  /// sulla directory specifica dell'app fornita da [getDownloadsDirectory].
  ///
  /// **Nome file:** `stuff-tracker-db-[ddmmyyyy].db`
  /// Esempio: `stuff-tracker-db-17022026.db`
  Future<ExportResult> exportToTemporaryFile() async {
    debugPrint(
      '[BackupController] Preparazione export con nome file specifico',
    );

    final downloadsDir = await _resolveDownloadsDirectory();

    if (downloadsDir == null) {
      throw ExportFailedException('backup.downloads_unavailable'.tr());
    }

    // Crea la directory se per qualche motivo non esiste
    if (!await downloadsDir.exists()) {
      debugPrint(
        '[BackupController] 📁 Directory Downloads non esiste, la creo...',
      );
      await downloadsDir.create(recursive: true);
    }

    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final fileName =
        '${AppConstants.backupFilePrefix}-$day$month$year-$hour$minute$second${AppConstants.databaseFileExtension}';

    final destinationPath = p.join(downloadsDir.path, fileName);

    debugPrint('[BackupController] 📁 Directory export: ${downloadsDir.path}');
    debugPrint('[BackupController] 📄 Nome file export: $fileName');
    debugPrint('[BackupController] 📂 Path completo: $destinationPath');

    return await exportDatabase(destinationPath);
  }

  /// Risolve la directory di destinazione ottimale per l'export.
  ///
  /// **Android**: tenta in ordine i percorsi della cartella Download pubblica
  /// (`/storage/emulated/0/Download` e variante con `s`). Per ciascuno verifica
  /// l'effettivo accesso in scrittura con un file temporaneo. Se nessun percorso
  /// pubblico è scrivibile (Android 11+ senza [MANAGE_EXTERNAL_STORAGE]), ricade
  /// su [getDownloadsDirectory] che restituisce la directory privata dell'app.
  ///
  /// **iOS / Desktop**: delegato direttamente a [getDownloadsDirectory].
  Future<Directory?> _resolveDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Percorsi standard della cartella Download pubblica su Android.
      // Disponibili senza permessi aggiuntivi su Android ≤ 9.
      // Su Android 10, accessibili grazie a requestLegacyExternalStorage="true".
      // Su Android 11+, la scrittura diretta fallisce: fallback su path_provider.
      const androidPublicPaths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
      ];

      for (final candidatePath in androidPublicPaths) {
        final dir = Directory(candidatePath);
        if (!await dir.exists()) continue;

        // Verifica accesso in scrittura con byte reali (non File.create()
        // che crea un file vuoto: alcune ROM Android permettono la creazione
        // di file vuoti ma bloccano scritture con dati effettivi).
        final testFile = File(p.join(dir.path, '.tmp_write_test'));
        try {
          await testFile.writeAsBytes([0x53, 0x51, 0x4C]); // 'SQL'
          await testFile.delete();
          debugPrint(
            '[BackupController] ✅ Cartella Download pubblica accessibile: $candidatePath',
          );
          return dir;
        } catch (_) {
          debugPrint(
            '[BackupController] ⚠️ $candidatePath non scrivibile, provo alternativa...',
          );
        }
      }

      debugPrint(
        '[BackupController] ⚠️ Cartella Download pubblica non accessibile '
        '(Android 11+?), uso directory privata via path_provider.',
      );
    }

    // Fallback: directory Downloads specifica dell'app
    // (es. /Android/data/<pkg>/files/Downloads).
    return getDownloadsDirectory();
  }

  /// Valida che un file di import abbia il nome corretto.
  ///
  /// Accetta file che iniziano con il prefisso standard di export
  /// (`pack-log-export-db`) oppure con il prefisso dei safety backup
  /// (`safety-backup-pack-log-export-db`).
  bool validateImportFileName(String filePath) {
    final fileName = p.basename(filePath);
    final isValid =
        fileName.startsWith(AppConstants.backupFilePrefix) ||
        fileName.startsWith(
          '$_safetyBackupPrefix${AppConstants.backupFilePrefix}',
        );

    debugPrint(
      '[BackupController] Validazione nome file: $fileName -> '
      '${isValid ? "✅ VALIDO" : "❌ INVALIDO"}',
    );

    return isValid;
  }
}

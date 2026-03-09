import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stuff_tracker_2/features/houses/providers/house_provider.dart';
import 'package:stuff_tracker_2/features/houses/providers/house_stats_provider.dart';
import 'package:stuff_tracker_2/features/items/providers/item_provider.dart';
import 'package:stuff_tracker_2/features/trips/providers/trip_provider.dart';
import 'package:stuff_tracker_2/features/spaces/providers/space_provider.dart';
import 'package:stuff_tracker_2/features/luggages/providers/luggage_provider.dart';
import 'package:stuff_tracker_2/shared/constants/app_constants.dart';
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
  static const String _safetyBackupReason = 'Safety backup before import';

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
      
      // Invalida il database provider per permettere nuove connessioni
      // (necessario perché abbiamo chiamato .close() durante l'export)
      debugPrint('[BackupController] 🔄 Invalidazione database provider...');
      ref.invalidate(appDatabaseProvider);
      
      // Aspetta riconnessione e invalida family providers per sicurezza
      await Future.delayed(const Duration(milliseconds: 300));
      final housesAsync = ref.read(houseNotifierProvider);
      if (housesAsync.hasValue && housesAsync.value != null) {
        for (final house in housesAsync.value!) {
          ref.invalidate(itemNotifierProvider(house.id));
          ref.invalidate(houseStatsProvider(house.id));
          ref.invalidate(spacesByHouseProvider(house.id));
          ref.invalidate(spaceCountByHouseProvider(house.id));
          ref.invalidate(luggagesByHouseProvider(house.id));
          ref.invalidate(luggageCountByHouseProvider(house.id));
        }
      }
      
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
      
      // Invalida comunque il provider per ripristinare lo stato
      ref.invalidate(appDatabaseProvider);
      await Future.delayed(const Duration(milliseconds: 300));
      final housesAsync = ref.read(houseNotifierProvider);
      if (housesAsync.hasValue && housesAsync.value != null) {
        for (final house in housesAsync.value!) {
          ref.invalidate(itemNotifierProvider(house.id));
          ref.invalidate(houseStatsProvider(house.id));
          ref.invalidate(spacesByHouseProvider(house.id));
          ref.invalidate(spaceCountByHouseProvider(house.id));
          ref.invalidate(luggagesByHouseProvider(house.id));
          ref.invalidate(luggageCountByHouseProvider(house.id));
        }
      }
      
      rethrow;
    }
  }

  /// Importa un database da un file esterno, sostituendo quello corrente.
  /// 
  /// **Disaster Recovery Flow:**
  /// 1. Valida nome file (deve iniziare con "stuff-tracker-db")
  /// 2. Crea safety backup del DB corrente
  /// 3. Valida il file da importare (SQLite magic bytes)
  /// 4. Chiude il database
  /// 5. Clean wipe (elimina .sqlite, .sqlite-wal, .sqlite-shm)
  /// 6. Copia il nuovo database
  /// 7. Valida il nuovo database
  /// 8. Se qualcosa fallisce -> ROLLBACK automatico dal safety backup
  /// 9. Invalida il provider per ricreare connessione
  /// 
  /// **Returns:**
  /// - [ImportResult]: Risultato dell'operazione (success o failure con messaggio)
  Future<ImportResult> importDatabase(String sourcePath) async {
    String? safetyBackupPath;

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

      final backupService = ref.read(databaseBackupServiceProvider);
      final legacyBackupService = ref.read(backupServiceProvider);

      // STEP 1: Crea safety backup prima di qualsiasi operazione
      debugPrint('');
      debugPrint('[BackupController] ➤ STEP 1: Creazione safety backup...');
      safetyBackupPath = await legacyBackupService.createBackup(
        reason: _safetyBackupReason,
      );
      
      if (safetyBackupPath == null) {
        debugPrint('[BackupController] ❌ Safety backup fallito');
        throw ImportFailedException(
          'backup.safety_backup_failed'.tr(),
        );
      }
      
      debugPrint('[BackupController] ✅ Safety backup creato: ${p.basename(safetyBackupPath)}');

      // STEP 2: Valida il file sorgente PRIMA di procedere
      debugPrint('');
      debugPrint('[BackupController] ➤ STEP 2: Validazione file SQLite...');
      final isValid = await backupService.validateDatabaseFile(sourcePath);
      if (!isValid) {
        debugPrint('[BackupController] ❌ File non valido (non è un database SQLite)');
        throw ImportValidationException(
          'backup.invalid_sqlite_file'.tr(),
        );
      }
      debugPrint('[BackupController] ✅ File SQLite valido');

      // STEP 3: Import del database (chiude DB, clean wipe, copia)
      debugPrint('');
      debugPrint('[BackupController] ➤ STEP 3: Import database...');
      await backupService.importData(sourcePath);
      debugPrint('[BackupController] ✅ Database importato fisicamente');

      // STEP 4: Invalida TUTTI i provider per ricreare connessione fresca
      debugPrint('');
      debugPrint('[BackupController] ➤ STEP 4: Invalidazione completa provider...');
      await _invalidateAllProviders();
      debugPrint('[BackupController] ✅ Tutti i provider invalidati e ricaricati');
      
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('[BackupController] 🎉 IMPORT COMPLETATO CON SUCCESSO');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('');
      
      return const ImportResult.success();
      
    } catch (e) {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('[BackupController] ❌ IMPORT FALLITO: $e');
      debugPrint('═══════════════════════════════════════════════════');
      
      // DISASTER RECOVERY: Ripristina dal safety backup
      if (safetyBackupPath != null) {
        debugPrint('');
        debugPrint('[BackupController] 🔄 AVVIO ROLLBACK AUTOMATICO...');
        debugPrint('[BackupController] 📂 Safety backup: ${p.basename(safetyBackupPath)}');
        
        try {
          await _performRollback(safetyBackupPath);
          
          debugPrint('');
          debugPrint('[BackupController] ✅ ROLLBACK COMPLETATO');
          debugPrint('[BackupController] Database ripristinato allo stato precedente');
          debugPrint('');
        } catch (rollbackError) {
          // Questo è il worst-case scenario: import fallito E rollback fallito
          debugPrint('');
          debugPrint('═══════════════════════════════════════════════════');
          debugPrint('[BackupController] 🔥 CRITICAL ERROR: ROLLBACK FALLITO');
          debugPrint('[BackupController] Errore: $rollbackError');
          debugPrint('[BackupController] Database potrebbe essere in stato inconsistente!');
          debugPrint('═══════════════════════════════════════════════════');
          debugPrint('');
          
          return ImportResult.failure(
            'backup.critical_error'.tr(),
          );
        }
      }
      
      return ImportResult.failure(
        e is ImportValidationException
            ? 'backup.import_validation_failed'.tr()
            : 'backup.import_failed'.tr(),
      );
    }
  }

  /// Invalida tutti i provider dell'app per forzare il reload completo dopo import/export.
  /// 
  /// Questo metodo:
  /// 1. Invalida il database provider (ricreerà la connessione)
  /// 2. Aspetta un breve delay per permettere la riconnessione
  /// 3. Invalida tutti i provider che dipendono dal database
  Future<void> _invalidateAllProviders() async {
    debugPrint('[BackupController] 🔄 Invalidazione completa di tutti i provider:');
    
    // Step 1: Invalida il database
    debugPrint('  ↳ Database provider...');
    ref.invalidate(appDatabaseProvider);
    
    // Step 2: Breve delay per permettere la riconnessione del database
    debugPrint('  ↳ Attendo riconnessione database...');
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('  ↳ Database pronto ✅');
    
    // Step 3: Invalida tutti i provider dipendenti
    debugPrint('  ↳ Houses provider...');
    ref.invalidate(houseNotifierProvider);
    
    // Aspetta che le case si ricarichino per invalidare i family providers
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Step 4: Invalida family providers per ogni casa
    final housesAsync = ref.read(houseNotifierProvider);
    if (housesAsync.hasValue && housesAsync.value != null) {
      final houses = housesAsync.value!;
      debugPrint('  ↳ Invalidazione family providers per ${houses.length} case...');
      
      for (final house in houses) {
        debugPrint('    • Items provider per casa: ${house.name}');
        ref.invalidate(itemNotifierProvider(house.id));
        
        debugPrint('    • House Stats provider per casa: ${house.name}');
        ref.invalidate(houseStatsProvider(house.id));
        
        debugPrint('    • Spaces provider per casa: ${house.name}');
        ref.invalidate(spacesByHouseProvider(house.id));
        ref.invalidate(spaceCountByHouseProvider(house.id));
        
        debugPrint('    • Luggages provider per casa: ${house.name}');
        ref.invalidate(luggagesByHouseProvider(house.id));
        ref.invalidate(luggageCountByHouseProvider(house.id));
      }
    } else {
      // Fallback: invalida i provider globali
      debugPrint('  ↳ Items provider (globale)...');
      ref.invalidate(itemNotifierProvider);
      
      debugPrint('  ↳ House Stats provider (globale)...');
      ref.invalidate(houseStatsProvider);
    }
    
    debugPrint('  ↳ Spaces provider...');
    ref.invalidate(spaceNotifierProvider);
    
    debugPrint('  ↳ Luggages provider...');
    ref.invalidate(luggageNotifierProvider);
    
    debugPrint('  ↳ Trips provider...');
    ref.invalidate(tripNotifierProvider);
    
    // Step 5: Aspetta che i provider si ricarichino
    debugPrint('  ↳ Attendo ricaricamento completo provider...');
    await Future.delayed(const Duration(milliseconds: 1000));
    
    debugPrint('[BackupController] ✅ Invalidazione completa terminata');
  }

  /// Esegue il rollback dal safety backup.
  /// 
  /// **CRITICAL**: Se questa operazione fallisce, siamo in uno stato inconsistente.
  Future<void> _performRollback(String safetyBackupPath) async {
    try {
      debugPrint('[BackupController] 🔄 Import safety backup...');
      final backupService = ref.read(databaseBackupServiceProvider);
      
      // Import del safety backup (clean wipe + copia)
      await backupService.importData(safetyBackupPath);
      debugPrint('[BackupController] ✅ Safety backup importato');
      
      // Invalida tutti i provider per ricaricare completamente l'app
      await _invalidateAllProviders();
      
    } catch (e, stack) {
      throw BackupRollbackException(
        'backup.rollback_impossible'.tr(),
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  /// Esporta il database in un file temporaneo per condivisione.
  /// 
  /// Utile per permettere all'utente di salvare/condividere il database.
  /// Il file viene creato nella directory temporanea del sistema.
  /// 
  /// **Nome file:** `stuff-tracker-db-[ddmmyyyy].db`
  /// Esempio: `stuff-tracker-db-17022026.db`
  Future<ExportResult> exportToTemporaryFile() async {
    try {
      debugPrint('[BackupController] Preparazione export con nome file specifico');
      
      // Usa la directory Downloads per rendere il file accessibile all'utente
      final downloadsDir = await getDownloadsDirectory();
      
      if (downloadsDir == null) {
        throw ExportFailedException(
          'backup.downloads_unavailable'.tr(),
        );
      }
      
      // Crea la directory Downloads se non esiste
      if (!await downloadsDir.exists()) {
        debugPrint('[BackupController] 📁 Directory Downloads non esiste, la creo...');
        await downloadsDir.create(recursive: true);
        debugPrint('[BackupController] ✅ Directory Downloads creata');
      }
      
      final now = DateTime.now();
      
      // Formato: [prefix]-[ddmmyyyy].db
      final day = now.day.toString().padLeft(2, '0');
      final month = now.month.toString().padLeft(2, '0');
      final year = now.year.toString();
      final fileName = '${AppConstants.backupFilePrefix}-$day$month$year${AppConstants.databaseFileExtension}';
      
      final destinationPath = p.join(downloadsDir.path, fileName);
      
      debugPrint('[BackupController] 📁 Directory export: ${downloadsDir.path}');
      debugPrint('[BackupController] 📄 Nome file export: $fileName');
      debugPrint('[BackupController] 📂 Path completo: $destinationPath');

      return await exportDatabase(destinationPath);
    } catch (e) {
      rethrow;
    }
  }

  /// Valida che un file di import abbia il nome corretto.
  /// 
  /// Il nome deve iniziare con il prefisso definito in AppConstants per essere accettato.
  bool validateImportFileName(String filePath) {
    final fileName = p.basename(filePath);
    final isValid = fileName.startsWith(AppConstants.backupFilePrefix);
    
    debugPrint('[BackupController] Validazione nome file: $fileName -> ${isValid ? "✅ VALIDO" : "❌ INVALIDO"}');
    
    return isValid;
  }
}

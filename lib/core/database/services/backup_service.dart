import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pack_log/shared/constants/app_constants.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Configurazione per i backup.
class BackupConfig {
  /// Numero massimo di backup da mantenere
  final int maxBackups;
  
  /// Intervallo minimo tra backup automatici (in ore)
  final int autoBackupIntervalHours;

  const BackupConfig({
    this.maxBackups = 5,
    this.autoBackupIntervalHours = 24,
  });
  
  static const defaultConfig = BackupConfig();
}

/// Informazioni su un backup.
class BackupInfo {
  final String path;
  final DateTime createdAt;
  final int sizeBytes;

  BackupInfo({
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
  });
  
  String get fileName => p.basename(path);
  
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Servizio per la gestione dei backup del database.
/// 
/// Fornisce:
/// - Backup automatici periodici
/// - Backup manuali
/// - Rotazione dei backup (mantiene solo gli ultimi N)
/// - Ripristino da backup
/// - Verifica integrità backup
class BackupService {
  static const String _lastBackupKey = 'last_backup_timestamp';
  static const String _dbFileName = 'stuff_tracker.db';

  /// Nome della sottocartella pubblica per i backup automatici.
  /// Creata dentro la cartella Download del dispositivo, visibile
  /// nel file manager senza app aggiuntive.
  static const String _publicBackupFolderName = 'PackLogAutomaticBackups';

  /// Fallback: usato quando la cartella Download pubblica non è scrivibile
  /// (es. Android 11+ senza permessi aggiuntivi).
  static const String _privateBackupFolderName = 'backups';
  
  final BackupConfig _config;
  
  BackupService({BackupConfig config = BackupConfig.defaultConfig}) 
      : _config = config;

  /// Ritorna il percorso della directory dove vengono salvati i backup automatici.
  ///
  /// Utile per mostrare all'utente dove viene creata la copia di sicurezza
  /// prima di un'operazione di import.
  Future<String> getBackupDirectoryPath() async {
    final dir = await _getBackupDirectory();
    return dir.path;
  }

  /// Ottiene la directory per i backup automatici.
  ///
  /// **Strategia a due livelli:**
  /// 1. Tenta `<Download pubblico>/automaticBackupPackLog/` (visibile nel
  ///    file manager). Funziona su Android ≤ 10 con il permesso
  ///    `WRITE_EXTERNAL_STORAGE` e `requestLegacyExternalStorage="true"`.
  /// 2. Fallback su `<documenti privati app>/backups/` se il percorso
  ///    pubblico non è scrivibile (Android 11+ senza permessi speciali).
  ///
  /// La directory viene creata automaticamente se non esiste.
  Future<Directory> _getBackupDirectory() async {
    if (Platform.isAndroid) {
      final publicDir = await _resolvePublicBackupDirectory();
      if (publicDir != null) return publicDir;
    }

    // Fallback: directory privata dell'app
    final appDir = await getApplicationDocumentsDirectory();
    final fallbackDir = Directory(p.join(appDir.path, _privateBackupFolderName));
    if (!await fallbackDir.exists()) {
      await fallbackDir.create(recursive: true);
    }
    return fallbackDir;
  }

  /// Tenta di risolvere `<Download pubblico>/automaticBackupPackLog/` su Android.
  ///
  /// **Ordine critico delle operazioni:**
  /// 1. Verifica accesso in scrittura nella dir **parent** (root Download),
  ///    usando byte reali (non un file vuoto) per simulare la copia reale del DB.
  /// 2. Solo se il parent è scrivibile, crea/usa la sottocartella.
  ///
  /// Questo previene la creazione di cartelle orfane vuote: se il test di
  /// scrittura fallisce, non viene creata nessuna directory e si passa al
  /// path alternativo. Ritorna `null` se nessun percorso è accessibile.
  Future<Directory?> _resolvePublicBackupDirectory() async {
    const androidPublicPaths = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
    ];

    for (final basePath in androidPublicPaths) {
      final baseDir = Directory(basePath);
      if (!await baseDir.exists()) continue;

      // STEP 1: Verifica accesso in scrittura nella dir ROOT prima di tutto.
      // Si usa writeAsBytes() con byte reali (non File.create() che crea un
      // file vuoto da 0 byte: alcune ROM Android permettono la creazione di
      // file vuoti ma bloccano le scritture con dati effettivi).
      final parentTestFile =
          File(p.join(basePath, '.tmp_backup_write_test'));
      try {
        await parentTestFile.writeAsBytes([0x53, 0x51, 0x4C]); // 'SQL'
        await parentTestFile.delete();
      } catch (_) {
        debugPrint(
          '[BackupService] ⚠️ $basePath non scrivibile, provo alternativa...',
        );
        continue; // Niente cartelle orfane: non creiamo nulla qui
      }

      // STEP 2: Accesso confermato → ora crea/usa la sottocartella.
      final backupDir =
          Directory(p.join(basePath, _publicBackupFolderName));
      if (!await backupDir.exists()) {
        try {
          await backupDir.create(recursive: true);
        } catch (e) {
          debugPrint(
            '[BackupService] ⚠️ Impossibile creare sottocartella: $e',
          );
          continue;
        }
      }

      debugPrint(
        '[BackupService] ✅ Cartella backup pubblica: ${backupDir.path}',
      );
      return backupDir;
    }

    return null;
  }

  /// Ottiene il percorso del database principale.
  Future<File> _getDatabaseFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    return File(p.join(appDir.path, _dbFileName));
  }

  /// Genera il percorso completo per un nuovo file di backup senza crearlo.
  ///
  /// Usato da [BackupController] quando vuole delegare la copia fisica a
  /// [SqliteBackupService] (che gestisce correttamente il flush del WAL),
  /// ma ha bisogno di conoscere in anticipo dove salvare il file.
  /// Crea la directory di destinazione se non esiste.
  Future<String> generateBackupFilePath() async {
    final backupDir = await _getBackupDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final backupFileName =
        'auto_backup_${AppConstants.backupFilePrefix}_$timestamp.db';
    return p.join(backupDir.path, backupFileName);
  }

  /// Registra il timestamp dell'ultimo backup riuscito.
  ///
  /// Va chiamato dopo che il file di backup è stato scritto con successo
  /// (anche tramite [SqliteBackupService.exportData]).
  Future<void> markBackupCreated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Crea un backup del database.
  ///
  /// ⚠️  ATTENZIONE: questo metodo copia il file raw dal disco. Va chiamato
  /// solo quando la connessione Drift è già CHIUSA (WAL flushed), altrimenti
  /// la copia potrebbe essere incompleta. Usa [generateBackupFilePath] +
  /// [SqliteBackupService.exportData] quando la connessione è aperta.
  ///
  /// Ritorna il percorso del backup creato, o null se fallisce.
  Future<String?> createBackup({String? reason}) async {
    try {
      final dbFile = await _getDatabaseFile();
      
      if (!await dbFile.exists()) {
        debugPrint('[BackupService] Database non trovato, nessun backup creato');
        return null;
      }

      final backupDir = await _getBackupDirectory();
      final timestamp = DateTime.now().toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final backupPrefix = AppConstants.backupFilePrefix;
      final backupFileName = 'auto_backup_${backupPrefix}_$timestamp.db';
      final backupPath = p.join(backupDir.path, backupFileName);

      // Copia il database
      await dbFile.copy(backupPath);
      
      // Verifica che il backup sia stato creato correttamente
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        debugPrint('[BackupService] Backup non creato correttamente');
        return null;
      }

      // Salva il timestamp dell'ultimo backup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint(
        '[BackupService] Backup creato: $backupFileName '
        '${reason != null ? "(motivo: $reason)" : ""}',
      );

      // Pulisci i vecchi backup
      await _cleanOldBackups();

      return backupPath;
    } catch (e) {
      debugPrint('[BackupService] Errore creando backup: $e');
      return null;
    }
  }

  /// Crea un backup automatico se necessario.
  /// 
  /// Controlla se è passato abbastanza tempo dall'ultimo backup.
  Future<bool> createAutoBackupIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastBackup = prefs.getInt(_lastBackupKey);
      
      if (lastBackup == null) {
        // Nessun backup precedente, creane uno
        final result = await createBackup(reason: 'Primo backup automatico');
        return result != null;
      }

      final lastBackupTime = DateTime.fromMillisecondsSinceEpoch(lastBackup);
      final hoursSinceLastBackup = DateTime.now().difference(lastBackupTime).inHours;

      if (hoursSinceLastBackup >= _config.autoBackupIntervalHours) {
        final result = await createBackup(reason: 'Backup automatico periodico');
        return result != null;
      }

      debugPrint(
        '[BackupService] Backup automatico non necessario '
        '(ultimo: ${hoursSinceLastBackup}h fa)',
      );
      return true;
    } catch (e) {
      debugPrint('[BackupService] Errore nel backup automatico: $e');
      return false;
    }
  }

  /// Ottiene la lista dei backup disponibili.
  Future<List<BackupInfo>> getAvailableBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      final files = await backupDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.db'))
          .cast<File>()
          .toList();

      final backups = <BackupInfo>[];
      
      for (final file in files) {
        final stat = await file.stat();
        backups.add(BackupInfo(
          path: file.path,
          createdAt: stat.modified,
          sizeBytes: stat.size,
        ));
      }

      // Ordina per data (più recente prima)
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return backups;
    } catch (e) {
      debugPrint('[BackupService] Errore ottenendo lista backup: $e');
      return [];
    }
  }

  /// Ripristina il database da un backup.
  /// 
  /// **ATTENZIONE**: Questa operazione sovrascrive il database corrente!
  /// L'app deve essere riavviata dopo il ripristino.
  Future<bool> restoreFromBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      
      if (!await backupFile.exists()) {
        debugPrint('[BackupService] Backup non trovato: $backupPath');
        return false;
      }

      // Crea un backup del database corrente prima di sovrascriverlo
      await createBackup(reason: 'Pre-ripristino');

      final dbFile = await _getDatabaseFile();
      
      // Copia il backup sul database principale
      await backupFile.copy(dbFile.path);

      debugPrint('[BackupService] Database ripristinato da: $backupPath');
      return true;
    } catch (e) {
      debugPrint('[BackupService] Errore ripristinando backup: $e');
      return false;
    }
  }

  /// Elimina i backup più vecchi, mantenendo solo gli ultimi N.
  Future<void> _cleanOldBackups() async {
    try {
      final backups = await getAvailableBackups();
      
      if (backups.length <= _config.maxBackups) {
        return;
      }

      // Elimina i backup più vecchi
      final toDelete = backups.skip(_config.maxBackups);
      
      for (final backup in toDelete) {
        try {
          await File(backup.path).delete();
          debugPrint('[BackupService] Backup eliminato: ${backup.fileName}');
        } catch (e) {
          debugPrint('[BackupService] Errore eliminando backup: $e');
        }
      }
    } catch (e) {
      debugPrint('[BackupService] Errore nella pulizia backup: $e');
    }
  }

  /// Elimina tutti i backup.
  Future<void> deleteAllBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      
      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
        debugPrint('[BackupService] Tutti i backup eliminati');
      }
    } catch (e) {
      debugPrint('[BackupService] Errore eliminando backup: $e');
    }
  }

  /// Verifica l'integrità di un backup.
  Future<bool> verifyBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      
      if (!await backupFile.exists()) {
        return false;
      }

      // Verifica che il file non sia vuoto
      final stat = await backupFile.stat();
      if (stat.size == 0) {
        return false;
      }

      // Verifica che sia un database SQLite valido (magic bytes)
      final bytes = await backupFile.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes.take(6));
      
      return header == 'SQLite';
    } catch (e) {
      debugPrint('[BackupService] Errore verificando backup: $e');
      return false;
    }
  }
}

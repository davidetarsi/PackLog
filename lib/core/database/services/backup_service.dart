import 'dart:io';
import 'package:flutter/foundation.dart';
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
  static const String _backupFolderName = 'backups';
  
  final BackupConfig _config;
  
  BackupService({BackupConfig config = BackupConfig.defaultConfig}) 
      : _config = config;

  /// Ottiene il percorso della cartella dei backup.
  Future<Directory> _getBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(appDir.path, _backupFolderName));
    
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    
    return backupDir;
  }

  /// Ottiene il percorso del database principale.
  Future<File> _getDatabaseFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    return File(p.join(appDir.path, _dbFileName));
  }

  /// Crea un backup del database.
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
      final backupFileName = 'backup_$timestamp.db';
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

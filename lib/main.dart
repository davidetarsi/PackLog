import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'core/database/database.dart';
import 'core/database/migration_service.dart';
import 'core/database/services/backup_service.dart';
import 'core/database/services/data_integrity_service.dart';
import 'core/routing/app_router.dart';
import 'shared/theme/app_theme.dart';

void main() async {
  // Assicura che i widget Flutter siano inizializzati
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inizializza easy_localization
  await EasyLocalization.ensureInitialized();
  
  // Inizializza i servizi di persistenza in modo robusto
  await _initializePersistence();
  
  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('it', 'IT'),
        Locale('en', 'US'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('it', 'IT'),
      child: const ProviderScope(child: MyApp()),
    ),
  );
}

/// Inizializza tutti i servizi di persistenza in modo robusto.
/// 
/// Esegue in ordine:
/// 1. Migrazione da SharedPreferences (se necessario)
/// 2. Verifica integrità database
/// 3. Backup automatico (se necessario)
Future<void> _initializePersistence() async {
  debugPrint('[Main] Inizializzazione persistenza...');
  
  try {
    final database = AppDatabase();
    final prefs = await SharedPreferences.getInstance();
    
    // 1. MIGRAZIONE
    await _runMigration(database, prefs);
    
    // 2. VERIFICA INTEGRITÀ
    await _checkDataIntegrity(database);
    
    // 3. BACKUP AUTOMATICO
    await _createAutoBackup();
    
    // Chiudi la connessione temporanea
    // Il provider creerà una nuova connessione
    await database.close();
    
    debugPrint('[Main] Persistenza inizializzata con successo');
  } catch (e, stackTrace) {
    debugPrint('[Main] ERRORE CRITICO nell\'inizializzazione: $e');
    debugPrint('[Main] Stack trace: $stackTrace');
    // Non blocchiamo l'app, proviamo a continuare
  }
}

/// Esegue la migrazione da SharedPreferences a Drift.
Future<void> _runMigration(AppDatabase database, SharedPreferences prefs) async {
  try {
    final migrationService = MigrationService(database, prefs);
    final success = await migrationService.migrateIfNeeded();
    
    if (!success) {
      debugPrint('[Main] Attenzione: migrazione non completata');
    }
  } catch (e) {
    debugPrint('[Main] Errore durante la migrazione: $e');
  }
}

/// Verifica l'integrità dei dati e ripara automaticamente se possibile.
Future<void> _checkDataIntegrity(AppDatabase database) async {
  try {
    final integrityService = DataIntegrityService(database);
    
    // Prima verifica rapida
    final quickOk = await integrityService.quickCheck();
    if (!quickOk) {
      debugPrint('[Main] Quick check fallito, eseguo verifica completa...');
    }
    
    // Verifica completa
    final result = await integrityService.runFullCheck();
    
    if (!result.isHealthy) {
      debugPrint('[Main] Trovati ${result.issueCount} problemi di integrità');
      
      // Prova a riparare automaticamente
      if (result.fixableIssueCount > 0) {
        debugPrint('[Main] Tento riparazione automatica...');
        final fixed = await integrityService.autoFix(result);
        debugPrint('[Main] Riparati $fixed problemi');
      }
    } else {
      debugPrint('[Main] Database integro');
    }
  } catch (e) {
    debugPrint('[Main] Errore nella verifica integrità: $e');
  }
}

/// Crea un backup automatico se necessario.
Future<void> _createAutoBackup() async {
  try {
    final backupService = BackupService();
    await backupService.createAutoBackupIfNeeded();
  } catch (e) {
    debugPrint('[Main] Errore nel backup automatico: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Stuff Tracker',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      // Localization configuration
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}

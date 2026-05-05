/// Bootstrap condiviso dell'applicazione.
///
/// Questo file è l'unico punto in cui viene eseguita l'inizializzazione
/// dell'app. Separa la logica di avvio dagli entry-point specifici per
/// flavor (`main_dev.dart`, `main_prod.dart`), rispettando il principio
/// **Single Responsibility**: ogni file ha esattamente una ragione di essere
/// modificato.
///
/// Flusso di avvio:
/// ```
/// main_dev.dart / main_prod.dart
///       │
///       └─► bootstrap(Environment) ──► _validateConfig()
///                                   ──► EasyLocalization.ensureInitialized()
///                                   ──► _initializePersistence()
///                                   │     ├─ _runMigration()      (SharedPrefs → Drift)
///                                   │     └─ _createAutoBackup()  (se necessario)
///                                   └─► runApp(MyApp)
/// ```
///
/// **DataIntegrityService** non è incluso nel flusso automatico: disponibile
/// tramite [dataIntegrityServiceProvider] per ispezioni manuali (Debug).
library;

import 'package:amplitude_flutter/amplitude.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/database/database.dart';
import 'core/database/migration_service.dart';
import 'core/database/services/backup_service.dart';
import 'core/routing/app_router.dart';
import 'shared/config/app_config.dart';
import 'shared/providers/language_locale.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/theme/app_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// ENUM Environment
// ═════════════════════════════════════════════════════════════════════════════

/// Descrive l'ambiente di esecuzione dell'applicazione.
///
/// L'enum viene passato a [bootstrap] dall'entry-point specifico del flavor
/// per consentire comportamenti differenziati (es. severità della validazione,
/// banner di debug) senza usare `kDebugMode` che non rappresenta l'ambiente
/// di destinazione, bensì la modalità di compilazione Dart.
enum Environment {
  /// Ambiente di sviluppo locale.
  ///
  /// - Tollera configurazioni API mancanti (warning invece di eccezione).
  /// - Mostra il banner "DEBUG" nell'angolo dell'app.
  /// - Installabile in parallelo alla build prod grazie all'`applicationIdSuffix`.
  dev,

  /// Ambiente di produzione destinato agli utenti finali.
  ///
  /// - Validazione rigorosa: configurazioni mancanti bloccano l'avvio.
  /// - Nessun banner di debug visibile agli utenti.
  prod,
}

// ═════════════════════════════════════════════════════════════════════════════
// BOOTSTRAP
// ═════════════════════════════════════════════════════════════════════════════

/// Punto di bootstrap condiviso per tutti gli entry-point dell'app.
///
/// Riceve l'[env] dall'entry-point del flavor e orchestra in sequenza:
/// 1. Inizializzazione del binding Flutter.
/// 2. Validazione della configurazione (con severità dipendente da [env]).
/// 3. Inizializzazione della localizzazione (async).
/// 4. Pipeline di persistenza: migrazione → backup automatico.
/// 5. Avvio dell'app con [runApp].
///
/// Il blocco `try/catch` globale garantisce che qualsiasi errore non gestito
/// durante l'avvio venga loggato con stack trace leggibile, anziché causare
/// un crash silenzioso con schermata nera.
///
/// Esempio di utilizzo dall'entry-point:
/// ```dart
/// Future<void> main() async => bootstrap(Environment.dev);
/// ```
Future<void> bootstrap(Environment env) async {
  // Deve essere la prima chiamata assoluta: abilita l'interazione con il
  // framework Flutter (channels, plugin, servizi nativi) prima di runApp.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    _validateConfig(env);

    await EasyLocalization.ensureInitialized();

    await Future.wait([
      Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      ),
      Amplitude.getInstance().init(AppConfig.amplitudeApiKey),
      _initializePersistence(),
    ]);

    await SentryFlutter.init(
      (options) {
        options.dsn = AppConfig.sentryDsn;
        options.environment = env.name;
        options.tracesSampleRate = 1.0;
      },
      appRunner: () => runApp(
        EasyLocalization(
          supportedLocales: const [
            Locale('it', 'IT'),
            Locale('en', 'US'),
          ],
          path: 'assets/translations',
          fallbackLocale: const Locale('it', 'IT'),
          child: ProviderScope(
            child: MyApp(environment: env),
          ),
        ),
      ),
    );
  } catch (e, stackTrace) {
    // Catch-all critico: logga il problema con stack trace completo e
    // propaga l'eccezione affinché il framework Flutter mostri la schermata
    // di errore predefinita (rosso su nero in debug, grigio in release).
    debugPrint('[Bootstrap] ❌ ERRORE CRITICO durante l\'avvio: $e');
    debugPrint('[Bootstrap] Stack trace:\n$stackTrace');
    rethrow;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Valida la configurazione dell'app con severità dipendente dall'[env].
///
/// La distinzione è intenzionale:
/// - In [Environment.dev] uno sviluppatore potrebbe non avere ancora tutte
///   le API key configurate localmente; bloccare l'avvio rallenterebbe il
///   ciclo di sviluppo senza benefici reali.
/// - In [Environment.prod] una chiave mancante significa una feature rotta
///   per l'utente finale: è corretto fallire subito e in modo evidente.
void _validateConfig(Environment env) {
  try {
    AppConfig.validate();
  } on StateError catch (e) {
    if (env == Environment.prod) {
      // In produzione la configurazione incompleta è un errore bloccante:
      // un deploy con chiavi mancanti non deve raggiungere gli utenti.
      rethrow;
    }
    // In dev logghiamo il problema senza interrompere lo sviluppo.
    debugPrint('[Bootstrap] ⚠️  Configurazione incompleta (ignorata in dev): $e');
  }
}

/// Inizializza tutti i servizi di persistenza in modo robusto.
///
/// Esegue in ordine sequenziale:
/// 1. **Migrazione**: trasferisce i dati legacy da SharedPreferences a Drift.
/// 2. **Backup**: crea un backup automatico se l'ultimo è troppo vecchio.
///
/// Il [DataIntegrityService] **non viene eseguito automaticamente** all'avvio:
/// SQLite garantisce già l'integrità referenziale tramite FK con `ON DELETE
/// CASCADE/SET NULL` e `PRAGMA foreign_keys = ON`. L'esecuzione automatica
/// causava overhead O(N) ad ogni avvio senza benefici concreti per un DB
/// locale. Il servizio resta disponibile per uso manuale (area Debug) o per
/// sanificare dati migrati dai vecchi JSON tramite [dataIntegrityServiceProvider].
///
/// La connessione [AppDatabase] aperta qui è temporanea e viene chiusa al
/// termine: ogni provider Riverpod creerà la propria connessione lazy al
/// primo utilizzo, evitando contese sull'accesso al file SQLite.
Future<void> _initializePersistence() async {
  debugPrint('[Bootstrap] Inizializzazione persistenza...');

  try {
    final AppDatabase database = AppDatabase();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await _runMigration(database, prefs);

    // CRITICO: chiudi il DB PRIMA del backup automatico.
    // BackupService copia il file raw: in WAL mode il file .db principale
    // non contiene le transazioni più recenti finché la connessione è aperta.
    // Chiudere qui fa flushed il WAL nel file principale e rilascia i lock,
    // garantendo che la copia sia completa e non corrotta.
    await database.close();

    await _createAutoBackup();

    debugPrint('[Bootstrap] ✅ Persistenza inizializzata con successo');
  } catch (e, stackTrace) {
    // Non blocchiamo l'avvio: l'app può funzionare (parzialmente) anche
    // senza persistenza inizializzata, e l'utente vedrà comunque i dati
    // già presenti nel database non corrotto.
    debugPrint('[Bootstrap] ⚠️  Errore nell\'inizializzazione persistenza: $e');
    debugPrint('[Bootstrap] Stack trace:\n$stackTrace');
  }
}

/// Esegue la migrazione da SharedPreferences a Drift, se necessaria.
///
/// La migrazione è idempotente: il [MigrationService] verifica internamente
/// se è già stata eseguita prima di procedere.
Future<void> _runMigration(
  AppDatabase database,
  SharedPreferences prefs,
) async {
  try {
    final MigrationService migrationService = MigrationService(database, prefs);
    final bool success = await migrationService.migrateIfNeeded();

    if (!success) {
      debugPrint('[Bootstrap] ⚠️  Migrazione non completata');
    }
  } catch (e) {
    debugPrint('[Bootstrap] Errore durante la migrazione: $e');
  }
}

/// Crea un backup automatico del database se l'ultimo è troppo vecchio.
///
/// La logica di throttling (es. "non prima di X ore dall'ultimo backup")
/// è delegata al [BackupService] per mantenere questa funzione coesa.
Future<void> _createAutoBackup() async {
  try {
    final BackupService backupService = BackupService();
    await backupService.createAutoBackupIfNeeded();
  } catch (e) {
    debugPrint('[Bootstrap] Errore nel backup automatico: $e');
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ROOT WIDGET
// ═════════════════════════════════════════════════════════════════════════════

/// Widget radice dell'applicazione.
///
/// Riceve l'[environment] per differenziare il comportamento visivo:
/// il banner "DEBUG" è mostrato solo in [Environment.dev] per non
/// confondere gli utenti finali in produzione.
class MyApp extends ConsumerWidget {
  /// L'ambiente di esecuzione corrente.
  final Environment environment;

  const MyApp({required this.environment, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ThemeMode> themeModeAsync =
        ref.watch(themeModeNotifierProvider);

    final localeCode = context.locale.languageCode;
    final currentProviderLocale = ref.read(languageLocaleProvider);
    if (currentProviderLocale != localeCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(languageLocaleProvider.notifier).updateLocale(localeCode);
      });
    }

    return MaterialApp.router(
      title: 'Pack Log',
      // Il banner "DEBUG" è visibile solo in dev per non disorientare
      // gli utenti in produzione con indicatori tecnici.
      debugShowCheckedModeBanner: environment == Environment.dev,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeModeAsync.valueOrNull ?? ThemeMode.dark,
      routerConfig: appRouter,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}

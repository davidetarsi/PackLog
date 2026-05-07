/// Bootstrap condiviso dell'applicazione.
///
/// Questo file è l'unico punto in cui viene eseguita l'inizializzazione
/// dell'app. Separa la logica di avvio dagli entry-point specifici per
/// flavor (`main_dev.dart`, `main_prod.dart`), rispettando il principio
/// **Single Responsibility**: ogni file ha esattamente una ragione di essere
/// modificato.
///
/// Flusso di avvio (anti-ANR):
/// ```
/// main_dev.dart / main_prod.dart
///       │
///       └─► bootstrap(Environment) ──► _validateConfig()
///                                   ──► EasyLocalization.ensureInitialized()
///                                   ──► runApp(MyApp) ← immediato
///                                          │
///                                          └─► MyApp watches appBootstrapProvider
///                                                ├─ loading → splash screen
///                                                └─ data    → MaterialApp.router
///                                                     (Sentry, Supabase, Amplitude,
///                                                      persistence init deferite)
/// ```
///
/// TUTTA l'inizializzazione pesante (Sentry, Supabase, Amplitude, migrazione
/// DB, backup) è deferita DOPO runApp tramite [appBootstrapProvider] per
/// evitare ANR: Android triggera ANR se il main thread resta bloccato >5s
/// prima del primo frame. Sentry viene inizializzato senza appRunner;
/// gli errori sono comunque catturati via FlutterError.onError e
/// PlatformDispatcher.onError.
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
import 'core/sync/sync_provider.dart';
import 'shared/config/app_config.dart';
import 'shared/providers/language_locale.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/theme/app_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// DEFERRED BOOTSTRAP PROVIDER
// ═════════════════════════════════════════════════════════════════════════════

/// Impostato da [bootstrap] prima di [runApp], letto da [appBootstrapProvider].
late Environment _currentEnvironment;

/// Inizializzazione pesante deferita dopo il primo frame.
///
/// Sentry, Supabase, Amplitude e persistenza vengono inizializzati qui
/// anziché in [bootstrap] per evitare ANR su Android: [runApp] viene
/// chiamato subito, e [MyApp] mostra uno splash screen finché questo
/// provider non completa.
///
/// Sentry è inizializzato senza [appRunner] — gli errori sono comunque
/// catturati via [FlutterError.onError] e [PlatformDispatcher.onError].
final appBootstrapProvider = FutureProvider<void>((ref) async {
  final bool sentryEnabled = AppConfig.sentryDsn.isNotEmpty &&
      AppConfig.sentryDsn != 'MISSING_SENTRY_DSN';

  await Future.wait([
    if (sentryEnabled)
      SentryFlutter.init((options) {
        options.dsn = AppConfig.sentryDsn;
        options.environment = _currentEnvironment.name;
        options.tracesSampleRate = 1.0;
      }),
    Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    ),
    Amplitude.getInstance().init(AppConfig.amplitudeApiKey),
    _initializePersistence(),
  ]);

  ref.read(syncOrchestratorProvider);
});

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
/// Esegue solo operazioni veloci prima di [runApp] per evitare ANR:
/// 1. Binding Sentry-compatibile.
/// 2. Validazione configurazione.
/// 3. EasyLocalization (veloce, serve per l'UI).
/// 4. [runApp] immediato — nessun await pesante.
///
/// Tutta l'inizializzazione pesante (Sentry, Supabase, Amplitude, persistenza)
/// è gestita da [appBootstrapProvider] e visualizzata con uno splash screen.
Future<void> bootstrap(Environment env) async {
  SentryWidgetsFlutterBinding.ensureInitialized();
  _currentEnvironment = env;

  try {
    _validateConfig(env);

    await EasyLocalization.ensureInitialized();

    runApp(
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
    );
  } catch (e, stackTrace) {
    debugPrint('[Bootstrap] ERRORE CRITICO durante l\'avvio: $e');
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
/// Osserva [appBootstrapProvider]: mostra uno splash screen durante
/// l'inizializzazione pesante (Supabase, Amplitude, persistenza), poi
/// passa al [MaterialApp.router] con il router completo.
class MyApp extends ConsumerWidget {
  final Environment environment;

  const MyApp({required this.environment, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(appBootstrapProvider);

    return bootstrapState.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: environment == Environment.dev,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, _) => MaterialApp(
        debugShowCheckedModeBanner: environment == Environment.dev,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Errore di avvio: $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
      data: (_) {
        final themeModeAsync = ref.watch(themeModeNotifierProvider);

        final localeCode = context.locale.languageCode;
        final currentProviderLocale = ref.read(languageLocaleProvider);
        if (currentProviderLocale != localeCode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(languageLocaleProvider.notifier).updateLocale(localeCode);
          });
        }

        return MaterialApp.router(
          title: 'Pack Log',
          debugShowCheckedModeBanner: environment == Environment.dev,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeModeAsync.valueOrNull ?? ThemeMode.dark,
          routerConfig: ref.watch(appRouterProvider),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
        );
      },
    );
  }
}

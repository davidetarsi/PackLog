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

import 'dart:async';
import 'dart:io' show Platform;

import 'package:amplitude_flutter/amplitude.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tgram_analytics/tgram_analytics.dart';

import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

import 'core/auth/secure_local_storage.dart';
import 'core/consent/consent_provider.dart';
import 'core/database/database.dart';
import 'core/database/encryption/db_passphrase_service.dart';
import 'core/database/encryption/encryption_migration_service.dart';
import 'core/database/migration_service.dart';
import 'core/monitoring/app_error_observer.dart';
import 'core/monitoring/bootstrap_error_buffer.dart';
import 'core/monitoring/monitoring_service.dart';
import 'core/routing/app_router.dart';
import 'core/sync/sync_provider.dart';
import 'features/onboarding/providers/onboarding_status_provider.dart';
import 'shared/config/app_config.dart';
import 'shared/theme/app_spacing.dart';
import 'shared/providers/language_locale.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/ds_error_state.dart';

// ═════════════════════════════════════════════════════════════════════════════
// DEFERRED BOOTSTRAP PROVIDER
// ═════════════════════════════════════════════════════════════════════════════

/// Impostato da [bootstrap] prima di [runApp], letto da [appBootstrapProvider].
///
/// Nullable e non `late`: [initConsentedAnalytics] è pubblica e viene chiamata
/// anche dalla schermata di login. In produzione a quel punto il bootstrap è
/// già passato di qui, ma un `late` non inizializzato farebbe esplodere la
/// funzione in qualunque contesto che non abbia eseguito [bootstrap] — i test
/// per primi. Meglio un default esplicito che un `LateInitializationError`.
Environment? _environment;

/// Environment corrente, con fallback su [Environment.dev].
///
/// Il fallback è deliberatamente il più conservativo: in dev tgram non parte
/// e Sentry campiona tutto, quindi sbagliare in questa direzione non produce
/// traffico indesiderato verso i backend di produzione.
Environment get _currentEnvironment => _environment ?? Environment.dev;

/// Buffer per eccezioni di bootstrap avvenute prima dell'init di Sentry.
///
/// Viene svuotato in [_initNonCriticalServices] appena Sentry è pronto.
final BootstrapErrorBuffer _bootstrapErrorBuffer = BootstrapErrorBuffer();

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
  // Solo servizi critici per il funzionamento dell'app (local-first).
  // Supabase serve al sync orchestrator, persistence al DB.
  // Il consenso va idratato prima di qualunque altra cosa: `AppAnalyticsService`
  // è fail-closed e scarta ogni evento finché `hasConsent` non è leggibile.
  // Anticiparlo riduce a zero la finestra in cui un utente che ha già
  // acconsentito perderebbe eventi.
  await ref.read(consentServiceProvider).load();

  await Future.wait([
    _guardedInit(
      'Supabase',
      () => Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        // Sessione persistita in Keychain (iOS) / EncryptedSharedPreferences
        // (Android, Keystore-backed). Vedi [SecureLocalStorage] — include
        // anche migrazione one-shot dalle vecchie SharedPreferences.
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureLocalStorage(
            persistSessionKey:
                'sb-${Uri.parse(AppConfig.supabaseUrl).host.split(".").first}-auth-token',
          ),
        ),
      ),
    ),
    _initializePersistence(),
  ]);

  debugPrint('[Bootstrap] Future.wait completato, avvio sync orchestrator...');
  ref.read(syncOrchestratorProvider);
  debugPrint('[Bootstrap] Sync orchestrator inizializzato');

  // Servizi non critici schedulati sull'event queue — la parte sincrona di
  // SentryFlutter.init() (native bindings, integrations) blocca il main
  // thread. Schedulandoli con Future.delayed il provider completa prima,
  // l'UI renderizza, e solo dopo parte l'init pesante.
  // `hasConsent` è già leggibile: `consentServiceProvider.load()` è stato
  // atteso sopra.
  final bool hasConsent = ref.read(consentServiceProvider).hasConsent;
  Future.delayed(Duration.zero, () => _initNonCriticalServices(hasConsent));
  debugPrint('[Bootstrap] ✅ appBootstrapProvider completato');
});

/// Inizializza gli SDK di analytics che richiedono il consenso.
///
/// Separata da [_initNonCriticalServices] perché va invocata **anche** nel
/// momento in cui l'utente presta il consenso, non solo all'avvio: chi apre
/// l'app per la prima volta non ha consenso al bootstrap, e senza questa
/// chiamata resterebbe senza analytics fino al riavvio successivo.
///
/// Idempotente: le chiamate successive alla prima sono no-op.
///
/// **Perché non basta il gate in `AppAnalyticsService`.** Quel gate impedisce
/// di *trasmettere* eventi, ed è già fail-closed. Ma `Amplitude.init()` apre
/// per conto proprio una sessione e raccoglie proprietà del dispositivo: è
/// esso stesso un trattamento, e va quindi posticipato al consenso. Senza
/// questa separazione la dichiarazione "analytics opzionali" nel Data safety
/// di Play sarebbe falsa, e Google rileva Amplitude scansionando l'AAB.
Future<void> initConsentedAnalytics() async {
  if (_consentedAnalyticsStarted) return;
  _consentedAnalyticsStarted = true;

  final bool amplitudeEnabled =
      AppConfig.amplitudeApiKey.isNotEmpty &&
      AppConfig.amplitudeApiKey != 'MISSING_AMPLITUDE_API_KEY';

  if (amplitudeEnabled) {
    await _guardedInit(
      'Amplitude',
      () => Amplitude.getInstance().init(AppConfig.amplitudeApiKey),
    );
  }

  // tgram-analytics: di norma inizializzato SOLO in prod. Il piano free ha
  // quota 1 progetto, quindi lo stream è riservato agli eventi reali — le
  // build dev non devono inquinarlo. Finché `init()` non viene chiamato, il
  // sink tgram in [AppAnalyticsService] è un no-op (non bufferizza), quindi
  // in dev non accumula nulla in memoria.
  //
  // [AppConfig.tgramForceEnable] è la sola deroga: senza di essa le analytics
  // sarebbero verificabili solo dopo una release firmata dalla CI, perché il
  // login Google in prod richiede il keystore di release. Il flag va passato
  // esplicitamente da riga di comando, mai impostato di default.
  final bool tgramEnabled =
      (_currentEnvironment == Environment.prod || AppConfig.tgramForceEnable) &&
      AppConfig.tgramApiKey.isNotEmpty &&
      AppConfig.tgramApiKey != 'MISSING_TGRAM_API_KEY';

  if (tgramEnabled) {
    // Sincrono e non fallibile a runtime (l'unica eccezione possibile è sulla
    // validazione del formato della chiave), ma passa comunque da
    // _guardedInit per uniformità di logging con gli altri servizi.
    await _guardedInit(
      'tgram-analytics',
      () async => TGA.init(AppConfig.tgramApiKey, AppConfig.tgramServerUrl),
    );
  }
}

/// Guardia di idempotenza per [initConsentedAnalytics].
bool _consentedAnalyticsStarted = false;

/// `true` se [initConsentedAnalytics] è già stata eseguita in questa
/// esecuzione dell'app.
@visibleForTesting
bool get consentedAnalyticsStarted => _consentedAnalyticsStarted;

/// Azzera la guardia di [initConsentedAnalytics]. Solo per i test.
@visibleForTesting
void resetConsentedAnalyticsForTest() => _consentedAnalyticsStarted = false;

void _initNonCriticalServices(bool hasConsent) {
  final bool sentryEnabled =
      AppConfig.sentryDsn.isNotEmpty &&
      AppConfig.sentryDsn != 'MISSING_SENTRY_DSN';

  if (sentryEnabled) {
    // Sample rate per env: in dev catturiamo tutto per facilitare il debug,
    // in prod 10% per non bruciare la quota performance al crescere degli utenti.
    final double tracesSampleRate = switch (_currentEnvironment) {
      Environment.prod => 0.1,
      Environment.dev => 1.0,
    };
    _guardedInit(
      'Sentry',
      () => SentryFlutter.init((options) {
        options.dsn = AppConfig.sentryDsn;
        options.environment = _currentEnvironment.name;
        options.tracesSampleRate = tracesSampleRate;
      }),
    ).then((_) => _bootstrapErrorBuffer.flush(AppMonitoringService()));
  }

  // Sentry resta **fuori** dal gate del consenso, deliberatamente: il crash
  // reporting è diagnostico, non profilazione, gira con `sendDefaultPii`
  // disattivato (default) e serve a intercettare i crash che avvengono prima
  // che l'utente possa esprimere qualunque preferenza — cioè proprio quelli
  // che non si riesce a diagnosticare altrimenti.
  //
  // Amplitude e tgram invece sì: vedi [initConsentedAnalytics].
  if (hasConsent) {
    initConsentedAnalytics();
  } else {
    debugPrint('[Bootstrap] analytics in attesa del consenso');
  }
}

Future<void> _guardedInit(String name, Future<dynamic> Function() init) async {
  try {
    await init().timeout(const Duration(seconds: 10));
    debugPrint('[Bootstrap] ✅ $name inizializzato');
  } on TimeoutException {
    debugPrint('[Bootstrap] ⚠️  $name init timeout — proseguo senza');
  } catch (e) {
    debugPrint('[Bootstrap] ⚠️  $name init fallito: $e');
  }
}

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
  // In release silenziamo `debugPrint` globalmente. Motivi:
  // 1. Sicurezza/privacy: log come `[Auth] ...`, `[SyncService] ...`,
  //    `[SupabaseRepo] ...` finiscono in logcat su Android e console su iOS;
  //    su un device condiviso o tramite ADB sono recuperabili. Niente
  //    secret veri (token coperto altrove), ma userId, houseId, conteggi e
  //    messaggi di errore raw sono comunque informazioni di troppo.
  // 2. Performance: ogni `debugPrint` formatta una stringa e fa I/O — su
  //    sync loop o pull frequenti, costa.
  // In dev/profile (`kReleaseMode = false`) lasciamo il comportamento
  // standard di Flutter per debug confortevole.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Usa il binding standard Flutter — idempotente e privo di dipendenze da Sentry.
  // SentryFlutter.init() viene chiamato dopo runApp in [appBootstrapProvider]
  // dove si occupa autonomamente dell'integrazione con FlutterError.onError e
  // PlatformDispatcher.onError (standard Flutter 3.3+).
  // Non usare SentryWidgetsFlutterBinding.ensureInitialized() qui: il custom
  // binding Sentry può causare "Binding has not yet been initialized" quando
  // altri package (es. connectivity_plus, sync orchestrator) accedono a
  // WidgetsBinding.instance prima che Sentry abbia completato la propria init.
  WidgetsFlutterBinding.ensureInitialized();
  _environment = env;

  try {
    _validateConfig(env);

    await EasyLocalization.ensureInitialized();

    final deviceLangCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final startLocale = resolveLocale(deviceLangCode);

    runApp(
      EasyLocalization(
        supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        startLocale: startLocale,
        child: ProviderScope(
          observers: [AppErrorObserver()],
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
    debugPrint(
      '[Bootstrap] ⚠️  Configurazione incompleta (ignorata in dev): $e',
    );
  }
}

/// Inizializza tutti i servizi di persistenza in modo robusto.
///
/// Esegue in ordine sequenziale:
/// 1. **Migrazione SQLCipher**: cifra il DB in chiaro, se necessario.
/// 2. **Migrazione dati**: trasferisce i dati legacy da SharedPreferences a Drift.
///
/// Non esiste più alcun backup automatico su file: la copia di sicurezza è
/// il sync su Supabase. L'unico `.pre-encrypt-backup` che viene creato è
/// temporaneo, interno a [EncryptionMigrationService], e vive nella
/// directory privata dell'app.
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
    // Su Android, dice al package sqlite3 di caricare libsqlcipher.so invece
    // di libsqlite3.so (che non esiste: sqlcipher_flutter_libs shippa solo
    // libsqlcipher.so). Deve avvenire PRIMA di qualsiasi chiamata a sqlite3
    // inclusa EncryptionMigrationService.
    if (Platform.isAndroid) {
      open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
    }

    // Migrazione SQLCipher: deve avvenire PRIMA di qualsiasi apertura del DB.
    // La migration è idempotente: in fresh install genera solo la passphrase.
    final passphraseService = DbPassphraseService();
    final migrationService = await EncryptionMigrationService.withDefaultPaths(
      passphraseService,
    );
    await migrationService.ensureMigrated();

    final AppDatabase database = AppDatabase(passphraseService);
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await _runMigration(database, prefs);

    // Chiudi la connessione usata per la migrazione: i provider Riverpod
    // aprono la propria connessione lazy al primo utilizzo.
    await database.close();

    debugPrint('[Bootstrap] ✅ Persistenza inizializzata con successo');
  } catch (e, stackTrace) {
    _bootstrapErrorBuffer.record('persistence', e, stackTrace);
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
  } catch (e, st) {
    _bootstrapErrorBuffer.record('migration', e, st);
    debugPrint('[Bootstrap] Errore durante la migrazione: $e');
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

  // Builds a MaterialApp (splash/error) or MaterialApp.router (main) sharing
  // all common props. Pass exactly one of [home] or [routerConfig].
  Widget _app(
    BuildContext context, {
    Widget? home,
    RouterConfig<Object>? routerConfig,
    ThemeMode themeMode = ThemeMode.dark,
  }) {
    assert(
      (home == null) != (routerConfig == null),
      'Pass exactly one of home or routerConfig',
    );
    if (routerConfig != null) {
      return MaterialApp.router(
        title: 'Pack Log',
        debugShowCheckedModeBanner: environment == Environment.dev,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: routerConfig,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: environment == Environment.dev,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: home!,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(appBootstrapProvider);

    return bootstrapState.when(
      loading: () => _app(
        context,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, _) => _app(
        context,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Errore di avvio: $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
      data: (_) {
        return ref
            .watch(onboardingStatusProvider)
            .when(
              loading: () => _app(
                context,
                home: const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => _app(
                context,
                home: Scaffold(
                  body: DsErrorState(
                    error: error,
                    onRetry: () => ref.invalidate(onboardingStatusProvider),
                  ),
                ),
              ),
              data: (_) {
                final themeModeAsync = ref.watch(themeModeNotifierProvider);

                final localeCode = context.locale.languageCode;
                final currentProviderLocale = ref.read(languageLocaleProvider);
                if (currentProviderLocale != localeCode) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref
                        .read(languageLocaleProvider.notifier)
                        .updateLocale(localeCode);
                  });
                }

                return _app(
                  context,
                  routerConfig: ref.watch(appRouterProvider),
                  themeMode: themeModeAsync.valueOrNull ?? ThemeMode.dark,
                );
              },
            );
      },
    );
  }
}

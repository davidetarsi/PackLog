import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show DynamicLibrary;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

import 'package:pack_log/bootstrap.dart';
import 'package:pack_log/shared/providers/theme_provider.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/core/auth/auth_provider.dart';
import 'package:pack_log/core/auth/auth_repository.dart';
import 'package:pack_log/core/auth/auth_state.dart';
import 'package:pack_log/core/consent/consent_service.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/database_provider.dart';
import 'package:pack_log/core/routing/app_router.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/core/sync/sync_service.dart';
import 'package:pack_log/features/profile/providers/gpt_usage_provider.dart';
import 'package:pack_log/features/onboarding/providers/onboarding_status_provider.dart';
import 'package:pack_log/features/tour/model/onboarding_state.dart';
import 'package:pack_log/features/tour/providers/post_login_onboarding_provider.dart';
import 'package:pack_log/features/tour/repositories/i_onboarding_repository.dart';
import 'package:pack_log/features/tour/repositories/shared_prefs_onboarding_repository.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';
import 'package:pack_log/shared/model/location_type.dart';
import 'package:pack_log/features/items/model/italian_dictionary.dart';
import 'package:pack_log/features/items/services/category_infer_service.dart';
import 'package:pack_log/features/trips/services/trip_weather_service.dart';
import 'package:pack_log/shared/providers/connectivity_provider.dart';
import 'package:pack_log/shared/services/location_search_service.dart';

import 'fakes.dart';
import 'seed.dart';

/// Telefono di riferimento: Pixel 7 in dp, con status bar e barra gesti.
const kScreenSize = Size(412, 915);
const kPixelRatio = 3.0;
const kStatusBar = 24.0;
const kGestureBar = 16.0;

const _boundaryKey = ValueKey('screenshot-boundary');

/// L'app su Android usa SQLCipher; sull'host Linux il pacchetto `sqlite3`
/// cerca `libsqlite3.so`, che molte distro installano solo come
/// `libsqlite3.so.0` (manca il symlink del pacchetto -dev).
void useSystemSqlite() {
  // Un DB in memoria nuovo per ogni scenario è voluto, non un errore.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  open.overrideFor(OperatingSystem.linux, () {
    try {
      return DynamicLibrary.open('libsqlite3.so');
    } on ArgumentError {
      return DynamicLibrary.open('libsqlite3.so.0');
    }
  });
}

/// Tema con cui girare. Dark è il default dell'app (`ThemeModeNotifier`).
enum ShotTheme { dark, light }

/// Stato di partenza di uno scenario.
class AppSetup {
  final bool onboardingCompleted;
  final bool authenticated;
  final OnboardingStep tourStep;

  /// Casa creata dalla prova AI (`defaultHouseId` del tour).
  final String? tourHouseId;
  final SeedLevel seed;
  final int unsyncedChanges;
  final List<Override> extraOverrides;

  const AppSetup({
    this.onboardingCompleted = true,
    this.authenticated = true,
    this.tourStep = OnboardingStep.done,
    this.tourHouseId,
    this.seed = SeedLevel.full,
    this.unsyncedChanges = 0,
    this.extraOverrides = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Fakes per i servizi che in produzione parlano con la rete o col sistema.
// ─────────────────────────────────────────────────────────────────────────────

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.currentAuthState);

  @override
  final AuthState currentAuthState;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}
}

class _MemoryOnboardingRepository implements IOnboardingRepository {
  _MemoryOnboardingRepository(this._step, this._defaultHouse);

  OnboardingStep _step;
  bool _skipped = false;
  bool _hasHouses = false;
  String? _defaultHouse;

  @override
  Future<OnboardingStep> loadStep() async => _step;
  @override
  Future<void> saveStep(OnboardingStep step) async => _step = step;
  @override
  Future<bool> loadSkippedAi() async => _skipped;
  @override
  Future<void> saveSkippedAi(bool value) async => _skipped = value;
  @override
  Future<bool> loadHasExistingHouses() async => _hasHouses;
  @override
  Future<void> saveHasExistingHouses(bool value) async => _hasHouses = value;
  @override
  Future<String?> loadDefaultHouseId() async => _defaultHouse;
  @override
  Future<void> saveDefaultHouseId(String? id) async => _defaultHouse = id;
}

/// Ricerca di luoghi senza rete: tre città fisse, filtrate sul nome.
class _FakeLocationSearch extends LocationSearchService {
  static final _places = [
    for (final (name, country, lat, lon) in const [
      ('Lisbona', 'Portogallo', 38.7223, -9.1393),
      ('Sintra', 'Portogallo', 38.7980, -9.3900),
      ('Siviglia', 'Spagna', 37.3891, -5.9845),
    ])
      LocationSuggestionModel(
        placeId: 'fake-$name',
        displayName: '$name, $country',
        name: name,
        city: name,
        country: country,
        locationType: LocationType.city,
        lat: lat,
        lon: lon,
      ),
  ];

  @override
  Future<List<LocationSuggestionModel>> search(
    String query, {
    required String lang,
  }) async {
    final q = query.trim().toLowerCase();
    return _places
        .where((place) => place.name!.toLowerCase().contains(q))
        .toList();
  }
}

class _MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

class _OnlineConnectivity extends ConnectivityNotifier {
  @override
  bool build() => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Harness
// ─────────────────────────────────────────────────────────────────────────────

/// Un'istanza dell'app vera (router, shell, tema, traduzioni) con DB in
/// memoria e servizi esterni sostituiti da fake.
class ScreenshotApp {
  ScreenshotApp._(
    this.tester,
    this.container,
    this.db,
    this.issues,
    this._restoreErrorHandler,
  );

  final WidgetTester tester;
  final ProviderContainer container;
  final AppDatabase db;

  /// Problemi di layout visti durante lo scenario (overflow).
  final List<String> issues;
  final void Function() _restoreErrorHandler;

  GoRouter get router => container.read(appRouterProvider);

  static Future<ScreenshotApp> start(
    WidgetTester tester, {
    required ShotTheme theme,
    AppSetup setup = const AppSetup(),
  }) async {
    tester.view.physicalSize = kScreenSize * kPixelRatio;
    tester.view.devicePixelRatio = kPixelRatio;
    tester.view.padding = const FakeViewPadding(
      top: kStatusBar * kPixelRatio,
      bottom: kGestureBar * kPixelRatio,
    );
    tester.view.viewPadding = tester.view.padding;
    addTearDown(tester.view.reset);

    // flutter_test disegna le elevation come un contorno nero pieno al posto
    // dell'ombra (`debugDisableShadows` è true nei test): negli screenshot i
    // bottoni tondi e lo speed-dial sembravano avere un bordo nero spesso che
    // sul telefono non c'è. Qui vogliamo le ombre vere; [finish] rimette il
    // valore di default prima della fine del test, che flutter_test verifica.
    debugDisableShadows = false;

    // Il bundle tiene in cache il Future delle traduzioni nato nel test
    // precedente: riusarlo lascia Localizations in attesa per sempre.
    rootBundle.clear();

    // Su un telefono in italiano `findSystemLocale()` restituisce it_IT e i
    // `DateFormat` senza locale esplicito formattano "9 ott". Sull'host Linux
    // verrebbe en_US ("9 Oct").
    Intl.systemLocale = 'it_IT';

    SharedPreferences.setMockInitialValues({
      'onboarding_completed': setup.onboardingCompleted,
      'theme_mode': theme.name,
    });
    PackageInfo.setMockInitialValues(
      appName: 'PackLog',
      packageName: 'com.packlog.app',
      version: '1.1.3',
      buildNumber: '6',
      buildSignature: '',
    );

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final sync = _MockSyncOrchestrator();
    when(() => sync.requestSync()).thenReturn(null);
    when(() => sync.requestForcedSync()).thenReturn(null);

    final auth = setup.authenticated
        ? const AuthState.authenticated(
            userId: 'user-1',
            email: 'davide.rossi@example.com',
            displayName: 'Davide Rossi',
          )
        : const AuthState.unauthenticated();

    final container = ProviderContainer(
      overrides: [
        appBootstrapProvider.overrideWith((ref) async {}),
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(auth)),
        onboardingRepositoryProvider.overrideWithValue(
          _MemoryOnboardingRepository(setup.tourStep, setup.tourHouseId),
        ),
        // Consenso mai caricato → gate fail-closed: nessun evento parte.
        analyticsServiceProvider.overrideWithValue(
          AppAnalyticsService(null, consent: ConsentService()),
        ),
        syncOrchestratorProvider.overrideWithValue(sync),
        // Niente Geoapify nei test: la ricerca delle mete è finta.
        locationSearchServiceProvider.overrideWithValue(_FakeLocationSearch()),
        // Niente Open-Meteo nei test: il meteo della valigia è finto.
        tripWeatherServiceProvider.overrideWithValue(FakeTripWeather()),
        connectivityNotifierProvider.overrideWith(_OnlineConnectivity.new),
        totalUnsyncedCountProvider.overrideWith(
          (ref) async => setup.unsyncedChanges,
        ),
        syncUnsyncedBreakdownProvider.overrideWith(
          (ref) async => [
            if (setup.unsyncedChanges > 0)
              SyncEntityStatus(
                entityLabelKey: 'profile.sync_entity_items',
                count: setup.unsyncedChanges,
                reasonKey: 'profile.sync_reason_network',
              ),
          ],
        ),
        gptUsageProvider.overrideWith(
          (ref) async => const GptUsageModel(usageCount: 12, usageCap: 30),
        ),
        // Il dizionario remoto passa da Supabase, che qui non c'è: si usa
        // quello incluso nell'app, come fa l'app quando il remoto non risponde.
        categoryInferServiceProvider.overrideWith(
          (ref) async => CategoryInferService(ItalianDictionary()),
        ),
        ...setup.extraOverrides,
      ],
    );

    await tester.runAsync(() async {
      await seed(container, setup.seed);
      // `MyApp` crea il router solo a bootstrap concluso e onboarding letto,
      // e il redirect del router non fa nulla finché il bootstrap è in
      // corso: li risolviamo prima, così il primo redirect è quello giusto.
      await container.read(appBootstrapProvider.future);
      await container.read(onboardingStatusProvider.future);
      await container.read(postLoginOnboardingProvider.future);
    });

    // Gli overflow sono difetti reali della UI, non del test: li registriamo
    // nel manifest invece di far fallire lo scenario, così lo screenshot (con
    // la banda gialla/nera) arriva comunque a chi deve sistemarlo.
    final issues = <String>[];
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('overflowed')) {
        issues.add(_describeOverflow(details, message));
        return;
      }
      originalOnError?.call(details);
    };

    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundaryKey,
        child: EasyLocalization(
          supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          startLocale: const Locale('it', 'IT'),
          useOnlyLangCode: false,
          child: UncontrolledProviderScope(
            container: container,
            child: const _ScreenshotMaterialApp(),
          ),
        ),
      ),
    );

    final app = ScreenshotApp._(
      tester,
      container,
      db,
      issues,
      () => FlutterError.onError = originalOnError,
    );
    await app.settle();
    return app;
  }

  /// Smonta l'app e libera container e DB dentro il test.
  ///
  /// Va fatto qui e non in `addTearDown`: `TripNotifier` programma un timer
  /// di refresh, e flutter_test verifica che non ci siano timer pendenti
  /// subito dopo il corpo del test, prima dei tearDown.
  Future<void> finish() async {
    _restoreErrorHandler();
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.runAsync(db.close);
    await tester.pump();
    debugDisableShadows = true;
  }

  /// Fa avanzare il tempo finché la UI si stabilizza.
  ///
  /// Niente `pumpAndSettle`: skeleton shimmer e spinner animano all'infinito
  /// e lo farebbero andare in timeout. Il DB (sqlite in memoria) e il
  /// caricamento delle traduzioni hanno bisogno di I/O vero: diamo loro un
  /// giro di `runAsync` a ogni passo.
  Future<void> settle({int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> go(String location) async {
    router.go(location);
    await settle();
  }

  Future<void> push(String location) async {
    unawaited(router.push(location));
    await settle();
  }

  Future<void> tap(Finder finder, {int frames = 12}) async {
    await tester.tap(finder.first, warnIfMissed: false);
    await settle(frames: frames);
  }

  Future<void> longPress(Finder finder) async {
    await tester.longPress(finder.first, warnIfMissed: false);
    await settle();
  }

  Future<void> enterText(Finder finder, String text) async {
    await tester.enterText(finder.first, text);
    await settle(frames: 4);
  }

  /// Decodifica le immagini a schermo: fuori da `runAsync` resterebbero
  /// segnaposto vuoti nel PNG.
  Future<void> _precacheImages() async {
    final images = find.byType(Image).evaluate().toList();
    if (images.isEmpty) return;
    await tester.runAsync(() async {
      for (final element in images) {
        final widget = element.widget as Image;
        await precacheImage(widget.image, element);
      }
    });
    await tester.pump();
  }

  Future<void> capture(Shot shot) async {
    await _precacheImages();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundaryKey),
    );
    final bytes = await tester.runAsync(() async {
      final layer = boundary.debugLayer! as OffsetLayer;
      final image = await layer.toImage(
        boundary.paintBounds,
        pixelRatio: kPixelRatio,
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    final file = File(shot.path)..createSync(recursive: true);
    file.writeAsBytesSync(bytes!);
    Manifest.add(shot, issues.toSet().toList());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Manifest
// ─────────────────────────────────────────────────────────────────────────────

const kOutputDir = 'build/ui-screenshots';

class Shot {
  final String flow;
  final String flowTitle;
  final int order;
  final String screen;
  final String state;
  final String source;
  final String description;
  final String? route;
  final ShotTheme theme;

  const Shot({
    required this.flow,
    required this.flowTitle,
    required this.order,
    required this.screen,
    required this.state,
    required this.source,
    required this.description,
    required this.theme,
    this.route,
  });

  String get fileName =>
      '${order.toString().padLeft(2, '0')}-$screen-$state-${theme.name}.png';

  String get path => '$kOutputDir/$flow/$fileName';

  Map<String, Object?> toJson() => {
    'flow': flow,
    'flowTitle': flowTitle,
    'order': order,
    'screen': screen,
    'state': state,
    'theme': theme.name,
    'file': '$flow/$fileName',
    'source': source,
    'route': route,
    'description': description,
    'size': {
      'width': kScreenSize.width,
      'height': kScreenSize.height,
      'pixelRatio': kPixelRatio,
    },
  };
}

class Manifest {
  static final List<(Shot, List<String>)> _shots = [];

  static void add(Shot shot, List<String> issues) => _shots.add((shot, issues));

  static void write() {
    if (_shots.isEmpty) return;
    final file = File('$kOutputDir/manifest.json');
    // Fusione col manifest esistente: si può rigenerare un solo flusso
    // (`--plain-name`) senza perdere le voci degli altri.
    final existing = <String, Map<String, Object?>>{};
    if (file.existsSync()) {
      final decoded = jsonDecode(file.readAsStringSync()) as Map;
      for (final e in (decoded['screens'] as List)) {
        final m = Map<String, Object?>.from(e as Map);
        existing[m['file']! as String] = m;
      }
    }
    for (final (s, issues) in _shots) {
      existing['${s.flow}/${s.fileName}'] = {...s.toJson(), 'issues': issues};
    }
    final screens = existing.values.toList()
      ..sort((a, b) {
        final byFlow = (a['flow']! as String).compareTo(b['flow']! as String);
        if (byFlow != 0) return byFlow;
        final byOrder = (a['order']! as int).compareTo(b['order']! as int);
        if (byOrder != 0) return byOrder;
        return (a['theme']! as String).compareTo(b['theme']! as String);
      });
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'generatedAt': DateTime.now().toIso8601String(),
          'device': 'Pixel 7 (412x915 dp)',
          'locale': 'it-IT',
          'screens': screens,
        }),
      );
  }
}

/// "RenderFlex overflowed by 48 pixels on the right — Row lib/...:120:12"
String _describeOverflow(FlutterErrorDetails details, String message) {
  final summary = message.split('\n').first.trim();
  final text = details.toString();
  final match = RegExp(
    r'relevant error-causing widget was:\s*\n\s*(\S+)\s+\S*?(lib/[^\s:]+:\d+:\d+)',
  ).firstMatch(text);
  if (match == null) return summary;
  return '$summary — ${match.group(1)} ${match.group(2)}';
}

/// Il ramo "pronto" di `MyApp` (bootstrap.dart), con una sola differenza.
///
/// `appBarTheme.titleTextStyle` non dichiara `fontFamily`: su Android ricade
/// sul font di sistema (Roboto, lo stesso di 'sans-serif'), ma il motore di
/// `flutter test` ha come font di sistema "FlutterTest", che disegna ogni
/// parola come un rettangolo pieno. Qui il titolo riceve esplicitamente
/// 'sans-serif', cioè ciò che il telefono mostra comunque.
///
/// Gli altri rami di `MyApp` (splash, errore di bootstrap) non servono: il
/// bootstrap è sostituito da un Future già risolto.
class _ScreenshotMaterialApp extends ConsumerWidget {
  const _ScreenshotMaterialApp();

  static ThemeData _withAppBarFont(ThemeData theme) => theme.copyWith(
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: AppTheme.fontFamily,
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(themeModeNotifierProvider).valueOrNull ?? ThemeMode.dark;
    return MaterialApp.router(
      title: 'Pack Log',
      debugShowCheckedModeBanner: false,
      theme: _withAppBarFont(AppTheme.light),
      darkTheme: _withAppBarFont(AppTheme.dark),
      themeMode: themeMode,
      routerConfig: ref.watch(appRouterProvider),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}

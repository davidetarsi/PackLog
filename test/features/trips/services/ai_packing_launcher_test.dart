import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/items/services/category_infer_service.dart';
import 'package:pack_log/features/kits/providers/kit_provider.dart';
import 'package:pack_log/features/kits/model/kit_model.dart';
import 'package:pack_log/features/luggages/repositories/luggage_repository.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/ai_packing_request.dart';
import 'package:pack_log/features/trips/model/pack_trip_job.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/providers/trip_weather_provider.dart';
import 'package:pack_log/features/trips/services/trip_weather_service.dart';
import 'package:pack_log/features/trips/view/widgets/pack/pack_weather.dart';
import 'package:pack_log/features/trips/providers/ai_packing_run_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/ai_packing_launcher.dart';
import 'package:pack_log/features/trips/services/pack_trip_service.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_choice_pill.dart';
import 'package:pack_log/shared/widgets/ds_dialog.dart';
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/catalogo_di_prova.dart';
import '../../../helpers/memory_asset_loader.dart';

class _MockTripRepository extends Mock implements TripRepository {}

class _MockHouseRepository extends Mock implements HouseRepository {}

class _MockItemRepository extends Mock implements ItemRepository {}

class _MockLuggageRepository extends Mock implements LuggageRepository {}

/// `pack-trip` che non risponde finché il test non vuole.
class _HangingService extends PackTripService {
  _HangingService() : super(token: () => 'jwt');
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<AiPackingResult> generate(
    Map<String, dynamic> body, {
    required String houseId,
  }) {
    bodies.add(body);
    return Completer<AiPackingResult>().future;
  }
}

/// Meteo finto: conta le richieste.
class _FakeWeather extends TripWeatherService {
  int calls = 0;

  @override
  Future<TripWeather> fetch(TripWeatherRequest request) async {
    calls++;
    return TripWeather(
      signature: request.signature,
      fetchedAt: DateTime.now(),
      stops: [
        for (final stop in request.stops)
          StopWeather(
            name: stop.name,
            from: stop.from,
            to: stop.to,
            source: WeatherSource.forecast,
            tempMin: 3,
            tempMax: 9,
          ),
      ],
    );
  }
}

class _Kits extends KitNotifier {
  @override
  Future<List<KitModel>> build(String houseId) async => const [];
}

final _milano = HouseModel(
  id: 'h1',
  name: 'Casa Milano',
  isPrimary: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _partenza = DateTime.now().add(const Duration(days: 10));

TripModel _trip({List<TripItem> items = const [], bool withCoords = true}) =>
    TripModel(
      id: 'trip-1',
      name: 'Islanda',
      items: items,
      destinationLocation: LocationSuggestionModel(
        placeId: 'p-rey',
        displayName: 'Reykjavik, Islanda',
        city: 'Reykjavik',
        country: 'Islanda',
        lat: withCoords ? 64.1 : null,
        lon: withCoords ? -21.9 : null,
      ),
      departureDateTime: _partenza,
      returnDateTime: _partenza.add(const Duration(days: 5)),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

final _maglietta = TripItem(
  id: 'i1',
  name: 'Maglietta',
  category: ItemCategory.vestiti,
  quantity: 1,
  originHouseId: 'h1',
);

void main() {
  late _HangingService service;
  late String location;
  late ProviderContainer container;
  late List<TripModel> savedTrips;
  late _FakeWeather weather;
  AiPackingSetup? returned;
  var called = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pumpLauncher(
    WidgetTester tester, {
    required TripModel trip,
    bool isNew = false,
    bool saved = true,
  }) async {
    // La cache del meteo vive nelle preferenze: ogni prova parte vuota.
    SharedPreferences.setMockInitialValues({});
    caricaCatalogoDelRepo();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    service = _HangingService();
    returned = null;
    called = false;
    final tripRepo = _MockTripRepository();
    final houseRepo = _MockHouseRepository();
    final itemRepo = _MockItemRepository();
    final luggageRepo = _MockLuggageRepository();
    savedTrips = saved ? [trip] : [];
    weather = _FakeWeather();
    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => savedTrips);
    when(() => houseRepo.getAllHouses()).thenAnswer((_) async => [_milano]);
    when(() => itemRepo.getItemsByHouseId(any())).thenAnswer((_) async => []);
    when(() => luggageRepo.getAllLuggages()).thenAnswer((_) async => []);
    when(
      () => luggageRepo.getLuggagesByHouseId(any()),
    ).thenAnswer((_) async => []);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () async {
                  returned = await startAiPacking(
                    context,
                    ref,
                    trip: trip,
                    isNew: isNew,
                  );
                  called = true;
                },
                child: const Text('avvia'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/ai-packing',
          builder: (context, state) {
            location = state.uri.path;
            return const Scaffold(body: Text('In attesa'));
          },
        ),
      ],
    );
    location = '/';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(tripRepo),
          houseRepositoryProvider.overrideWithValue(houseRepo),
          itemRepositoryProvider.overrideWithValue(itemRepo),
          luggageRepositoryProvider.overrideWithValue(luggageRepo),
          categoryInferServiceProvider.overrideWith(
            (ref) => Completer<CategoryInferService>().future,
          ),
          packTripServiceProvider.overrideWithValue(service),
          tripWeatherServiceProvider.overrideWithValue(weather),
          kitNotifierProvider('h1').overrideWith(_Kits.new),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
          path: 'assets/translations',
          assetLoader: MemoryAssetLoader(readAppTranslations()),
          fallbackLocale: const Locale('en', 'US'),
          startLocale: const Locale('it', 'IT'),
          saveLocale: false,
          child: Builder(
            builder: (context) => MaterialApp.router(
              theme: AppTheme.light,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.text('avvia')));
    // Le case si leggono prima del tocco, come nell'app.
    await container.read(houseNotifierProvider.future);
  }

  Future<void> tapStart(WidgetTester tester) async {
    await tester.tap(find.text('avvia'));
    await tester.pumpAndSettle();
  }

  Future<void> confirmSheet(WidgetTester tester) async {
    for (final label in ['Città e musei', 'Hotel']) {
      final pill = find.descendant(
        of: find.byType(DsFormSheet),
        matching: find.widgetWithText(DsChoicePill, label),
      );
      if (pill.evaluate().isNotEmpty &&
          !tester.widget<DsChoicePill>(pill).selected) {
        final text = find.descendant(
          of: find.byType(DsFormSheet),
          matching: find.text(label),
        );
        await tester.ensureVisible(text);
        await tester.pumpAndSettle();
        await tester.tap(text);
        await tester.pumpAndSettle();
      }
    }
    final prepare = find.descendant(
      of: find.byType(DsFormSheet),
      matching: find.text('Prepara la valigia'),
    );
    await tester.ensureVisible(prepare);
    await tester.pumpAndSettle();
    await tester.tap(prepare);
    await tester.pumpAndSettle();
  }

  testWidgets('busy_shows_snackbar_and_no_sheet', (tester) async {
    await pumpLauncher(tester, trip: _trip());
    final notifier = container.read(aiPackingRunProvider.notifier);
    notifier.start(
      AiPackingRequest(
        trip: _trip(),
        isNew: false,
        setup: const AiPackingSetup(houseId: 'h1'),
        job: PackTripJob(body: {}, houseId: 'h1', title: 'X', nights: 1),
      ),
    );

    await tapStart(tester);

    expect(
      find.text('Sto già preparando una valigia: ti avviso quando è pronta.'),
      findsOneWidget,
    );
    expect(find.byType(DsFormSheet), findsNothing);
    expect(called, isTrue);
    expect(returned, isNull);
  });

  testWidgets('unavailable_shows_reason', (tester) async {
    await pumpLauncher(tester, trip: _trip(withCoords: false));

    await tapStart(tester);

    expect(
      find.text(
        'Una tappa non ha ancora una posizione sulla mappa: impostala per preparare la valigia con AI.',
      ),
      findsOneWidget,
    );
    expect(find.byType(DsFormSheet), findsNothing);
    expect(returned, isNull);
  });

  testWidgets('existing_items_ask_confirmation_only_when_not_new', (
    tester,
  ) async {
    await pumpLauncher(tester, trip: _trip(items: [_maglietta]));
    await tapStart(tester);
    expect(find.text('Vuoi sostituire la valigia?'), findsOneWidget);
    expect(find.byType(DsDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(DsDialog),
        matching: find.text('Annulla'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DsFormSheet), findsNothing);
    expect(returned, isNull);

    await pumpLauncher(tester, trip: _trip(items: [_maglietta]), isNew: true);
    await tapStart(tester);
    expect(find.text('Vuoi sostituire la valigia?'), findsNothing);
    expect(find.byType(DsFormSheet), findsOneWidget);
  });

  testWidgets('sheet_closed_starts_nothing', (tester) async {
    await pumpLauncher(tester, trip: _trip());
    await tapStart(tester);
    expect(find.byType(DsFormSheet), findsOneWidget);

    // Il tocco sullo sfondo chiude il foglio.
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();

    expect(returned, isNull);
    expect(called, isTrue);
    expect(container.read(aiPackingRunProvider), isA<AiRunIdle>());
    expect(location, '/');
    expect(service.bodies, isEmpty);
  });

  testWidgets('confirmed_starts_run_and_opens_wait', (tester) async {
    await pumpLauncher(tester, trip: _trip());
    await tapStart(tester);
    await confirmSheet(tester);

    expect(returned?.houseId, 'h1');
    final state = container.read(aiPackingRunProvider);
    expect(state, isA<AiRunRunning>());
    final request = (state as AiRunRunning).request;
    expect(request.isNew, isFalse);
    expect(request.setup.houseId, 'h1');
    expect(request.job.houseId, 'h1');
    expect(request.job.title, 'Reykjavik');
    // Prima valigia: niente rigenerazione e nessuna risposta cambiata.
    expect(request.job.isRegeneration, isFalse);
    expect(request.job.setupChanged, isEmpty);
    expect(location, '/ai-packing');
    expect(find.text('In attesa'), findsOneWidget);
    expect(service.bodies, hasLength(1));
  });

  testWidgets('regeneration_sets_job_flags', (tester) async {
    final before = _trip().copyWith(
      aiSetup: const AiPackingSetup(houseId: 'h1', luggageId: 'vecchio'),
      aiResult: AiPackingResult(
        generatedAt: DateTime(2026),
        houseId: 'h1',
        proposal: const [],
      ),
    );
    await pumpLauncher(tester, trip: before);
    await tapStart(tester);
    await confirmSheet(tester);

    final request =
        (container.read(aiPackingRunProvider) as AiRunRunning).request;
    expect(request.job.isRegeneration, isTrue);
    expect(request.job.setupChanged, contains('luggage'));
    expect(request.job.luggage, request.luggage);
  });

  testWidgets('new_trip_has_no_setup_changed', (tester) async {
    // Bozza di risposte rimasta da un tentativo precedente.
    final draft = _trip().copyWith(
      aiSetup: const AiPackingSetup(houseId: 'h1', luggageId: 'vecchio'),
    );
    await pumpLauncher(tester, trip: draft, isNew: true);
    await tapStart(tester);
    await confirmSheet(tester);

    final request =
        (container.read(aiPackingRunProvider) as AiRunRunning).request;
    expect(request.isNew, isTrue);
    expect(request.job.isRegeneration, isFalse);
    expect(request.job.setupChanged, isEmpty);
  });

  testWidgets('sheet_shows_stop_weather_for_unsaved_trip', (tester) async {
    // La scheda meteo compare per tappa: serve un viaggio con più tappe.
    final trip = _trip().copyWith(
      legs: [
        TripLeg(
          id: 'leg-1',
          locationDisplayName: 'Oslo, Norvegia',
          from: _partenza.add(const Duration(days: 3)),
          to: _partenza.add(const Duration(days: 5)),
          lat: 59.9,
          lon: 10.7,
          country: 'Norvegia',
        ),
      ],
    );
    await pumpLauncher(tester, trip: trip, isNew: true, saved: false);
    await container.read(tripNotifierProvider.future);
    await tapStart(tester);

    expect(find.byType(DsFormSheet), findsOneWidget);
    expect(find.byType(WeatherStopCard), findsOneWidget);
    expect(find.text('3° / 9°'), findsOneWidget);
    // Una sola richiesta, anche con due tappe.
    expect(weather.calls, 1);
  });

  testWidgets('new_trip_finished_has_weather_from_sheet', (tester) async {
    await pumpLauncher(tester, trip: _trip(), isNew: true, saved: false);
    await container.read(tripNotifierProvider.future);
    await tapStart(tester);
    await confirmSheet(tester);

    final request =
        (container.read(aiPackingRunProvider) as AiRunRunning).request;
    expect(request.weather?.stops.single.tempMax, 9);
    // Una sola richiesta, quella del foglio.
    expect(weather.calls, 1);
  });

  testWidgets('saved_new_trip_reuses_weather_without_new_request', (
    tester,
  ) async {
    final trip = _trip();
    await pumpLauncher(tester, trip: trip, isNew: true, saved: false);
    await container.read(tripNotifierProvider.future);
    await tapStart(tester);
    await confirmSheet(tester);
    expect(weather.calls, 1);

    // La valigia arriva e il viaggio si salva: il dettaglio non richiede.
    savedTrips = [trip];
    container.invalidate(tripNotifierProvider);
    final state = await container.read(
      tripWeatherNotifierProvider(trip.id).future,
    );
    expect(state, isA<TripWeatherReady>());
    expect(weather.calls, 1);
  });
}

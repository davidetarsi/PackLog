import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/kits/model/kit_model.dart';
import 'package:pack_log/features/kits/providers/kit_provider.dart';
import 'package:pack_log/features/luggages/repositories/luggage_repository.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/providers/trip_weather_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/trip_detail_screen.dart';
import 'package:pack_log/features/trips/view/widgets/trip_changed_notice.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/catalogo_di_prova.dart';
import '../../../helpers/memory_asset_loader.dart';

class _MockTripRepository extends Mock implements TripRepository {}

class _MockHouseRepository extends Mock implements HouseRepository {}

class _MockItemRepository extends Mock implements ItemRepository {}

class _MockLuggageRepository extends Mock implements LuggageRepository {}

class _MockLifecycle extends Mock implements TripLifecycleService {}

class _MockSync extends Mock implements SyncOrchestrator {}

class _MockAnalytics extends Mock implements CoreAnalyticsService {}

class _Weather extends TripWeatherNotifier {
  @override
  Future<TripWeatherState> build(String tripId) async =>
      const TripWeatherNotAvailable(WeatherUnavailable.past);
}

class _NoKits extends KitNotifier {
  @override
  Future<List<KitModel>> build(String houseId) async => const [];
}

final _casa = HouseModel(
  id: 'h1',
  name: 'Casa',
  isPrimary: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _partenza = DateTime.now().add(const Duration(days: 10));

TripModel _base() => TripModel(
  id: 'trip-1',
  name: 'Islanda',
  items: [
    TripItem(
      id: 'i-1',
      name: 'Maglietta',
      category: ItemCategory.vestiti,
      quantity: 1,
    ),
  ],
  destinationLocation: LocationSuggestionModel(
    placeId: 'p-rey',
    displayName: 'Reykjavik, Islanda',
    city: 'Reykjavik',
    country: 'Islanda',
    lat: 64.1,
    lon: -21.9,
  ),
  departureDateTime: _partenza,
  returnDateTime: _partenza.add(const Duration(days: 5)),
  transports: const ['treno'],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

AiSlot _slot() => const AiSlot(
  id: 's1',
  type: 'giacca',
  category: ItemCategory.vestiti,
  level: AiSlotLevel.useful,
  name: 'Giacca',
  copies: 1,
  remaining: 1,
  addLabel: 'Aggiungi',
);

/// Viaggio con la valigia fatta per [base]; [changed] cambia il viaggio dopo.
TripModel _trip({bool changed = true, bool dismissed = false}) {
  final base = _base();
  final withResult = base.copyWith(
    aiResult: AiPackingResult(
      generatedAt: DateTime(2026, 11),
      houseId: 'h1',
      slots: [_slot()],
      tripShape: AiTripShape.of(base),
      changeNoticeDismissed: dismissed,
    ),
  );
  return changed
      ? withResult.copyWith(transports: const ['aereo'])
      : withResult;
}

void main() {
  late _MockTripRepository tripRepo;
  late _MockHouseRepository houseRepo;
  late _MockItemRepository itemRepo;
  late _MockLuggageRepository luggageRepo;
  late _MockLifecycle lifecycle;
  late _MockSync sync;
  late _MockAnalytics analytics;
  late List<String> visited;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(_base());
  });

  setUp(() {
    caricaCatalogoDelRepo();
    SharedPreferences.setMockInitialValues({});
    tripRepo = _MockTripRepository();
    houseRepo = _MockHouseRepository();
    itemRepo = _MockItemRepository();
    luggageRepo = _MockLuggageRepository();
    lifecycle = _MockLifecycle();
    sync = _MockSync();
    analytics = _MockAnalytics();
    visited = [];
    when(
      () => lifecycle.transferItemsForCompletedTrips(any()),
    ).thenAnswer((_) async => <String>{});
    when(() => lifecycle.computeNextStatusChange(any())).thenReturn(null);
    when(() => sync.requestSync()).thenReturn(null);
    when(() => tripRepo.updateTrip(any())).thenAnswer((_) async {});
    when(() => houseRepo.getAllHouses()).thenAnswer((_) async => [_casa]);
    when(() => itemRepo.getItemsByHouseId(any())).thenAnswer((_) async => []);
    when(() => luggageRepo.getAllLuggages()).thenAnswer((_) async => []);
    when(
      () => luggageRepo.getLuggagesByHouseId(any()),
    ).thenAnswer((_) async => []);
  });

  Future<void> pumpDetail(WidgetTester tester, TripModel trip) async {
    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [trip]);
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/trips/trip-1',
      routes: [
        GoRoute(
          path: '/trips/:id',
          builder: (context, state) =>
              TripDetailScreen(tripId: state.pathParameters['id']!),
        ),
        // Ogni altra pagina aperta dal dettaglio si nota nel test.
        GoRoute(
          path: '/trips/:id/edit-items',
          builder: (context, state) {
            visited.add(state.uri.toString());
            return const Scaffold(body: Text('Pagina valigia'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(tripRepo),
          houseRepositoryProvider.overrideWithValue(houseRepo),
          itemRepositoryProvider.overrideWithValue(itemRepo),
          luggageRepositoryProvider.overrideWithValue(luggageRepo),
          tripLifecycleServiceProvider.overrideWithValue(lifecycle),
          coreAnalyticsServiceProvider.overrideWithValue(analytics),
          syncOrchestratorProvider.overrideWithValue(sync),
          tripWeatherNotifierProvider('trip-1').overrideWith(_Weather.new),
          kitNotifierProvider('h1').overrideWith(_NoKits.new),
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
  }

  final notice = find.byType(TripChangedNotice);
  const noticeText =
      'Hai cambiato il viaggio: la valigia potrebbe non andare '
      'più bene.';

  testWidgets('notice_shows_when_outdated', (tester) async {
    await pumpDetail(tester, _trip());
    expect(notice, findsOneWidget);
    expect(find.text(noticeText), findsOneWidget);
    expect(find.text('Rifalla con AI'), findsOneWidget);
  });

  testWidgets('notice_hidden_when_trip_unchanged_or_dismissed', (tester) async {
    await pumpDetail(tester, _trip(changed: false));
    expect(notice, findsNothing);
    await tester.pumpWidget(const SizedBox());
    await pumpDetail(tester, _trip(dismissed: true));
    expect(notice, findsNothing);
  });

  testWidgets('notice_action_starts_ai_on_detail', (tester) async {
    await pumpDetail(tester, _trip());

    await tester.tap(find.byKey(const Key('trip_changed_redo')));
    await tester.pumpAndSettle();
    expect(find.text('Vuoi sostituire la valigia?'), findsOneWidget);
    await tester.tap(find.text('Sostituisci'));
    await tester.pumpAndSettle();

    // Il foglio sta sopra il dettaglio: nessuna navigazione a edit-items, e
    // l'avviso resta finché la valigia nuova non arriva.
    expect(find.byType(DsFormSheet), findsOneWidget);
    expect(find.text('Valigia con AI'), findsOneWidget);
    expect(visited, isEmpty);
    expect(find.text('Pagina valigia'), findsNothing);
    expect(notice, findsOneWidget);
    verifyNever(() => tripRepo.updateTrip(any()));
  });

  testWidgets('notice_close_persists', (tester) async {
    await pumpDetail(tester, _trip());

    await tester.tap(find.byKey(const Key('trip_changed_close')));
    await tester.pumpAndSettle();

    final saved =
        verify(() => tripRepo.updateTrip(captureAny())).captured.single
            as TripModel;
    expect(saved.aiResult?.changeNoticeDismissed, isTrue);
    // Il resto della valigia non cambia.
    expect(saved.aiResult?.tripShape, _trip().aiResult?.tripShape);

    // Un nuovo pump con il viaggio come è stato scritto: l'avviso non torna.
    await tester.pumpWidget(const SizedBox());
    await pumpDetail(tester, saved);
    expect(notice, findsNothing);
  });

  testWidgets('regenerate_menu_starts_ai_on_detail', (tester) async {
    await pumpDetail(tester, _trip(changed: false));

    await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rigenera'));
    await tester.pumpAndSettle();
    expect(find.text('Vuoi sostituire la valigia?'), findsOneWidget);
    await tester.tap(find.text('Sostituisci'));
    await tester.pumpAndSettle();

    expect(find.byType(DsFormSheet), findsOneWidget);
    expect(visited, isEmpty);
    expect(find.text('Pagina valigia'), findsNothing);
  });
}

import 'dart:async';

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
import 'package:pack_log/features/items/services/category_infer_service.dart';
import 'package:pack_log/features/kits/model/kit_model.dart';
import 'package:pack_log/features/kits/providers/kit_provider.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/luggages/repositories/luggage_repository.dart';
import 'package:pack_log/features/trips/model/ai_packing_request.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/ai_packing_run_provider.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/view/new_trip_screen.dart';
import 'package:pack_log/features/trips/view/widgets/trip_calendar.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:pack_log/shared/widgets/ds_choice_pill.dart';
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';
import 'package:pack_log/shared/widgets/ds_steps.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/catalogo_di_prova.dart';
import '../../../helpers/memory_asset_loader.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockLuggageRepository extends Mock implements LuggageRepository {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

/// Il lavoro AI finto: registra le richieste e resta in corso.
class _FakeRun extends AiPackingRun {
  final requests = <AiPackingRequest>[];

  @override
  AiPackingRunState build() => const AiRunIdle();

  @override
  bool start(AiPackingRequest request) {
    if (state is AiRunRunning) return false;
    requests.add(request);
    state = AiRunRunning(request);
    return true;
  }
}

class _Kits extends KitNotifier {
  @override
  Future<List<KitModel>> build(String houseId) async => const [];
}

final _nextMonth = DateTime(DateTime.now().year, DateTime.now().month + 1);
final _departure = DateTime(_nextMonth.year, _nextMonth.month, 10);
final _return = DateTime(_nextMonth.year, _nextMonth.month, 12);

Future<void> _tapDay(WidgetTester tester, DateTime day) async {
  final finder = find.byKey(
    ValueKey('trip_calendar_day_${DateFormat('yyyy-MM-dd').format(day)}'),
  );
  await tester.scrollUntilVisible(
    finder,
    50,
    scrollable: find.descendant(
      of: find.byType(TripCalendar),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pickDates(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('new_trip_dates')));
  await tester.pumpAndSettle();
  await _tapDay(tester, _departure);
  await _tapDay(tester, _return);
  await tester.tap(find.text('Conferma date'));
  await tester.pumpAndSettle();
}

/// "Riusa" è il passo 1 di un viaggio nuovo, precompilato: non salva niente
/// finché non si sceglie una strada.
void main() {
  late MockTripRepository tripRepo;
  late ProviderContainer container;
  late _FakeRun run;

  final past = TripModel(
    id: 'trip-1',
    name: 'Toscana',
    description: 'Nota sul viaggio',
    departureDateTime: DateTime(2026, 9, 12),
    returnDateTime: DateTime(2026, 9, 20),
    destinationLocation: LocationSuggestionModel(
      placeId: 'p',
      displayName: 'Siena, Italia',
      city: 'Siena',
      lat: 43.3,
      lon: 11.3,
    ),
    legs: [
      TripLeg(
        id: 'a',
        locationDisplayName: 'Firenze',
        from: DateTime(2026, 9, 16),
        to: DateTime(2026, 9, 20),
      ),
    ],
    transports: const ['car'],
    items: [
      TripItem(
        id: 'i1',
        name: 'Maglietta',
        category: ItemCategory.vestiti,
        quantity: 2,
        originHouseId: 'h1',
        isChecked: true,
      ),
      TripItem(
        id: 'i2',
        name: 'Spazzolino',
        category: ItemCategory.toiletries,
        quantity: 1,
        originHouseId: 'h1',
        isChecked: true,
      ),
    ],
    luggages: [
      LuggageModel(
        id: 'l1',
        name: 'Zaino',
        sizeType: LuggageSize.cabinBaggage,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(
      TripModel(
        id: 'fallback',
        name: 'Fallback',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  });

  setUp(() {
    tripRepo = MockTripRepository();
    final houseRepo = MockHouseRepository();
    final itemRepo = MockItemRepository();
    final luggageRepo = MockLuggageRepository();
    run = _FakeRun();

    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [past]);
    when(() => tripRepo.addTrip(any())).thenAnswer((_) async {});
    when(() => houseRepo.getAllHouses()).thenAnswer(
      (_) async => [
        HouseModel(
          id: 'h1',
          name: 'Casa Milano',
          isPrimary: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    when(() => itemRepo.getItemsByHouseId(any())).thenAnswer((_) async => []);
    when(() => luggageRepo.getAllLuggages()).thenAnswer((_) async => []);
    when(
      () => luggageRepo.getLuggagesByHouseId(any()),
    ).thenAnswer((_) async => []);
    final sync = MockSyncOrchestrator();
    when(() => sync.requestSync()).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(tripRepo),
        houseRepositoryProvider.overrideWithValue(houseRepo),
        itemRepositoryProvider.overrideWithValue(itemRepo),
        luggageRepositoryProvider.overrideWithValue(luggageRepo),
        categoryInferServiceProvider.overrideWith(
          (ref) => Completer<CategoryInferService>().future,
        ),
        coreAnalyticsServiceProvider.overrideWithValue(
          MockCoreAnalyticsService(),
        ),
        syncOrchestratorProvider.overrideWithValue(sync),
        aiPackingRunProvider.overrideWith(() => run),
        kitNotifierProvider('h1').overrideWith(_Kits.new),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Monta la schermata sopra la tab Viaggi finta, come dal bottone "Riusa".
  Future<void> pumpReuse(WidgetTester tester) async {
    caricaCatalogoDelRepo();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await container.read(tripNotifierProvider.future);

    final router = GoRouter(
      initialLocation: '/trips',
      routes: [
        GoRoute(
          path: '/trips',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                const Text('trips-tab'),
                ElevatedButton(
                  onPressed: () => context.push('/new-trip?reuseFrom=trip-1'),
                  child: const Text('apri'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/trips/:id/edit-items',
          builder: (_, state) => Scaffold(
            body: Text(
              'edit-items ${state.pathParameters['id']} '
              'from=${state.uri.queryParameters['from']}',
            ),
          ),
        ),
        GoRoute(
          path: '/ai-packing',
          builder: (_, _) =>
              Scaffold(appBar: AppBar(), body: const Text('ai-wait')),
        ),
        GoRoute(
          path: '/new-trip',
          builder: (_, state) => NewTripScreen(
            reuseFromId: state.uri.queryParameters['reuseFrom'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
        path: 'assets/translations',
        assetLoader: MemoryAssetLoader(readAppTranslations()),
        fallbackLocale: const Locale('en', 'US'),
        startLocale: const Locale('it', 'IT'),
        saveLocale: false,
        child: UncontrolledProviderScope(
          container: container,
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
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  testWidgets('reuse_opens_prefilled_step_without_saving', (tester) async {
    await pumpReuse(tester);

    expect(find.byType(DsSteps), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Riusa il viaggio'),
      ),
      findsOneWidget,
    );
    expect(find.text('Siena, Italia'), findsOneWidget);
    expect(find.text('Tocca per impostare le date'), findsOneWidget);
    final name = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('new_trip_name')),
        matching: find.byType(TextField),
      ),
    );
    expect(name.controller!.text, 'Toscana');
    expect(find.byKey(const Key('edit_trip_save')), findsNothing);

    // Nessun viaggio nuovo all'apertura né all'uscita (niente conferma: il
    // passo non è stato toccato).
    expect(container.read(tripNotifierProvider).valueOrNull, [past]);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('trips-tab'), findsOneWidget);
    verifyNever(() => tripRepo.addTrip(any()));
    verifyNever(() => tripRepo.deleteTrip(any()));
    verifyNever(() => tripRepo.updateTrip(any()));
    expect(container.read(tripNotifierProvider).valueOrNull, [past]);
  });

  testWidgets('reuse_has_two_buttons', (tester) async {
    await pumpReuse(tester);

    expect(find.byKey(const Key('new_trip_prepare_ai')), findsOneWidget);
    expect(find.byKey(const Key('new_trip_choose_items')), findsOneWidget);
    expect(find.text('Prepara la valigia con AI'), findsOneWidget);
    expect(find.text('Scegli tu cosa portare'), findsOneWidget);
    for (final gone in ['reuse_next', 'reuse_later', 'new_trip_next']) {
      expect(find.byKey(Key(gone)), findsNothing);
    }
    // Senza date i bottoni sono spenti.
    expect(
      tester
          .widget<DsButton>(find.byKey(const Key('new_trip_choose_items')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('reuse_zero_night_stop_blocks_choose_items', (tester) async {
    await pumpReuse(tester);
    await _pickDates(tester);

    expect(
      find.text('Firenze finisce prima di iniziare: controlla le date.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<DsButton>(find.byKey(const Key('new_trip_choose_items')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('new_trip_choose_items')));
    await tester.pumpAndSettle();
    verifyNever(() => tripRepo.addTrip(any()));
  });

  testWidgets(
    'reuse_choose_items_saves_copy_with_unchecked_items_and_luggages',
    (tester) async {
      await pumpReuse(tester);
      await _pickDates(tester);
      // La tappa di Firenze nasce a zero notti: si sistema dalla sua riga.
      expect(
        find.text('Firenze finisce prima di iniziare: controlla le date.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Firenze'));
      await tester.tap(find.text('Firenze'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stop_sheet_dates')));
      await tester.pumpAndSettle();
      await _tapDay(tester, DateTime(_nextMonth.year, _nextMonth.month, 14));
      await tester.tap(find.text('Conferma'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stop_sheet_save')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('new_trip_choose_items')));
      await tester.pumpAndSettle();

      final saved =
          verify(() => tripRepo.addTrip(captureAny())).captured.single
              as TripModel;
      expect(saved.id, isNot('trip-1'));
      expect(saved.name, 'Toscana');
      expect(saved.departureDateTime, _departure);
      expect(saved.legs.single.locationDisplayName, 'Firenze');
      expect(saved.transports, ['car']);
      expect(saved.items.map((i) => i.id), ['i1', 'i2']);
      expect(saved.items.every((i) => !i.isChecked), isTrue);
      expect(saved.items.first.quantity, 2);
      expect(saved.luggages.map((l) => l.id), ['l1']);
      expect(find.text('edit-items ${saved.id} from=new'), findsOneWidget);
      verifyNever(() => tripRepo.updateTrip(any()));
    },
  );

  testWidgets(
    'reuse_ai_starts_new_trip_without_items / reuse_ai_carries_description',
    (tester) async {
      await pumpReuse(tester);
      await _pickDates(tester);
      // Come sopra la tappa va sistemata; qui basta togliere Firenze.
      await tester.ensureVisible(find.text('Firenze'));
      await tester.tap(find.text('Firenze'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stop_sheet_remove')));
      await tester.pumpAndSettle();
      if (find.text('Elimina').evaluate().isNotEmpty) {
        await tester.tap(find.text('Elimina').last);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const Key('new_trip_prepare_ai')));
      await tester.pumpAndSettle();
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

      expect(run.requests, hasLength(1));
      final request = run.requests.single;
      expect(request.isNew, isTrue);
      expect(request.trip.id, isNot('trip-1'));
      expect(request.trip.items, isEmpty);
      expect(request.trip.luggages, isEmpty);
      expect(request.trip.description, 'Nota sul viaggio');
      expect(request.trip.destinationLocation?.displayName, 'Siena, Italia');
      expect(find.text('ai-wait'), findsOneWidget);
      verifyNever(() => tripRepo.addTrip(any()));
    },
  );
}

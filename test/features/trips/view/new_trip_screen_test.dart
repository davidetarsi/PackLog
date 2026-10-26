import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/new_trip_screen.dart';
import 'package:pack_log/features/trips/view/widgets/place_search.dart';
import 'package:pack_log/features/trips/view/widgets/trip_calendar.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';
import 'package:pack_log/shared/model/location_type.dart';
import 'package:pack_log/shared/services/location_search_service.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';

import '../../../helpers/memory_asset_loader.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

class MockTripLifecycleService extends Mock implements TripLifecycleService {}

class MockLocationSearchService extends Mock implements LocationSearchService {}

final _houses = [
  HouseModel(
    id: 'h1',
    name: 'Casa Milano',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  HouseModel(
    id: 'h2',
    name: 'Casa al mare',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  HouseModel(
    id: 'h3',
    name: 'Casa in montagna',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
];

final _places = [
  LocationSuggestionModel(
    placeId: 'p1',
    displayName: 'Marsiglia, Francia',
    name: 'Marsiglia',
    city: 'Marsiglia',
    country: 'Francia',
    locationType: LocationType.city,
  ),
];

/// Primo e secondo giorno del mese prossimo: sempre futuri, e il calendario
/// va scorso fino a loro (vedi [_tapDay]).
final _nextMonth = DateTime(DateTime.now().year, DateTime.now().month + 1);
final _departure = DateTime(_nextMonth.year, _nextMonth.month, 10);
final _return = DateTime(_nextMonth.year, _nextMonth.month, 12);

Finder _dayFinder(DateTime day) => find.byKey(
  ValueKey('trip_calendar_day_${DateFormat('yyyy-MM-dd').format(day)}'),
);

/// Scorre il calendario fino al giorno e lo tocca.
Future<void> _tapDay(WidgetTester tester, DateTime day) async {
  final finder = _dayFinder(day);
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

Finder get _placeField => find.descendant(
  of: find.byType(PlaceSearch),
  matching: find.byType(TextField),
);

Finder get _nameField => find.byKey(const Key('new_trip_name'));

String _nameText(WidgetTester tester) =>
    tester.widget<TextField>(_nameField).controller!.text;

/// Sceglie una casa dalla ricerca della meta.
Future<void> _pickHouse(WidgetTester tester, String id) async {
  await tester.tap(_placeField);
  await tester.pump();
  await tester.tap(find.byKey(Key('place_search_house_$id')));
  await tester.pumpAndSettle();
}

DateTime _day(int day) => DateTime(_nextMonth.year, _nextMonth.month, day);

/// Il campo place della tappa aperta nel foglio.
Finder get _stopPlaceField => find.descendant(
  of: find.byKey(const Key('stop_sheet_place')),
  matching: find.byType(TextField),
);

/// Aggiunge una tappa in coda dalla sua riga: casa e giorno di fine.
Future<void> _addStop(
  WidgetTester tester, {
  required String houseId,
  required int endDay,
}) async {
  await tester.ensureVisible(find.byKey(const Key('new_trip_add_stop')));
  await tester.tap(find.byKey(const Key('new_trip_add_stop')));
  await tester.pumpAndSettle();
  await tester.tap(_stopPlaceField);
  await tester.pump();
  await tester.tap(find.byKey(Key('place_search_house_$houseId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('stop_sheet_dates')));
  await tester.pumpAndSettle();
  await _tapDay(tester, _day(endDay));
  await tester.tap(find.text('Conferma'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('stop_sheet_save')));
  await tester.pumpAndSettle();
}

/// Cambia la fine della meta: il foglio ha il range completo, quindi il primo
/// tocco riparte dalla partenza e il secondo sceglie il ritorno.
Future<void> _moveDestinationEnd(WidgetTester tester, DateTime end) async {
  await tester.ensureVisible(find.byKey(const Key('new_trip_dates')));
  await tester.tap(find.byKey(const Key('new_trip_dates')));
  await tester.pumpAndSettle();
  await _tapDay(tester, _departure);
  await _tapDay(tester, end);
  await tester.tap(find.text('Conferma date'));
  await tester.pumpAndSettle();
}

/// Sceglie le date di andata e ritorno dal foglio "Quando?".
Future<void> _pickDates(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('new_trip_dates')));
  await tester.pumpAndSettle();
  await _tapDay(tester, _departure);
  await _tapDay(tester, _return);
  await tester.tap(find.text('Conferma date'));
  await tester.pumpAndSettle();
}

/// Vero se la decorazione dipinge con [color] (sfondo o bordo).
bool _decorationUsesColor(Decoration decoration, Color color) {
  if (decoration is! BoxDecoration) return false;
  final border = decoration.border;
  return decoration.color == color ||
      (border is Border && border.top.color == color);
}

void main() {
  late MockTripRepository tripRepo;
  late MockHouseRepository houseRepo;
  late MockLocationSearchService locationService;
  late MockTripLifecycleService lifecycle;
  late ProviderContainer container;

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
    houseRepo = MockHouseRepository();
    locationService = MockLocationSearchService();
    lifecycle = MockTripLifecycleService();

    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => []);
    when(() => tripRepo.addTrip(any())).thenAnswer((_) async {});
    when(() => houseRepo.getAllHouses()).thenAnswer((_) async => _houses);
    when(
      () => locationService.search(any(), lang: any(named: 'lang')),
    ).thenAnswer((_) async => _places);
    when(
      () => lifecycle.transferItemsForCompletedTrips(any()),
    ).thenAnswer((_) async => <String>{});
    when(() => lifecycle.computeNextStatusChange(any())).thenReturn(null);

    final sync = MockSyncOrchestrator();
    when(() => sync.requestSync()).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(tripRepo),
        houseRepositoryProvider.overrideWithValue(houseRepo),
        itemRepositoryProvider.overrideWithValue(MockItemRepository()),
        coreAnalyticsServiceProvider.overrideWithValue(
          MockCoreAnalyticsService(),
        ),
        syncOrchestratorProvider.overrideWithValue(sync),
        tripLifecycleServiceProvider.overrideWithValue(lifecycle),
        locationSearchServiceProvider.overrideWithValue(locationService),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Monta la schermata sopra una tab finta "/trips", come dalla tab Viaggi:
  /// il bottone "apri" spinge [open] con `push`, così Indietro ha dove tornare.
  Future<void> pumpScreen(
    WidgetTester tester, {
    String open = '/new-trip',
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await container.read(tripNotifierProvider.future);
    await container.read(houseNotifierProvider.future);

    final router = GoRouter(
      initialLocation: '/trips',
      routes: [
        GoRoute(
          path: '/trips',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('trips-tab'),
                Text('focus=${state.uri.queryParameters['focus']}'),
                ElevatedButton(
                  onPressed: () => context.push(open),
                  child: const Text('apri'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/trips/:id/edit-items',
          builder: (_, state) => Scaffold(
            body: Column(
              children: [
                Text(
                  'edit-items ${state.pathParameters['id']} '
                  'from=${state.uri.queryParameters['from']}',
                ),
                Text('ai=${state.uri.queryParameters['ai'] ?? 'none'}'),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/new-trip',
          builder: (_, state) =>
              NewTripScreen(aiIntent: state.uri.queryParameters['ai'] == '1'),
        ),
        GoRoute(
          path: '/trips/:id/edit-info',
          builder: (_, state) =>
              NewTripScreen(tripId: state.pathParameters['id']!),
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

  TripModel savedTrip() =>
      verify(() => tripRepo.addTrip(captureAny())).captured.single as TripModel;

  group('NewTripScreen — campi', () {
    testWidgets('"Quando?" è alto come il campo "Dove vai?"', (tester) async {
      await pumpScreen(tester);

      final where = tester.getSize(
        find.descendant(
          of: find.byKey(const Key('new_trip_place_search')),
          matching: find.byType(TextField),
        ),
      );
      final when = tester.getSize(find.byKey(const Key('new_trip_dates')));

      expect(when.height, where.height);
    });

    testWidgets('con la tastiera aperta i bottoni non salgono', (tester) async {
      // Come negli altri form con CTA in fondo (StickyCtaScaffold): la
      // tastiera copre i bottoni invece di spingerli sopra di sé.
      await pumpScreen(tester);
      final before = tester.getTopLeft(find.byKey(const Key('new_trip_next')));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final after = tester.getTopLeft(find.byKey(const Key('new_trip_next')));
      expect(after.dy, before.dy);
    });
  });

  group('NewTripScreen — valigia con AI', () {
    testWidgets('nel passo 1 "Prepara con AI" è un contorno neutro sotto '
        '"Avanti"', (tester) async {
      await pumpScreen(tester);

      final ai = find.byKey(const Key('new_trip_prepare_ai'));
      final scheme = Theme.of(tester.element(ai)).colorScheme;
      final style = tester.widget<OutlinedButton>(ai).style!;
      expect(style.foregroundColor!.resolve({}), scheme.onSurface);
      expect(style.side!.resolve({})!.color, scheme.outline);
      expect(
        find.descendant(of: ai, matching: find.text('Prepara con AI')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: ai, matching: find.byIcon(Icons.auto_awesome)),
        findsOneWidget,
      );
      expect(
        tester.getSize(ai).height,
        tester.getSize(find.byKey(const Key('new_trip_next'))).height,
      );
      double y(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
      expect(y('new_trip_next'), lessThan(y('new_trip_prepare_ai')));
      expect(y('new_trip_prepare_ai'), lessThan(y('new_trip_later')));
    });

    testWidgets('nel passo 1 solo "Avanti" usa il colore primario', (
      tester,
    ) async {
      await pumpScreen(tester);

      final next = find.byKey(const Key('new_trip_next'));
      final primary = Theme.of(tester.element(next)).colorScheme.primary;
      // Tutto ciò che sta dentro "Avanti" è suo: il resto della schermata no.
      final avanti = find
          .descendant(of: next, matching: find.byWidgetPredicate((_) => true))
          .evaluate()
          .followedBy(next.evaluate())
          .toSet();

      bool usesPrimary(Widget w) {
        if (w is DsButton) return w.variant == DsButtonVariant.primary;
        if (w is Text) return w.style?.color == primary;
        if (w is Icon) return w.color == primary;
        if (w is Material) return w.color == primary;
        if (w is ButtonStyleButton) {
          return w.style?.foregroundColor?.resolve({}) == primary ||
              w.style?.side?.resolve({})?.color == primary;
        }
        if (w is DecoratedBox) {
          return _decorationUsesColor(w.decoration, primary);
        }
        if (w is Container) {
          return w.color == primary ||
              (w.decoration != null &&
                  _decorationUsesColor(w.decoration!, primary));
        }
        return false;
      }

      final others = find
          .byWidgetPredicate(usesPrimary)
          .evaluate()
          .where((e) => !avanti.contains(e))
          .map((e) => e.widget.runtimeType.toString())
          .toList();
      expect(others, isEmpty);
    });

    testWidgets('doppio tocco su "Prepara con AI" salva una sola volta', (
      tester,
    ) async {
      final saving = Completer<void>();
      when(() => tripRepo.addTrip(any())).thenAnswer((_) => saving.future);
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      await tester.tap(find.byKey(const Key('new_trip_prepare_ai')));
      await tester.tap(find.byKey(const Key('new_trip_prepare_ai')));
      await tester.pump();
      saving.complete();
      await tester.pumpAndSettle();

      // Una sola chiamata: `verify` la consuma, quindi la si legge da lì.
      final trip =
          verify(() => tripRepo.addTrip(captureAny())).captured.single
              as TripModel;
      expect(find.text('edit-items ${trip.id} from=new'), findsOneWidget);
      expect(find.text('ai=1'), findsOneWidget);
    });

    testWidgets('"Prepara con AI" salva e apre la valigia con ai=1', (
      tester,
    ) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      await tester.tap(find.byKey(const Key('new_trip_prepare_ai')));
      await tester.pumpAndSettle();

      final trip = savedTrip();
      expect(trip.destinationHouseId, 'h1');
      expect(find.text('edit-items ${trip.id} from=new'), findsOneWidget);
      expect(find.text('ai=1'), findsOneWidget);
    });

    testWidgets('"Prepara con AI" a modulo vuoto mostra gli errori', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('new_trip_prepare_ai')));
      await tester.pumpAndSettle();

      expect(
        find.text('Scegli dove vai: serve anche per il meteo.'),
        findsOneWidget,
      );
      verifyNever(() => tripRepo.addTrip(any()));
    });

    testWidgets('con ai=1 il primario è "Prepara con AI", c\'è il link '
        '"Prepara a mano" e non "Avanti"', (tester) async {
      await pumpScreen(tester, open: '/new-trip?ai=1');

      expect(find.byKey(const Key('new_trip_next')), findsNothing);
      expect(find.text('Avanti: prepara la valigia'), findsNothing);
      expect(
        tester
            .widget<DsButton>(find.byKey(const Key('new_trip_prepare_ai')))
            .variant,
        DsButtonVariant.primary,
      );
      expect(find.text('Prepara a mano'), findsOneWidget);
      double y(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
      expect(y('new_trip_prepare_ai'), lessThan(y('new_trip_manual')));
      expect(y('new_trip_manual'), lessThan(y('new_trip_later')));
    });

    testWidgets('con ai=1, "Prepara a mano" porta al passo 2 senza AI', (
      tester,
    ) async {
      await pumpScreen(tester, open: '/new-trip?ai=1');
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      await tester.tap(find.byKey(const Key('new_trip_manual')));
      await tester.pumpAndSettle();

      final trip = savedTrip();
      expect(find.text('edit-items ${trip.id} from=new'), findsOneWidget);
      expect(find.text('ai=none'), findsOneWidget);
    });

    testWidgets('in modifica di un viaggio non compaiono i bottoni AI', (
      tester,
    ) async {
      final trip = TripModel(
        id: 'trip-1',
        name: 'Toscana',
        departureDateTime: DateTime(2026, 9, 12),
        returnDateTime: DateTime(2026, 9, 20),
        destinationLocation: LocationSuggestionModel(
          placeId: 'p',
          displayName: 'Siena, Italia',
          city: 'Siena',
        ),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [trip]);

      await pumpScreen(tester, open: '/trips/trip-1/edit-info');

      expect(find.byKey(const Key('edit_trip_save')), findsOneWidget);
      expect(find.byKey(const Key('new_trip_prepare_ai')), findsNothing);
      expect(find.byKey(const Key('new_trip_manual')), findsNothing);
    });
  });

  group('NewTripScreen — uscita', () {
    testWidgets('a modulo vuoto il tocco su Avanti mostra i due errori', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('new_trip_next')));
      await tester.pumpAndSettle();

      expect(
        find.text('Scegli dove vai: serve anche per il meteo.'),
        findsOneWidget,
      );
      expect(find.text('Scegli andata e ritorno.'), findsOneWidget);
      verifyNever(() => tripRepo.addTrip(any()));
    });

    testWidgets('Avanti salva meta e date e porta a edit-items?from=new', (
      tester,
    ) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      await tester.tap(find.byKey(const Key('new_trip_next')));
      await tester.pumpAndSettle();

      final trip = savedTrip();
      expect(trip.destinationHouseId, 'h1');
      expect(trip.departureDateTime, _departure);
      expect(trip.returnDateTime, _return);
      expect(trip.name, 'Casa Milano');
      expect(find.text('edit-items ${trip.id} from=new'), findsOneWidget);
    });

    testWidgets('Prepara la valigia più tardi porta a trips?focus=<id>', (
      tester,
    ) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h2');
      await _pickDates(tester);

      await tester.tap(find.byKey(const Key('new_trip_later')));
      await tester.pumpAndSettle();

      final trip = savedTrip();
      expect(trip.destinationHouseId, 'h2');
      expect(find.text('focus=${trip.id}'), findsOneWidget);
      expect(find.text('trips-tab'), findsOneWidget);
    });

    testWidgets(
      'una meta dalla ricerca dei luoghi si salva con le coordinate',
      (tester) async {
        await pumpScreen(tester);
        await tester.tap(_placeField);
        await tester.pump();
        await tester.enterText(_placeField, 'Mar');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('place_search_location_0')));
        await tester.pumpAndSettle();
        await _pickDates(tester);

        await tester.tap(find.byKey(const Key('new_trip_later')));
        await tester.pumpAndSettle();

        final trip = savedTrip();
        expect(trip.destinationHouseId, isNull);
        expect(trip.destinationLocation?.displayName, 'Marsiglia, Francia');
        expect(trip.name, 'Marsiglia');
      },
    );

    testWidgets('con una meta scelta, Indietro chiede conferma', (
      tester,
    ) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Lasciare il nuovo viaggio?'), findsOneWidget);
      expect(find.text('Nuovo viaggio'), findsOneWidget);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(find.text('Lasciare il nuovo viaggio?'), findsNothing);
      expect(find.text('Nuovo viaggio'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conferma'));
      await tester.pumpAndSettle();

      expect(find.text('trips-tab'), findsOneWidget);
      verifyNever(() => tripRepo.addTrip(any()));
    });

    testWidgets('senza niente, Indietro esce subito', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Lasciare il nuovo viaggio?'), findsNothing);
      expect(find.text('trips-tab'), findsOneWidget);
    });
  });

  group('NewTripScreen — nome del viaggio', () {
    testWidgets('segue la meta finché non lo modifichi', (tester) async {
      await pumpScreen(tester);

      await _pickHouse(tester, 'h1');
      expect(_nameText(tester), 'Casa Milano');

      // Via la meta e scegline un'altra: il nome proposto cambia.
      await tester.tap(find.byKey(const Key('new_trip_clear_destination')));
      await tester.pumpAndSettle();
      await _pickHouse(tester, 'h2');
      expect(_nameText(tester), 'Casa al mare');

      // Scritto a mano, il nome non segue più la meta.
      await tester.enterText(_nameField, 'Weekend');
      await tester.pump();
      await tester.tap(find.byKey(const Key('new_trip_clear_destination')));
      await tester.pumpAndSettle();
      await _pickHouse(tester, 'h1');
      expect(_nameText(tester), 'Weekend');
    });
  });

  group('NewTripScreen — tappe', () {
    testWidgets('Aggiungi tappa mette la riga in coda all\'itinerario', (
      tester,
    ) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      await _addStop(tester, houseId: 'h2', endDay: 14);

      expect(find.text('Casa al mare'), findsOneWidget);
      expect(find.text('trips.new.stops_tip'), findsNothing);
    });

    testWidgets('tocco su una tappa apre la sua modifica', (tester) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);
      await _addStop(tester, houseId: 'h2', endDay: 14);

      await tester.tap(find.text('Casa al mare'));
      await tester.pumpAndSettle();

      expect(find.text('Modifica tappa'), findsOneWidget);
      expect(
        tester.widget<TextField>(_stopPlaceField).controller!.text,
        'Casa al mare',
      );
    });

    testWidgets('modificare la tappa dalla riga cambia il posto', (
      tester,
    ) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);
      await _addStop(tester, houseId: 'h2', endDay: 14);

      await tester.tap(find.text('Casa al mare'));
      await tester.pumpAndSettle();
      await tester.tap(_stopPlaceField);
      await tester.pump();
      await tester.enterText(_stopPlaceField, 'Casa in');
      await tester.pump();
      await tester.tap(find.byKey(const Key('place_search_house_h3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stop_sheet_save')));
      await tester.pumpAndSettle();

      expect(find.text('Casa in montagna'), findsOneWidget);
      expect(find.text('Casa al mare'), findsNothing);
    });

    testWidgets(
      'con le date fuori ordine la riga toccata è la tappa giusta e la elimina',
      (tester) async {
        await pumpScreen(tester);
        await _pickHouse(tester, 'h1');
        await _pickDates(tester);
        await _addStop(tester, houseId: 'h2', endDay: 14);
        await _addStop(tester, houseId: 'h3', endDay: 16);

        // La meta finisce il 15: la tappa B ("Casa al mare") finisce il 14,
        // prima di iniziare. Per data C verrebbe prima di B, ma le righe
        // restano nell'ordine della catena: A, B, C.
        await _moveDestinationEnd(tester, _day(15));
        final mare = tester.getTopLeft(find.text('Casa al mare')).dy;
        final montagna = tester.getTopLeft(find.text('Casa in montagna')).dy;
        expect(mare, lessThan(montagna));

        await tester.tap(find.text('Casa in montagna'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_stopPlaceField).controller!.text,
          'Casa in montagna',
        );

        await tester.tap(find.byKey(const Key('stop_sheet_remove')));
        await tester.pumpAndSettle();

        expect(find.text('Casa in montagna'), findsNothing);
        expect(find.text('Casa al mare'), findsOneWidget);
      },
    );

    testWidgets('una tappa a zero notti blocca Avanti e Più tardi', (
      tester,
    ) async {
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);
      await _addStop(tester, houseId: 'h2', endDay: 14);

      // La meta finisce il 14, come la tappa che parte da lì: zero notti.
      await _moveDestinationEnd(tester, _day(14));

      expect(
        find.text('Casa al mare finisce prima di iniziare: controlla le date.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DsButton>(find.byKey(const Key('new_trip_next')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('new_trip_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new_trip_later')));
      await tester.pumpAndSettle();

      verifyNever(() => tripRepo.addTrip(any()));
    });

    testWidgets('Più tardi a modulo vuoto mostra i due messaggi', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('new_trip_later')));
      await tester.pumpAndSettle();

      expect(
        find.text('Scegli dove vai: serve anche per il meteo.'),
        findsOneWidget,
      );
      expect(find.text('Scegli andata e ritorno.'), findsOneWidget);
      verifyNever(() => tripRepo.addTrip(any()));
    });

    testWidgets('un salvataggio che fallisce riabilita il bottone', (
      tester,
    ) async {
      when(() => tripRepo.addTrip(any())).thenThrow(Exception('offline'));
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      // Durante il salvataggio il bottone gira: niente pumpAndSettle finché
      // il dialogo d'errore non chiude, altrimenti lo spinner non si ferma mai.
      await tester.tap(find.byKey(const Key('new_trip_next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Errore di salvataggio'), findsOneWidget);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(find.text('Nuovo viaggio'), findsOneWidget);
      expect(
        tester
            .widget<DsButton>(find.byKey(const Key('new_trip_next')))
            .isLoading,
        isFalse,
      );

      await tester.tap(find.byKey(const Key('new_trip_next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      verify(() => tripRepo.addTrip(any())).called(2);
    });

    testWidgets('durante il salvataggio il back non esce né chiede conferma', (
      tester,
    ) async {
      final saving = Completer<void>();
      when(() => tripRepo.addTrip(any())).thenAnswer((_) => saving.future);
      await pumpScreen(tester);
      await _pickHouse(tester, 'h1');
      await _pickDates(tester);

      await tester.tap(find.byKey(const Key('new_trip_next')));
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pump();

      expect(find.text('Lasciare il nuovo viaggio?'), findsNothing);
      expect(find.text('Nuovo viaggio'), findsOneWidget);

      saving.complete();
      await tester.pumpAndSettle();
      final trip = savedTrip();
      expect(find.text('edit-items ${trip.id} from=new'), findsOneWidget);
    });
  });
}

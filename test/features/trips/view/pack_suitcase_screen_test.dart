import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/luggages/repositories/luggage_repository.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/pack_suitcase_screen.dart';
import 'package:pack_log/features/trips/view/widgets/pack/pack_parts.dart';
import 'package:pack_log/features/luggages/view/luggages_management_screen.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_empty_state.dart';
import 'package:pack_log/shared/widgets/ds_steps.dart';
import 'package:pack_log/shared/widgets/quantity_stepper.dart';

import '../../../helpers/memory_asset_loader.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockLuggageRepository extends Mock implements LuggageRepository {}

class MockTripLifecycleService extends Mock implements TripLifecycleService {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

final _milano = HouseModel(
  id: 'h1',
  name: 'Casa Milano',
  isPrimary: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _mare = HouseModel(
  id: 'h2',
  name: 'Casa al mare',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ItemModel _item(
  String id,
  String name,
  ItemCategory category, {
  required String houseId,
  int quantity = 1,
}) => ItemModel(
  id: id,
  houseId: houseId,
  name: name,
  category: category,
  quantity: quantity,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _maglietta = _item(
  'i-maglietta',
  'Maglietta',
  ItemCategory.vestiti,
  houseId: 'h1',
  quantity: 3,
);

final _spazzolino = _item(
  'i-spazzolino',
  'Spazzolino',
  ItemCategory.toiletries,
  houseId: 'h1',
);

final _calzini = _item(
  'i-calzini',
  'Calzini',
  ItemCategory.vestiti,
  houseId: 'h2',
);

LuggageModel _luggage(String id, String name) => LuggageModel(
  id: id,
  houseId: 'h1',
  name: name,
  sizeType: LuggageSize.cabinBaggage,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

TripModel _trip({
  List<TripItem> items = const [],
  List<LuggageModel> luggages = const [],
  String? destinationHouseId,
}) => TripModel(
  id: 'trip-1',
  name: 'Lisbona',
  items: items,
  luggages: luggages,
  destinationHouseId: destinationHouseId,
  departureDateTime: DateTime(2099, 10, 29),
  returnDateTime: DateTime(2099, 11, 3),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

TripItem _tripItem(
  ItemModel item, {
  int quantity = 1,
  bool isChecked = false,
}) => TripItem(
  id: item.id,
  name: item.name,
  category: item.category,
  quantity: quantity,
  originHouseId: item.houseId,
  isChecked: isChecked,
);

void main() {
  late MockTripRepository tripRepo;
  late MockHouseRepository houseRepo;
  late MockItemRepository itemRepo;
  late MockLuggageRepository luggageRepo;
  late MockTripLifecycleService lifecycle;
  late MockCoreAnalyticsService analytics;
  late MockSyncOrchestrator sync;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(_trip());
  });

  setUp(() {
    tripRepo = MockTripRepository();
    houseRepo = MockHouseRepository();
    itemRepo = MockItemRepository();
    luggageRepo = MockLuggageRepository();
    lifecycle = MockTripLifecycleService();
    analytics = MockCoreAnalyticsService();
    sync = MockSyncOrchestrator();

    when(
      () => lifecycle.transferItemsForCompletedTrips(any()),
    ).thenAnswer((_) async => <String>{});
    when(() => lifecycle.computeNextStatusChange(any())).thenReturn(null);
    when(() => sync.requestSync()).thenReturn(null);
    when(() => tripRepo.updateTrip(any())).thenAnswer((_) async {});
  });

  /// Stub dei repository per una schermata. Le case e gli oggetti sono quelli
  /// passati; il viaggio è quello salvato e torna dal reload dopo il salvataggio.
  void arrange({
    TripModel? trip,
    List<HouseModel>? houses,
    Map<String, List<ItemModel>> items = const {},
    List<LuggageModel> luggages = const [],
  }) {
    final storedTrip = trip ?? _trip();
    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [storedTrip]);
    when(
      () => houseRepo.getAllHouses(),
    ).thenAnswer((_) async => houses ?? [_milano]);
    when(() => itemRepo.getItemsByHouseId(any())).thenAnswer(
      (invocation) async =>
          items[invocation.positionalArguments.first as String] ?? const [],
    );
    when(() => luggageRepo.getAllLuggages()).thenAnswer((_) async => luggages);
    when(
      () => luggageRepo.getLuggagesByHouseId(any()),
    ).thenAnswer((_) async => luggages);
  }

  Future<void> pumpPack(WidgetTester tester, {bool fromNewTrip = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final path = '/trips/trip-1/edit-items${fromNewTrip ? '?from=new' : ''}';
    final router = GoRouter(
      initialLocation: '/trips',
      routes: [
        GoRoute(
          path: '/trips',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.push(path),
                child: const Text('apri'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/trips/:id/edit-items',
          builder: (context, state) => PackSuitcaseScreen(
            tripId: state.pathParameters['id']!,
            fromNewTrip: state.uri.queryParameters['from'] == 'new',
          ),
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
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  /// La riga di un oggetto.
  Finder rowOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(PackItemRow));

  Checkbox checkboxOf(WidgetTester tester, String name) => tester.widget(
    find.descendant(of: rowOf(name), matching: find.byType(Checkbox)),
  );

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> tapInRow(WidgetTester tester, String name, IconData icon) async {
    final finder = find.descendant(
      of: rowOf(name),
      matching: find.byIcon(icon),
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Sceglie una casa dal selettore aperto dalla pillola "Da".
  Future<void> pickHouse(
    WidgetTester tester, {
    required String from,
    required String to,
  }) async {
    await tapText(tester, from);
    await tester.tap(find.widgetWithText(ListTile, to));
    await tester.pumpAndSettle();
  }

  /// Il salvataggio: l'ultimo viaggio passato a `updateTrip`.
  TripModel savedTrip() =>
      verify(() => tripRepo.updateTrip(captureAny())).captured.single
          as TripModel;

  group('PackSuitcaseScreen — struttura', () {
    testWidgets('con la tastiera aperta "Fatto" non sale', (tester) async {
      arrange();
      await pumpPack(tester);
      final done = find.byType(DsButton).last;
      final before = tester.getTopLeft(done);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(done).dy, before.dy);
    });

    testWidgets('con fromNewTrip mostra l indicatore dei passi', (
      tester,
    ) async {
      arrange();
      await pumpPack(tester, fromNewTrip: true);

      expect(find.byType(DsSteps), findsOneWidget);
    });

    testWidgets('senza fromNewTrip non mostra l indicatore dei passi', (
      tester,
    ) async {
      arrange();
      await pumpPack(tester);

      expect(find.byType(DsSteps), findsNothing);
    });

    testWidgets('una casa sola, che è la meta, mostra i suoi oggetti', (
      tester,
    ) async {
      arrange(
        trip: _trip(destinationHouseId: 'h1'),
        houses: [_milano],
        items: {
          'h1': [_maglietta, _spazzolino],
        },
      );
      await pumpPack(tester);

      expect(find.text('Maglietta'), findsOneWidget);
      expect(find.text('Spazzolino'), findsOneWidget);
      // Con una casa sola il selettore non apre niente: niente freccia.
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('senza bagagli mostra il testo e il link per aggiungerne', (
      tester,
    ) async {
      arrange();
      await pumpPack(tester);

      expect(find.text('Non hai ancora bagagli.'), findsOneWidget);
      expect(find.text('Aggiungi bagagli'), findsOneWidget);
    });

    testWidgets(
      'la casa predefinita è la prima altra casa se la principale è la meta',
      (tester) async {
        arrange(
          trip: _trip(destinationHouseId: 'h1'),
          houses: [_milano, _mare],
          items: {
            'h1': [_maglietta],
            'h2': [_calzini],
          },
        );
        await pumpPack(tester);

        expect(find.text('Calzini'), findsOneWidget);
        expect(find.text('Maglietta'), findsNothing);
      },
    );

    testWidgets('la ricerca filtra per nome gli oggetti della casa', (
      tester,
    ) async {
      arrange(
        items: {
          'h1': [_maglietta, _spazzolino],
        },
      );
      await pumpPack(tester);

      await tester.enterText(find.byType(TextField), 'spazz');
      await tester.pumpAndSettle();

      expect(find.text('Spazzolino'), findsOneWidget);
      expect(find.text('Maglietta'), findsNothing);
    });
  });

  group('PackSuitcaseScreen — selezione', () {
    testWidgets('gli oggetti del viaggio partono spuntati', (tester) async {
      arrange(
        trip: _trip(items: [_tripItem(_maglietta, isChecked: false)]),
        items: {
          'h1': [_maglietta, _spazzolino],
        },
      );
      await pumpPack(tester);

      expect(checkboxOf(tester, 'Maglietta').value, isTrue);
      expect(checkboxOf(tester, 'Spazzolino').value, isFalse);
      expect(find.text('Fatto · 1 oggetto'), findsOneWidget);
    });

    testWidgets(
      'una spunta in un altra casa resta quando si cambia casa e "Fatto" la conta',
      (tester) async {
        arrange(
          houses: [_milano, _mare],
          items: {
            'h1': [_maglietta],
            'h2': [_calzini],
          },
        );
        await pumpPack(tester);

        await pickHouse(tester, from: 'Casa Milano', to: 'Casa al mare');
        await tapText(tester, 'Calzini');
        expect(checkboxOf(tester, 'Calzini').value, isTrue);

        await pickHouse(tester, from: 'Casa al mare', to: 'Casa Milano');
        expect(find.text('Maglietta'), findsOneWidget);
        expect(checkboxOf(tester, 'Maglietta').value, isFalse);
        expect(find.text('Fatto · 1 oggetto'), findsOneWidget);
      },
    );

    testWidgets(
      'salvando, un oggetto già spuntato mantiene isChecked quando cambia la quantità',
      (tester) async {
        arrange(
          trip: _trip(items: [_tripItem(_maglietta, isChecked: true)]),
          items: {
            'h1': [_maglietta],
          },
        );
        await pumpPack(tester);

        await tapInRow(tester, 'Maglietta', Icons.add_circle_outline);
        await tapText(tester, 'Fatto · 1 oggetto');

        final saved = savedTrip();
        expect(saved.items.single.id, 'i-maglietta');
        expect(saved.items.single.quantity, 2);
        expect(saved.items.single.isChecked, isTrue);
      },
    );

    testWidgets('lo stepper non supera la quantità disponibile in casa', (
      tester,
    ) async {
      arrange(
        items: {
          'h1': [
            _item(
              'i-due',
              'Maglietta',
              ItemCategory.vestiti,
              houseId: 'h1',
              quantity: 2,
            ),
          ],
        },
      );
      await pumpPack(tester);

      await tapText(tester, 'Maglietta');
      expect(
        find.descendant(of: rowOf('Maglietta'), matching: find.text('1')),
        findsOneWidget,
      );

      await tapInRow(tester, 'Maglietta', Icons.add_circle_outline);
      expect(
        find.descendant(of: rowOf('Maglietta'), matching: find.text('2')),
        findsOneWidget,
      );

      final add = tester.widget<IconButton>(
        find.ancestor(
          of: find.descendant(
            of: rowOf('Maglietta'),
            matching: find.byIcon(Icons.add_circle_outline),
          ),
          matching: find.byType(IconButton),
        ),
      );
      expect(add.onPressed, isNull);
    });

    testWidgets(
      'un tocco sul numero o a lato dello stepper non toglie l oggetto',
      (tester) async {
        arrange(
          trip: _trip(items: [_tripItem(_maglietta, quantity: 2)]),
          items: {
            'h1': [_maglietta],
          },
        );
        await pumpPack(tester);
        expect(checkboxOf(tester, 'Maglietta').value, isTrue);

        // Il numero tra i due pulsanti.
        await tester.tap(
          find.descendant(of: rowOf('Maglietta'), matching: find.text('2')),
        );
        await tester.pumpAndSettle();
        expect(checkboxOf(tester, 'Maglietta').value, isTrue);

        // Il margine della riga a destra dello stepper.
        final row = tester.getRect(rowOf('Maglietta'));
        final stepper = tester.getRect(find.byType(QuantityStepper));
        await tester.tapAt(
          Offset((stepper.right + row.right) / 2, row.center.dy),
        );
        await tester.pumpAndSettle();
        expect(checkboxOf(tester, 'Maglietta').value, isTrue);

        // Sopra lo stepper, nel margine verticale della riga.
        await tester.tapAt(
          Offset(stepper.center.dx, (row.top + stepper.top) / 2),
        );
        await tester.pumpAndSettle();
        expect(checkboxOf(tester, 'Maglietta').value, isTrue);

        await tapText(tester, 'Fatto · 1 oggetto');
        expect(savedTrip().items.single.quantity, 2);
      },
    );

    testWidgets('un tocco sul nome toglie anche un oggetto con lo stepper', (
      tester,
    ) async {
      arrange(
        trip: _trip(items: [_tripItem(_maglietta, quantity: 2)]),
        items: {
          'h1': [_maglietta],
        },
      );
      await pumpPack(tester);

      await tapText(tester, 'Maglietta');

      expect(checkboxOf(tester, 'Maglietta').value, isFalse);
    });

    testWidgets(
      'salvando, un oggetto nuovo della casa mostrata ha quantità 1, non spuntato e la casa d origine',
      (tester) async {
        arrange(
          houses: [_milano, _mare],
          items: {
            'h1': [_maglietta],
            'h2': [_calzini],
          },
        );
        await pumpPack(tester);

        await tapText(tester, 'Maglietta');
        await tapText(tester, 'Fatto · 1 oggetto');

        final item = savedTrip().items.single;
        expect(item.id, 'i-maglietta');
        expect(item.quantity, 1);
        expect(item.isChecked, isFalse);
        expect(item.originHouseId, 'h1');
      },
    );

    testWidgets('togliendo un oggetto già nel viaggio, "Fatto" lo rimuove', (
      tester,
    ) async {
      arrange(
        trip: _trip(items: [_tripItem(_maglietta), _tripItem(_spazzolino)]),
        items: {
          'h1': [_maglietta, _spazzolino],
        },
      );
      await pumpPack(tester);

      await tapText(tester, 'Maglietta');
      expect(checkboxOf(tester, 'Maglietta').value, isFalse);
      await tapText(tester, 'Fatto · 1 oggetto');

      expect(savedTrip().items.map((i) => i.id), ['i-spazzolino']);
    });

    testWidgets('lo stepper non compare per gli oggetti in quantità singola', (
      tester,
    ) async {
      arrange(
        items: {
          'h1': [_spazzolino],
        },
      );
      await pumpPack(tester);

      await tapText(tester, 'Spazzolino');

      expect(checkboxOf(tester, 'Spazzolino').value, isTrue);
      expect(
        find.descendant(
          of: rowOf('Spazzolino'),
          matching: find.byIcon(Icons.add_circle_outline),
        ),
        findsNothing,
      );
    });

    testWidgets('"Fatto" senza oggetti scelti dice solo Fatto', (tester) async {
      arrange(
        items: {
          'h1': [_spazzolino],
        },
      );
      await pumpPack(tester);

      expect(find.text('Fatto'), findsOneWidget);
    });
  });

  group('PackSuitcaseScreen — bagagli e salvataggio', () {
    testWidgets('"Aggiungi bagagli" apre il foglio di gestione dei bagagli', (
      tester,
    ) async {
      arrange();
      await pumpPack(tester);

      await tapText(tester, 'Aggiungi bagagli');

      expect(find.byType(LuggagesManagementSheet), findsOneWidget);
    });

    testWidgets('i bagagli scelti si salvano in luggages', (tester) async {
      arrange(luggages: [_luggage('l1', 'Zaino'), _luggage('l2', 'Trolley')]);
      await pumpPack(tester);

      await tapText(tester, 'Zaino');
      await tapText(tester, 'Fatto');

      expect(savedTrip().luggages.map((l) => l.id), ['l1']);
    });

    testWidgets('salvando "Fatto" torna alla pagina che ha aperto la valigia', (
      tester,
    ) async {
      arrange(
        items: {
          'h1': [_spazzolino],
        },
      );
      await pumpPack(tester, fromNewTrip: true);

      await tapText(tester, 'Spazzolino');
      await tapText(tester, 'Fatto · 1 oggetto');

      expect(find.text('apri'), findsOneWidget);
      expect(find.text('Prepara la valigia'), findsNothing);
    });

    testWidgets('Indietro con modifiche chiede conferma e Annulla resta', (
      tester,
    ) async {
      arrange(
        items: {
          'h1': [_spazzolino],
        },
      );
      await pumpPack(tester);

      await tapText(tester, 'Spazzolino');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Uscire senza salvare?'), findsOneWidget);

      await tapText(tester, 'Annulla');

      expect(find.text('Prepara la valigia'), findsOneWidget);
      verifyNever(() => tripRepo.updateTrip(any()));
    });

    testWidgets('confermando l uscita si torna senza salvare', (tester) async {
      arrange(
        items: {
          'h1': [_spazzolino],
        },
      );
      await pumpPack(tester);

      await tapText(tester, 'Spazzolino');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tapText(tester, 'Conferma');

      expect(find.text('apri'), findsOneWidget);
      verifyNever(() => tripRepo.updateTrip(any()));
    });

    testWidgets('senza modifiche Indietro esce senza conferma', (tester) async {
      arrange();
      await pumpPack(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Uscire senza salvare?'), findsNothing);
      expect(find.text('apri'), findsOneWidget);
    });
  });

  group('PackSuitcaseScreen — casa senza oggetti', () {
    testWidgets('offre di creare un oggetto nella casa mostrata', (
      tester,
    ) async {
      // Senza questa azione, creare un viaggio da una casa vuota finisce in un
      // vicolo cieco: la pagina dice che non c'è niente e non offre una strada.
      arrange();
      await pumpPack(tester);

      expect(find.byKey(const Key('trip_items_empty_add')), findsOneWidget);
      expect(find.byType(DsEmptyState), findsOneWidget);
    });

    testWidgets('con oggetti presenti non mostra l azione', (tester) async {
      arrange(
        items: {
          'h1': [_spazzolino],
        },
      );
      await pumpPack(tester);

      expect(find.byKey(const Key('trip_items_empty_add')), findsNothing);
    });

    testWidgets(
      'con casa non vuota ma ricerca senza risultati non offre l azione',
      (tester) async {
        // La risposta alla ricerca vuota è cambiare la ricerca, non creare.
        arrange(
          items: {
            'h1': [_spazzolino],
          },
        );
        await pumpPack(tester);

        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();

        expect(find.text('Nessun oggetto trovato'), findsOneWidget);
        expect(find.byKey(const Key('trip_items_empty_add')), findsNothing);
      },
    );
  });
}

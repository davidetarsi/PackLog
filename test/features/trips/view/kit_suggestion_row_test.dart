import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/kits/model/kit_model.dart';
import 'package:pack_log/features/kits/repositories/kit_repository.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/trip_lifecycle_service.dart';
import 'package:pack_log/features/trips/view/trip_detail_screen.dart';
import 'package:pack_log/features/trips/view/widgets/slots/kit_learn_row.dart';
import 'package:pack_log/features/trips/view/widgets/slots/kit_suggestion_row.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/memory_asset_loader.dart';

class _MockTripRepo extends Mock implements TripRepository {}

class _MockHouseRepo extends Mock implements HouseRepository {}

class _MockLifecycle extends Mock implements TripLifecycleService {}

class _MockCore extends Mock implements CoreAnalyticsService {}

class _MockRaw extends Mock implements AppAnalyticsService {}

class _MockSync extends Mock implements SyncOrchestrator {}

class _MockKitRepo extends Mock implements KitRepository {}

class _FixedItems extends ItemNotifier {
  _FixedItems(this.items);

  final List<ItemModel> items;

  @override
  Future<List<ItemModel>> build(String houseId) async => items;
}

final _casa = HouseModel(
  id: 'h1',
  name: 'Casa',
  isPrimary: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ItemModel _item(String id, String name, {int? quantity}) => ItemModel(
  id: id,
  houseId: 'h1',
  name: name,
  category: ItemCategory.vestiti,
  quantity: quantity,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

KitModel _kit(
  String id,
  String name, {
  Map<String, int> yes = const {},
  List<String> no = const [],
  List<String> activities = const [],
}) => KitModel(
  id: id,
  houseId: 'h1',
  name: name,
  activities: activities,
  learned: KitLearned(yes: yes, no: no),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

AiKitSuggestion _suggestion(
  String kitId,
  Map<String, int> missing, {
  int taken = 3,
  int total = 5,
}) => AiKitSuggestion(
  kitId: kitId,
  taken: taken,
  total: total,
  missing: [
    for (final e in missing.entries) KitItemRef(itemId: e.key, copies: e.value),
  ],
);

TripModel _trip({
  List<AiKitSuggestion> suggestions = const [],
  List<String> counted = const [],
  List<TripItem> items = const [],
}) => TripModel(
  id: 'trip-1',
  name: 'Dolomiti',
  items: items,
  aiSetup: const AiPackingSetup(
    houseId: 'h1',
    stops: {
      'a': AiStopAnswers(activities: ['trekking', 'ski']),
      'b': AiStopAnswers(activities: ['trekking']),
    },
  ),
  aiResult: AiPackingResult(
    generatedAt: DateTime(2026, 11),
    houseId: 'h1',
    slots: [
      AiSlot(
        id: 'u-magliette',
        type: 'u-magliette',
        category: ItemCategory.vestiti,
        level: AiSlotLevel.useful,
        name: 'Magliette',
        copies: 3,
        remaining: 3,
        addLabel: 'Aggiungi',
      ),
    ],
    kitSuggestions: suggestions,
    kitLearnCounted: counted,
  ),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late _MockTripRepo tripRepo;
  late _MockKitRepo kitRepo;
  late _MockSync sync;
  late _MockRaw raw;
  late TripModel current;
  late List<KitModel> kits;
  late List<ItemModel> houseItems;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(_trip());
  });

  setUp(() {
    tripRepo = _MockTripRepo();
    kitRepo = _MockKitRepo();
    sync = _MockSync();
    raw = _MockRaw();
    when(
      () => raw.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    kits = [_kit('k1', 'Montagna')];
    houseItems = [
      _item('kway', 'K-way'),
      _item('calzetti', 'Calzetti merino', quantity: 3),
    ];
    when(() => sync.requestSync()).thenReturn(null);
    when(() => tripRepo.updateTrip(any())).thenAnswer((inv) async {
      current = inv.positionalArguments.first as TripModel;
    });
    when(() => tripRepo.getAllTrips()).thenAnswer((_) async => [current]);
    when(() => kitRepo.watchKits('h1')).thenAnswer((_) => Stream.value(kits));
    when(() => kitRepo.recordYes(any(), any())).thenAnswer((inv) async {
      final kit = kits.firstWhere((k) => k.id == inv.positionalArguments[0]);
      final yes = {...kit.learned.yes};
      for (final use in inv.positionalArguments[1] as List<String>) {
        yes[use] = (yes[use] ?? 0) + 1;
      }
      return kit.copyWith(
        learned: KitLearned(yes: yes, no: kit.learned.no),
      );
    });
    when(() => kitRepo.learnUse(any(), any())).thenAnswer((_) async {});
    when(() => kitRepo.refuseUse(any(), any())).thenAnswer((_) async {});
  });

  Future<void> pumpDetail(WidgetTester tester, TripModel trip) async {
    current = trip;
    final lifecycle = _MockLifecycle();
    when(
      () => lifecycle.transferItemsForCompletedTrips(any()),
    ).thenAnswer((_) async => <String>{});
    when(() => lifecycle.computeNextStatusChange(any())).thenReturn(null);
    final houseRepo = _MockHouseRepo();
    when(() => houseRepo.getAllHouses()).thenAnswer((_) async => [_casa]);
    tester.view.physicalSize = const Size(390, 4000);
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
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(tripRepo),
          houseRepositoryProvider.overrideWithValue(houseRepo),
          tripLifecycleServiceProvider.overrideWithValue(lifecycle),
          coreAnalyticsServiceProvider.overrideWithValue(_MockCore()),
          analyticsServiceProvider.overrideWithValue(raw),
          syncOrchestratorProvider.overrideWithValue(sync),
          kitRepositoryProvider.overrideWithValue(kitRepo),
          itemNotifierProvider(
            'h1',
          ).overrideWith(() => _FixedItems(houseItems)),
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
              theme: AppTheme.dark,
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

  final addButton = find.byKey(const Key('kit_row_add'));

  /// "Aggiungili in valigia" e il tempo del volo (l'attesa prima di partire
  /// nasce dopo l'ultimo frame).
  Future<void> addAll(WidgetTester tester) async {
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  final dismiss = find.byKey(const Key('kit_row_dismiss'));

  testWidgets('la X è sul bordo destro e "Aggiungili" sotto "Mancano"', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: KitSuggestionRow(
                kitName: 'Montagna',
                taken: 1,
                total: 3,
                missing: const [(name: 'K-way', copies: 1)],
                onAdd: () {},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final row = tester.getRect(find.byType(KitSuggestionRow));
    final x = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('kit_row_dismiss')),
        matching: find.byType(Icon),
      ),
    );
    expect(x.right, row.right);
    final missingLeft = tester.getTopLeft(
      find.byKey(const Key('kit_row_missing')),
    );
    final addLeft = tester.getTopLeft(
      find.descendant(
        of: find.byKey(const Key('kit_row_add')),
        matching: find.byType(Text),
      ),
    );
    expect(addLeft.dx, missingLeft.dx);
  });

  group('la riga del kit', () {
    testWidgets('mostra nomi e copie dei mancanti', (tester) async {
      await pumpDetail(
        tester,
        _trip(
          suggestions: [
            _suggestion('k1', {'kway': 1, 'calzetti': 2}),
          ],
        ),
      );
      expect(find.text('Kit Montagna'), findsOneWidget);
      expect(find.text('3 su 5 già in valigia'), findsOneWidget);
      expect(find.text('Mancano K-way e Calzetti merino ×2'), findsOneWidget);
      expect(find.text('Aggiungili in valigia'), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    });

    testWidgets('senza proposte non compare', (tester) async {
      await pumpDetail(tester, _trip());
      expect(find.byType(KitSuggestionRow), findsNothing);
    });

    testWidgets('una riga sola con due kit sopra soglia, poi la seconda', (
      tester,
    ) async {
      kits = [_kit('k1', 'Montagna'), _kit('k2', 'Aereo')];
      await pumpDetail(
        tester,
        _trip(
          suggestions: [
            _suggestion('k1', {'kway': 1}),
            _suggestion('k2', {'calzetti': 1}),
          ],
        ),
      );
      expect(find.byType(KitSuggestionRow), findsOneWidget);
      expect(find.text('Kit Montagna'), findsOneWidget);

      await tester.tap(dismiss);
      await tester.pumpAndSettle();
      expect(find.byType(KitSuggestionRow), findsOneWidget);
      expect(find.text('Kit Aereo'), findsOneWidget);
    });

    testWidgets('Aggiungili mette gli oggetti e nasconde la riga', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _trip(
          suggestions: [
            _suggestion('k1', {'kway': 1, 'calzetti': 2}),
          ],
        ),
      );
      await addAll(tester);

      expect(find.byType(KitSuggestionRow), findsNothing);
      expect(current.aiResult!.kitAnswers, {'k1': 'added'});
      expect(current.aiResult!.kitLearnCounted, ['k1']);
      expect(
        {for (final i in current.items) i.id: i.quantity},
        {'kway': 1, 'calzetti': 2},
      );
      expect(find.text('K-way'), findsOneWidget);
    });

    testWidgets('ricalcola il kit dopo una rimozione ancora in salvataggio', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _trip(
          items: [
            TripItem(
              id: 'calzetti',
              name: 'Calzetti merino',
              category: ItemCategory.vestiti,
              quantity: 1,
            ),
          ],
          suggestions: [
            _suggestion('k1', {'calzetti': 2}),
          ],
        ),
      );
      final removal = Completer<void>();
      addTearDown(() {
        if (!removal.isCompleted) removal.complete();
      });
      var writes = 0;
      when(() => tripRepo.updateTrip(any())).thenAnswer((inv) async {
        final next = inv.positionalArguments.first as TripModel;
        if (++writes == 1) await removal.future;
        current = next;
      });
      await tester.tap(find.byKey(const Key('trip_item_remove_calzetti')));
      await tester.pump();
      await addAll(tester);
      expect(writes, 1);
      removal.complete();
      await tester.pumpAndSettle();
      expect(current.items.single.id, 'calzetti');
      expect(current.items.single.quantity, 2);
      expect(current.aiResult!.kitAnswers, {'k1': 'added'});
    });

    testWidgets('eventi: accettata e scartata', (tester) async {
      kits = [_kit('k1', 'Montagna'), _kit('k2', 'Aereo')];
      houseItems = [...houseItems, _item('cuffia', 'Cuffia')];
      await pumpDetail(
        tester,
        _trip(
          suggestions: [
            _suggestion('k1', {'kway': 1, 'calzetti': 2}),
            _suggestion('k2', {'cuffia': 1}),
          ],
        ),
      );
      await addAll(tester);
      verify(
        () =>
            raw.logEvent('kit_suggestion_accepted', properties: {'missing': 2}),
      ).called(1);

      await tester.tap(dismiss);
      await tester.pumpAndSettle();
      verify(() => raw.logEvent('kit_suggestion_dismissed')).called(1);
    });

    testWidgets('copie: il massimo, mai la somma né più della casa', (
      tester,
    ) async {
      houseItems = [
        _item('kway', 'K-way', quantity: 2),
        _item('calzetti', 'Calzetti merino', quantity: 3),
      ];
      await pumpDetail(
        tester,
        _trip(
          items: [
            TripItem(
              id: 'calzetti',
              name: 'Calzetti merino',
              category: ItemCategory.vestiti,
              quantity: 1,
            ),
          ],
          suggestions: [
            _suggestion('k1', {'kway': 5, 'calzetti': 2}),
          ],
        ),
      );
      await addAll(tester);

      expect(
        {for (final i in current.items) i.id: i.quantity},
        {'kway': 2, 'calzetti': 2},
      );
    });

    testWidgets('X nasconde la riga e non conta', (tester) async {
      await pumpDetail(
        tester,
        _trip(
          suggestions: [
            _suggestion('k1', {'kway': 1}),
          ],
        ),
      );
      await tester.tap(dismiss);
      await tester.pumpAndSettle();

      expect(find.byType(KitSuggestionRow), findsNothing);
      expect(find.byType(KitLearnRow), findsNothing);
      expect(current.aiResult!.kitAnswers, {'k1': 'dismissed'});
      expect(current.aiResult!.kitLearnCounted, isEmpty);
      expect(current.items, isEmpty);
      verifyNever(() => kitRepo.recordYes(any(), any()));
    });

    testWidgets('mancante cancellato dalla casa: saltato', (tester) async {
      houseItems = [_item('calzetti', 'Calzetti merino', quantity: 3)];
      await pumpDetail(
        tester,
        _trip(
          suggestions: [
            _suggestion('k1', {'kway': 1, 'calzetti': 2}),
          ],
        ),
      );
      expect(find.text('Mancano Calzetti merino ×2'), findsOneWidget);
      await addAll(tester);
      expect(current.items.map((i) => i.id), ['calzetti']);
    });

    testWidgets('senza più mancanti in casa la riga non compare', (
      tester,
    ) async {
      houseItems = const [];
      await pumpDetail(
        tester,
        _trip(
          suggestions: [
            _suggestion('k1', {'kway': 1}),
          ],
        ),
      );
      expect(find.byType(KitSuggestionRow), findsNothing);
    });

    testWidgets('kit cancellato: niente riga e nessun crash', (tester) async {
      kits = const [];
      await pumpDetail(
        tester,
        _trip(
          suggestions: [
            _suggestion('k1', {'kway': 1}),
          ],
        ),
      );
      expect(find.byType(KitSuggestionRow), findsNothing);
    });
  });

  group('PackLog impara', () {
    testWidgets('secondo sì in due viaggi propone di imparare per trekking', (
      tester,
    ) async {
      kits = [
        _kit('k1', 'Montagna', yes: {'trekking': 1}),
      ];
      await pumpDetail(
        tester,
        _trip(
          suggestions: [
            _suggestion('k1', {'kway': 1}),
          ],
        ),
      );
      await addAll(tester);

      verify(() => kitRepo.recordYes('k1', ['trekking', 'ski'])).called(1);
      expect(
        find.text('La prossima volta lo aggiungo da solo per trekking?'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('kit_learn_yes')));
      await tester.pumpAndSettle();
      verify(() => kitRepo.learnUse('k1', 'trekking')).called(1);
      verify(
        () => raw.logEvent('kit_use_learned', properties: {'kind': 'activity'}),
      ).called(1);
      expect(find.byType(KitLearnRow), findsNothing);
    });

    testWidgets('No non lo impara e non lo chiede più', (tester) async {
      kits = [
        _kit('k1', 'Montagna', yes: {'trekking': 1}),
      ];
      await pumpDetail(
        tester,
        _trip(
          suggestions: [
            _suggestion('k1', {'kway': 1}),
          ],
        ),
      );
      await addAll(tester);
      await tester.tap(find.byKey(const Key('kit_learn_no')));
      await tester.pumpAndSettle();

      verify(() => kitRepo.refuseUse('k1', 'trekking')).called(1);
      verifyNever(() => raw.logEvent('kit_use_learned'));
      verifyNever(() => kitRepo.learnUse(any(), any()));
      expect(find.byType(KitLearnRow), findsNothing);
    });

    testWidgets('al primo sì non si propone niente', (tester) async {
      await pumpDetail(
        tester,
        _trip(
          suggestions: [
            _suggestion('k1', {'kway': 1}),
          ],
        ),
      );
      await addAll(tester);
      verify(() => kitRepo.recordYes('k1', any())).called(1);
      expect(find.byType(KitLearnRow), findsNothing);
    });

    testWidgets('un uso rifiutato o già nel kit non si propone', (
      tester,
    ) async {
      kits = [
        _kit(
          'k1',
          'Montagna',
          yes: {'trekking': 3, 'ski': 3},
          no: ['trekking'],
          activities: ['ski'],
        ),
      ];
      await pumpDetail(
        tester,
        _trip(
          suggestions: [
            _suggestion('k1', {'kway': 1}),
          ],
        ),
      );
      await addAll(tester);
      expect(find.byType(KitLearnRow), findsNothing);
    });

    testWidgets('stesso viaggio rigenerato non conta due volte', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _trip(
          counted: ['k1'],
          suggestions: [
            _suggestion('k1', {'kway': 1}),
          ],
        ),
      );
      await addAll(tester);

      verifyNever(() => kitRepo.recordYes(any(), any()));
      expect(current.aiResult!.kitLearnCounted, ['k1']);
      expect(current.aiResult!.kitAnswers, {'k1': 'added'});
    });
  });
}

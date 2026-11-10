import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/auth/auth_provider.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/tour/model/onboarding_state.dart';
import 'package:pack_log/features/tour/providers/post_login_onboarding_provider.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/ai_packing_request.dart';
import 'package:pack_log/features/trips/model/pack_trip_job.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/ai_packing_run_provider.dart';
import 'package:pack_log/features/trips/providers/suitcase_edits_provider.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/features/trips/services/pack_trip_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SentryLevel;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database_setup.dart';

/// La valigia AI salvata da `aiPackingRunProvider` con il TripNotifier vero e
/// la coda vera: la prima adozione, la rigenerazione e la guardia "id già
/// esistente" non producono eventi in `valigia_modifiche`.

class _Trips extends Mock implements TripRepository {}

class _Items extends Mock implements ItemRepository {}

class _Sync extends Mock implements SyncOrchestrator {}

class _Analytics extends Mock implements CoreAnalyticsService {}

class _Monitoring extends AppMonitoringService {
  @override
  void captureException(
    Object exception, {
    StackTrace? stackTrace,
    SentryLevel level = SentryLevel.error,
    Map<String, String>? tags,
  }) {}
}

class _Service extends PackTripService {
  _Service(this.result) : super(token: () => 'jwt');
  final AiPackingResult result;

  @override
  Future<AiPackingResult> generate(
    Map<String, dynamic> body, {
    required String houseId,
  }) async => result;
}

class _HouseItems extends ItemNotifier {
  @override
  Future<List<ItemModel>> build(String houseId) async => [_house('a')];
}

class _Onboarding extends PostLoginOnboarding {
  @override
  Future<OnboardingState> build() async =>
      const OnboardingState(step: OnboardingStep.firstTrip);

  @override
  Future<void> completeFirstTrip() async {}
}

final _old = DateTime(2026, 10, 1);
final _fresh = DateTime(2026, 11, 8);
final _departure = DateTime.now().add(const Duration(days: 30));

ItemModel _house(String id) => ItemModel(
  id: id,
  houseId: 'h1',
  name: 'Capo $id',
  category: ItemCategory.vestiti,
  quantity: 3,
  createdAt: _old,
  updatedAt: _old,
);

AiPackingResult _result(DateTime at, String itemId) => AiPackingResult(
  generatedAt: at,
  houseId: 'h1',
  proposal: [
    AiPackedItem(
      itemId: itemId,
      quantity: 1,
      reason: const AiReason(code: 'c', label: 'l', sentence: 's'),
    ),
  ],
  slots: const [],
);

TripModel _trip({AiPackingResult? result, List<TripItem> items = const []}) =>
    TripModel(
      id: 't1',
      name: 'Viaggio',
      items: items,
      departureDateTime: _departure,
      aiResult: result,
      createdAt: _old,
      updatedAt: _old,
    );

AiPackingRequest _request(TripModel trip, {required bool isNew}) =>
    AiPackingRequest(
      trip: trip,
      isNew: isNew,
      setup: const AiPackingSetup(houseId: 'h1', luggageId: 'l1'),
      job: PackTripJob(
        body: const {'trip': {}},
        houseId: 'h1',
        title: 'Islanda',
        nights: 3,
        isRegeneration: !isNew,
        setupChanged: const [],
      ),
    );

void main() {
  late AppDatabase db;
  late List<TripModel> stored;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(_trip());
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = createTestDatabase();
    stored = [];
    final trips = _Trips();
    when(() => trips.getAllTrips()).thenAnswer((_) async => [...stored]);
    when(() => trips.addTrip(any())).thenAnswer((i) async {
      stored.add(i.positionalArguments.first as TripModel);
    });
    when(() => trips.updateTrip(any())).thenAnswer((i) async {
      final t = i.positionalArguments.first as TripModel;
      stored = [for (final s in stored) s.id == t.id ? t : s];
    });
    final items = _Items();
    when(
      () => items.getItemsByIds(any()),
    ).thenAnswer((_) async => [_house('a')]);
    final sync = _Sync();
    when(() => sync.requestSync()).thenReturn(null);
    container = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(trips),
        itemRepositoryProvider.overrideWithValue(items),
        syncOrchestratorProvider.overrideWithValue(sync),
        coreAnalyticsServiceProvider.overrideWithValue(_Analytics()),
        monitoringServiceProvider.overrideWithValue(_Monitoring()),
        suitcaseEditsDaoProvider.overrideWithValue(db.suitcaseEditsDao),
        currentUserIdProvider.overrideWithValue('u-1'),
        packTripServiceProvider.overrideWithValue(
          _Service(_result(_fresh, 'a')),
        ),
        itemNotifierProvider('h1').overrideWith(_HouseItems.new),
        postLoginOnboardingProvider.overrideWith(_Onboarding.new),
      ],
    );
    container.listen(aiPackingRunProvider, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await closeTestDatabase(db);
  });

  Future<void> runAndWait(AiPackingRequest request) async {
    await container.read(tripNotifierProvider.future);
    container.read(aiPackingRunProvider.notifier).start(request);
    for (var i = 0; i < 100; i++) {
      if (container.read(aiPackingRunProvider) is AiRunDone) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(container.read(aiPackingRunProvider), isA<AiRunDone>());
    // La coda si scrive in background: si lascia il tempo di farlo.
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  test('ai_run_adoption_records_no_edits: viaggio nuovo (addTrip)', () async {
    await runAndWait(_request(_trip(), isNew: true));

    expect(stored.single.aiResult?.generatedAt, _fresh);
    expect(await db.suitcaseEditsDao.pending(), isEmpty);
  });

  test('ai_run_adoption_records_no_edits: Rigenera (updateTrip)', () async {
    final existing = _trip(
      result: _result(_old, 'z'),
      items: [
        TripItem(
          id: 'z',
          name: 'Vecchio',
          category: ItemCategory.vestiti,
          quantity: 1,
        ),
      ],
    );
    stored = [existing];

    await runAndWait(_request(existing, isNew: false));

    expect(stored.single.aiResult?.generatedAt, _fresh);
    expect(await db.suitcaseEditsDao.pending(), isEmpty);
  });

  test('ai_run_adoption_records_no_edits: guardia id già esistente', () async {
    // Un Riprova dopo un salvataggio riuscito a metà: il viaggio c'è già.
    final existing = _trip(
      result: _result(_old, 'z'),
      items: [
        TripItem(
          id: 'z',
          name: 'Vecchio',
          category: ItemCategory.vestiti,
          quantity: 1,
        ),
      ],
    );
    stored = [existing];

    await runAndWait(_request(_trip(), isNew: true));

    expect(stored.single.aiResult?.generatedAt, _fresh);
    expect(await db.suitcaseEditsDao.pending(), isEmpty);
  });

  test(
    'controllo: dopo l adozione una modifica dell utente si registra',
    () async {
      await runAndWait(_request(_trip(), isNew: true));
      final adopted = container.read(tripNotifierProvider).requireValue.single;

      await container
          .read(tripNotifierProvider.notifier)
          .updateTrip(adopted.copyWith(items: const []));

      for (var i = 0; i < 100; i++) {
        if ((await db.suitcaseEditsDao.pending()).isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(await db.suitcaseEditsDao.pending(), hasLength(1));
    },
  );
}

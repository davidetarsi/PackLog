import 'package:pack_log/core/database/exceptions/database_exceptions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/luggages/providers/luggage_provider.dart';
import 'package:pack_log/features/luggages/repositories/luggage_repository.dart';

class MockLuggageRepository extends Mock implements LuggageRepository {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

void main() {
  late MockLuggageRepository mockRepository;
  late MockCoreAnalyticsService mockAnalytics;
  late MockSyncOrchestrator mockSync;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockLuggageRepository();
    mockAnalytics = MockCoreAnalyticsService();
    mockSync = MockSyncOrchestrator();

    registerFallbackValue(
      LuggageModel(
        id: 'fallback',
        houseId: 'fallback',
        name: 'Fallback',
        sizeType: LuggageSize.cabinBaggage,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    when(
      () => mockAnalytics.trackLuggageCreated(size: any(named: 'size')),
    ).thenReturn(null);
    when(() => mockSync.requestSync()).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        luggageRepositoryProvider.overrideWithValue(mockRepository),
        coreAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
        syncOrchestratorProvider.overrideWithValue(mockSync),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test(
    'una rinomina aggiorna anche i bagagli del viaggio già osservati',
    () async {
      var stored = LuggageModel(
        id: 'l-1',
        houseId: 'h-1',
        name: 'Zaino',
        sizeType: LuggageSize.smallBackpack,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(
        () => mockRepository.getAllLuggages(),
      ).thenAnswer((_) async => [stored]);
      when(
        () => mockRepository.getLuggagesByTripId('t-1'),
      ).thenAnswer((_) async => [stored]);
      when(() => mockRepository.updateLuggage(any())).thenAnswer((call) async {
        stored = call.positionalArguments.first as LuggageModel;
      });
      final subscription = container.listen(
        luggagesByTripProvider('t-1'),
        (_, _) {},
      );
      addTearDown(subscription.close);
      expect(
        (await container.read(
          luggagesByTripProvider('t-1').future,
        )).single.name,
        'Zaino',
      );
      await container.read(luggageNotifierProvider.future);
      await container
          .read(luggageNotifierProvider.notifier)
          .updateLuggage(stored.copyWith(name: 'Zaino nuovo'));
      expect(
        (await container.read(
          luggagesByTripProvider('t-1').future,
        )).single.name,
        'Zaino nuovo',
      );
    },
  );

  test(
    'eliminazione rifiutata dal repository resta un errore recuperabile',
    () async {
      when(
        () => mockRepository.getAllLuggages(),
      ).thenAnswer((_) async => <LuggageModel>[]);
      when(
        () => mockRepository.deleteLuggage('missing'),
      ).thenAnswer((_) async => false);
      await container.read(luggageNotifierProvider.future);
      await expectLater(
        container
            .read(luggageNotifierProvider.notifier)
            .deleteLuggage('missing'),
        throwsA(isA<AppDatabaseException>()),
      );
      verifyNever(() => mockSync.requestSync());
    },
  );

  test(
    'un reload fallito dopo insert riuscito non richiede una seconda scrittura',
    () async {
      final model = LuggageModel(
        id: 'new',
        houseId: 'h-1',
        name: 'Nuovo',
        sizeType: LuggageSize.smallBackpack,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      var reads = 0;
      when(() => mockRepository.getAllLuggages()).thenAnswer((_) async {
        if (reads++ > 0) throw const EntityLoadException('reload');
        return <LuggageModel>[];
      });
      when(() => mockRepository.addLuggage(any())).thenAnswer((_) async {});
      await container.read(luggageNotifierProvider.future);
      await expectLater(
        container.read(luggageNotifierProvider.notifier).addLuggage(model),
        completes,
      );
      expect(container.read(luggageNotifierProvider).requireValue, [model]);
      verify(() => mockRepository.addLuggage(model)).called(1);
      verify(() => mockSync.requestSync()).called(1);
    },
  );

  group('LuggageNotifier - elenco globale', () {
    test('build carica bagagli senza filtro per casa', () async {
      when(() => mockRepository.getAllLuggages()).thenAnswer(
        (_) async => [
          LuggageModel(
            id: 'l-1',
            houseId: 'h-1',
            name: 'Zaino',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );

      final result = await container.read(luggageNotifierProvider.future);

      expect(result, hasLength(1));
      expect(result.first.houseId, equals('h-1'));
      verify(() => mockRepository.getAllLuggages()).called(1);
    });

    test(
      'addLuggage rethrows when repository fails (and preserves previous AsyncData)',
      () async {
        when(
          () => mockRepository.getAllLuggages(),
        ).thenAnswer((_) async => <LuggageModel>[]);

        final provider = luggageNotifierProvider;
        await container.read(provider.future);

        final newLuggage = LuggageModel(
          id: 'l-new',
          houseId: 'h-1',
          name: 'Zaino',
          sizeType: LuggageSize.cabinBaggage,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final addException = Exception('add luggage failed');
        when(() => mockRepository.addLuggage(any())).thenThrow(addException);

        final notifier = container.read(provider.notifier);

        // Contract: rethrowOnly=true — rethrow lets ErrorRetryDialog see the
        // failure; state is restored to previous AsyncData (no AsyncError flash).
        await expectLater(
          notifier.addLuggage(newLuggage),
          throwsA(equals(addException)),
        );

        final finalState = container.read(provider);
        expect(finalState, isA<AsyncData<List<LuggageModel>>>());
      },
    );
  });

  group('luggageNotifierProvider (cross-house list for trip selection)', () {
    test('returns the full luggages list via getAllLuggages', () async {
      when(() => mockRepository.getAllLuggages()).thenAnswer(
        (_) async => [
          LuggageModel(
            id: 'l-a',
            houseId: 'h-1',
            name: 'A',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          LuggageModel(
            id: 'l-b',
            name: 'B',
            sizeType: LuggageSize.holdBaggage,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );

      final result = await container.read(luggageNotifierProvider.future);
      expect(result, hasLength(2));
      expect(result.map((l) => l.houseId).toSet(), equals({'h-1', null}));
    });
  });
}

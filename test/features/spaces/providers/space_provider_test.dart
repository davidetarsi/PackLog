import 'package:pack_log/core/database/exceptions/database_exceptions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/spaces/model/space_model.dart';
import 'package:pack_log/features/spaces/providers/space_provider.dart';
import 'package:pack_log/features/spaces/repositories/space_repository.dart';

class MockSpaceRepository extends Mock implements SpaceRepository {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

void main() {
  late MockSpaceRepository mockRepository;
  late MockCoreAnalyticsService mockAnalytics;
  late MockSyncOrchestrator mockSync;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockSpaceRepository();
    mockAnalytics = MockCoreAnalyticsService();
    mockSync = MockSyncOrchestrator();

    registerFallbackValue(
      SpaceModel(
        id: 'fallback',
        houseId: 'fallback',
        name: 'Fallback',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    when(() => mockAnalytics.trackSpaceCreated()).thenReturn(null);
    when(() => mockSync.requestSync()).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        spaceRepositoryProvider.overrideWithValue(mockRepository),
        coreAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
        syncOrchestratorProvider.overrideWithValue(mockSync),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test(
    'eliminazione rifiutata dal repository resta un errore recuperabile',
    () async {
      when(
        () => mockRepository.getSpacesByHouseId('h-1'),
      ).thenAnswer((_) async => <SpaceModel>[]);
      when(
        () => mockRepository.deleteSpace('missing'),
      ).thenAnswer((_) async => false);
      await container.read(spaceNotifierProvider('h-1').future);
      await expectLater(
        container
            .read(spaceNotifierProvider('h-1').notifier)
            .deleteSpace('missing'),
        throwsA(isA<AppDatabaseException>()),
      );
      verifyNever(() => mockSync.requestSync());
    },
  );

  test(
    'un reload fallito dopo insert riuscito non richiede una seconda scrittura',
    () async {
      final model = SpaceModel(
        id: 'new',
        houseId: 'h-1',
        name: 'Nuovo',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      var reads = 0;
      when(() => mockRepository.getSpacesByHouseId('h-1')).thenAnswer((
        _,
      ) async {
        if (reads++ > 0) throw const EntityLoadException('reload');
        return <SpaceModel>[];
      });
      when(() => mockRepository.addSpace(any())).thenAnswer((_) async {});
      await container.read(spaceNotifierProvider('h-1').future);
      await expectLater(
        container.read(spaceNotifierProvider('h-1').notifier).addSpace(model),
        completes,
      );
      expect(container.read(spaceNotifierProvider('h-1')).requireValue, [
        model,
      ]);
      verify(() => mockRepository.addSpace(model)).called(1);
      verify(() => mockSync.requestSync()).called(1);
    },
  );

  group('SpaceNotifier - Family by houseId (P2 #12)', () {
    test('build only loads spaces for the requested houseId', () async {
      when(() => mockRepository.getSpacesByHouseId('h-1')).thenAnswer(
        (_) async => [
          SpaceModel(
            id: 's-1',
            houseId: 'h-1',
            name: 'Armadio',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );

      final result = await container.read(spaceNotifierProvider('h-1').future);

      expect(result, hasLength(1));
      expect(result.first.houseId, equals('h-1'));
      // Verifica che il provider abbia chiamato la query filtrata, non quella
      // globale.
      verify(() => mockRepository.getSpacesByHouseId('h-1')).called(1);
      verifyNever(() => mockRepository.getAllSpaces());
    });

    test(
      'addSpace rethrows when repository fails (and preserves previous AsyncData)',
      () async {
        when(
          () => mockRepository.getSpacesByHouseId('h-1'),
        ).thenAnswer((_) async => <SpaceModel>[]);

        final provider = spaceNotifierProvider('h-1');
        await container.read(provider.future);

        final newSpace = SpaceModel(
          id: 's-new',
          houseId: 'h-1',
          name: 'Armadio',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final addException = Exception('add space failed');
        when(() => mockRepository.addSpace(any())).thenThrow(addException);

        final notifier = container.read(provider.notifier);

        // Contract: rethrowOnly=true — rethrow lets ErrorRetryDialog see the
        // failure; state is restored to previous AsyncData (no AsyncError flash).
        await expectLater(
          notifier.addSpace(newSpace),
          throwsA(equals(addException)),
        );

        final finalState = container.read(provider);
        expect(finalState, isA<AsyncData<List<SpaceModel>>>());
      },
    );
  });
}

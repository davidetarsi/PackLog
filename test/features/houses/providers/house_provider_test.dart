import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';

class MockHouseRepository extends Mock implements HouseRepository {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

void main() {
  late MockHouseRepository mockRepository;
  late MockCoreAnalyticsService mockAnalytics;
  late MockSyncOrchestrator mockSync;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockHouseRepository();
    mockAnalytics = MockCoreAnalyticsService();
    mockSync = MockSyncOrchestrator();

    registerFallbackValue(
      HouseModel(
        id: 'fallback',
        name: 'Fallback',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    when(
      () => mockAnalytics.trackHouseCreated(
        houseId: any(named: 'houseId'),
        totalHouses: any(named: 'totalHouses'),
      ),
    ).thenReturn(null);
    when(() => mockSync.requestSync()).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        houseRepositoryProvider.overrideWithValue(mockRepository),
        coreAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
        syncOrchestratorProvider.overrideWithValue(mockSync),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('HouseNotifier - Error Handling Contract', () {
    test(
      'addHouse rethrows when repository fails (and sets AsyncError)',
      () async {
        // Initial load returns empty list so the provider settles.
        when(
          () => mockRepository.getAllHouses(),
        ).thenAnswer((_) async => <HouseModel>[]);

        final provider = houseNotifierProvider;
        await container.read(provider.future);

        final newHouse = HouseModel(
          id: 'h-new',
          name: 'Casa Nuova',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final addException = Exception('add failed');
        when(() => mockRepository.addHouse(any())).thenThrow(addException);

        final notifier = container.read(provider.notifier);

        // Contract: rethrow lets ErrorRetryDialog see the failure;
        // state still becomes AsyncError before the rethrow.
        await expectLater(
          notifier.addHouse(newHouse),
          throwsA(equals(addException)),
        );

        final finalState = container.read(provider);
        expect(finalState, isA<AsyncError<List<HouseModel>>>());
        expect(finalState.error, equals(addException));
      },
    );
  });
}

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

  group('LuggageNotifier - Family by houseId (P2 #12)', () {
    test('build only loads luggages for the requested houseId', () async {
      when(() => mockRepository.getLuggagesByHouseId('h-1')).thenAnswer(
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

      final result = await container.read(
        luggageNotifierProvider('h-1').future,
      );

      expect(result, hasLength(1));
      expect(result.first.houseId, equals('h-1'));
      verify(() => mockRepository.getLuggagesByHouseId('h-1')).called(1);
      verifyNever(() => mockRepository.getAllLuggages());
    });

    test(
      'addLuggage rethrows when repository fails (and sets AsyncError)',
      () async {
        when(
          () => mockRepository.getLuggagesByHouseId('h-1'),
        ).thenAnswer((_) async => <LuggageModel>[]);

        final provider = luggageNotifierProvider('h-1');
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

        await expectLater(
          notifier.addLuggage(newLuggage),
          throwsA(equals(addException)),
        );

        final finalState = container.read(provider);
        expect(finalState, isA<AsyncError<List<LuggageModel>>>());
        expect(finalState.error, equals(addException));
      },
    );
  });

  group('allLuggagesProvider (cross-house list for trip selection)', () {
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
            houseId: 'h-2',
            name: 'B',
            sizeType: LuggageSize.holdBaggage,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );

      final result = await container.read(allLuggagesProvider.future);
      expect(result, hasLength(2));
      expect(result.map((l) => l.houseId).toSet(), equals({'h-1', 'h-2'}));
    });
  });
}

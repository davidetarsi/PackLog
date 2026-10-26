import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/providers/user_colors_provider.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';

class MockItemRepository extends Mock implements ItemRepository {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      ItemModel(
        id: 'fallback',
        houseId: 'fallback',
        name: 'Fallback',
        category: ItemCategory.varie,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  });

  late MockItemRepository repository;
  late MockCoreAnalyticsService analytics;
  late MockSyncOrchestrator sync;
  late ProviderContainer container;

  setUp(() {
    repository = MockItemRepository();
    analytics = MockCoreAnalyticsService();
    sync = MockSyncOrchestrator();
    when(() => sync.requestSync()).thenReturn(null);
    container = ProviderContainer(
      overrides: [
        itemRepositoryProvider.overrideWithValue(repository),
        coreAnalyticsServiceProvider.overrideWithValue(analytics),
        syncOrchestratorProvider.overrideWithValue(sync),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('userColors restituisce i colori letti dal repository', () async {
    when(
      () => repository.getUsedColors(),
    ).thenAnswer((_) async => ['Blu', 'Rosa chiaro']);

    expect(await container.read(userColorsProvider.future), [
      'Blu',
      'Rosa chiaro',
    ]);
  });

  test('addItem riparte da userColors aggiornati', () async {
    when(() => repository.getUsedColors()).thenAnswer((_) async => ['Blu']);
    when(() => repository.getItemsByHouseId(any())).thenAnswer((_) async => []);
    when(() => repository.addItem(any())).thenAnswer((_) async {});
    await container.read(userColorsProvider.future);

    when(
      () => repository.getUsedColors(),
    ).thenAnswer((_) async => ['Blu', 'Verde']);
    await container
        .read(itemNotifierProvider('casa').notifier)
        .addItem(
          ItemModel(
            id: 'nuovo',
            houseId: 'casa',
            name: 'Maglia',
            category: ItemCategory.vestiti,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            aiMetadata: '{}',
          ),
        );

    expect(await container.read(userColorsProvider.future), ['Blu', 'Verde']);
  });
}

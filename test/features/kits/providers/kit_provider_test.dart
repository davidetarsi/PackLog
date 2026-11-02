import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/kits/model/kit_model.dart';
import 'package:pack_log/features/kits/providers/kit_provider.dart';
import 'package:pack_log/features/kits/repositories/kit_repository.dart';

class MockKitRepository extends Mock implements KitRepository {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

void main() {
  late MockKitRepository repo;
  late MockSyncOrchestrator sync;
  late ProviderContainer container;
  final now = DateTime(2026, 11, 3);
  final kit = KitModel(
    id: 'k1',
    houseId: 'h1',
    name: 'Sci',
    createdAt: now,
    updatedAt: now,
  );

  setUp(() {
    repo = MockKitRepository();
    sync = MockSyncOrchestrator();
    when(() => sync.requestSync()).thenReturn(null);
    container = ProviderContainer(
      overrides: [
        kitRepositoryProvider.overrideWithValue(repo),
        syncOrchestratorProvider.overrideWithValue(sync),
      ],
    );
  });

  tearDown(() => container.dispose());

  test(
    'carica i kit della casa e createKit ricarica e chiede il sync',
    () async {
      var created = false;
      when(
        () => repo.watchKits('h1'),
      ).thenAnswer((_) => Stream.value(created ? [kit] : const []));
      when(
        () => repo.createKit(
          houseId: 'h1',
          name: 'Sci',
          activities: any(named: 'activities'),
          transports: any(named: 'transports'),
        ),
      ).thenAnswer((_) async {
        created = true;
        return kit;
      });

      expect(await container.read(kitNotifierProvider('h1').future), isEmpty);
      final result = await container
          .read(kitNotifierProvider('h1').notifier)
          .createKit(name: 'Sci');

      expect(result.id, 'k1');
      expect(container.read(kitNotifierProvider('h1')).value, [kit]);
      verify(() => sync.requestSync()).called(1);
    },
  );

  test('il limite arriva al chiamante e la lista resta intatta', () async {
    when(() => repo.watchKits('h1')).thenAnswer((_) => Stream.value([kit]));
    when(
      () => repo.addItems('k1', any()),
    ).thenThrow(const KitLimitException(50));
    await container.read(kitNotifierProvider('h1').future);

    await expectLater(
      container.read(kitNotifierProvider('h1').notifier).addItems('k1', {
        'i': 1,
      }),
      throwsA(isA<KitLimitException>()),
    );
    expect(container.read(kitNotifierProvider('h1')).value, [kit]);
  });
}

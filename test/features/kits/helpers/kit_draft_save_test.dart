import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/kits/helpers/kit_draft_save.dart';
import 'package:pack_log/features/kits/model/kit_model.dart';
import 'package:pack_log/features/kits/providers/kit_provider.dart';
import 'package:pack_log/features/kits/repositories/kit_repository.dart';

class MockKitRepository extends Mock implements KitRepository {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

void main() {
  setUpAll(
    () => registerFallbackValue(
      KitModel(
        id: 'f',
        houseId: 'h',
        name: 'f',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ),
  );

  final now = DateTime(2026, 11, 3);
  final kit = KitModel(
    id: 'k1',
    houseId: 'h1',
    name: 'Sci',
    createdAt: now,
    updatedAt: now,
  );

  test('se addItems fallisce dopo createKit, il riprova aggiorna e non '
      'crea un doppione', () async {
    final repo = MockKitRepository();
    final sync = MockSyncOrchestrator();
    when(() => sync.requestSync()).thenReturn(null);
    when(() => repo.watchKits('h1')).thenAnswer((_) => Stream.value(const []));
    when(
      () => repo.createKit(
        houseId: 'h1',
        name: 'Sci',
        activities: any(named: 'activities'),
        transports: any(named: 'transports'),
      ),
    ).thenAnswer((_) async => kit);
    when(() => repo.updateKit(any())).thenAnswer((_) async {});
    var calls = 0;
    when(() => repo.addItems('k1', any())).thenAnswer((_) async {
      if (calls++ == 0) throw StateError('rete');
    });
    final container = ProviderContainer(
      overrides: [
        kitRepositoryProvider.overrideWithValue(repo),
        syncOrchestratorProvider.overrideWithValue(sync),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(kitNotifierProvider('h1').notifier);

    KitModel? existing;
    Future<void> attempt() => saveKitDraft(
      notifier,
      existing: existing,
      onCreated: (k) => existing = k,
      name: 'Sci',
      activities: const [],
      transports: const [],
      items: const {'a': 3},
    );

    await expectLater(attempt(), throwsStateError);
    expect(existing?.id, 'k1');
    await attempt();

    verify(
      () => repo.createKit(
        houseId: 'h1',
        name: 'Sci',
        activities: any(named: 'activities'),
        transports: any(named: 'transports'),
      ),
    ).called(1);
    verify(() => repo.addItems('k1', {'a': 3})).called(2);
  });
}

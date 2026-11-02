import 'dart:async';

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
    'carica i kit della casa e createKit chiede il sync; la lista segue lo stream',
    () async {
      final stream = StreamController<List<KitModel>>.broadcast(sync: true);
      addTearDown(stream.close);
      when(() => repo.watchKits('h1')).thenAnswer((_) {
        // Il primo valore arriva alla sottoscrizione, come in Drift.
        return Stream<List<KitModel>>.multi((c) {
          c.add(const []);
          final sub = stream.stream.listen(c.add);
          c.onCancel = sub.cancel;
        });
      });
      when(
        () => repo.createKit(
          houseId: 'h1',
          name: 'Sci',
          activities: any(named: 'activities'),
          transports: any(named: 'transports'),
        ),
      ).thenAnswer((_) async {
        stream.add([kit]);
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

  test(
    'un valore nuovo dello stream aggiorna lo stato senza mutazioni',
    () async {
      final stream = StreamController<List<KitModel>>();
      addTearDown(stream.close);
      when(() => repo.watchKits('h1')).thenAnswer((_) => stream.stream);
      stream.add(const []);
      expect(await container.read(kitNotifierProvider('h1').future), isEmpty);

      stream.add([kit]);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(kitNotifierProvider('h1')).value, [kit]);
    },
  );

  test('chiude la sottoscrizione quando il provider è eliminato', () async {
    var cancelled = false;
    final stream = StreamController<List<KitModel>>(
      onCancel: () => cancelled = true,
    );
    when(() => repo.watchKits('h1')).thenAnswer((_) => stream.stream);
    stream.add(const []);
    await container.read(kitNotifierProvider('h1').future);

    container.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(cancelled, isTrue);
  });
}

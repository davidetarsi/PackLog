import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/services/database_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/drift_item_repository.dart';
import 'package:pack_log/features/kits/providers/kit_provider.dart';
import 'package:pack_log/features/kits/repositories/drift_kit_repository.dart';
import 'package:pack_log/features/kits/repositories/kit_repository.dart';

import '../../../helpers/catalogo_di_prova.dart';
import '../../../helpers/test_database_setup.dart';

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

void main() {
  late AppDatabase db;
  late DriftItemRepository itemRepo;
  late ProviderContainer container;
  final now = DateTime(2026, 11, 3, 9);

  setUp(() async {
    caricaCatalogoDelRepo();
    db = createTestDatabase();
    itemRepo = DriftItemRepository(
      db.itemsDao,
      DatabaseService(db),
      () => 'u1',
      kitsDao: db.kitsDao,
    );
    final sync = MockSyncOrchestrator();
    when(() => sync.requestSync()).thenReturn(null);
    container = ProviderContainer(
      overrides: [
        kitRepositoryProvider.overrideWithValue(
          DriftKitRepository(db.kitsDao, () => 'u1'),
        ),
        syncOrchestratorProvider.overrideWithValue(sync),
      ],
    );
    await db.housesDao.insertHouse(
      HousesCompanion.insert(
        id: 'h1',
        name: 'Casa',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.itemsDao.insertItem(
      ItemsCompanion.insert(
        id: 'i1',
        houseId: 'h1',
        name: 'Oggetto',
        category: ItemCategory.varie,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    container.dispose();
    await closeTestDatabase(db);
  });

  List<Object> itemsOfKit() =>
      container.read(kitNotifierProvider('h1')).value!.single.items;

  // Lo stream di Drift consegna con un attimo di ritardo.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  test('cancellare un oggetto altrove aggiorna la lista dei kit', () async {
    final notifier = container.read(kitNotifierProvider('h1').notifier);
    await container.read(kitNotifierProvider('h1').future);
    final kit = await notifier.createKit(name: 'Sci');
    await notifier.addItems(kit.id, {'i1': 1});
    await settle();
    expect(itemsOfKit(), hasLength(1));

    await itemRepo.deleteItems(['i1']);
    await settle();

    expect(itemsOfKit(), isEmpty);
  });
}

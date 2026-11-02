import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/services/database_service.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/drift_item_repository.dart';
import 'package:pack_log/features/kits/repositories/drift_kit_repository.dart';
import 'package:pack_log/features/kits/repositories/kit_repository.dart';

import '../../../helpers/catalogo_di_prova.dart';
import '../../../helpers/test_database_setup.dart';

void main() {
  late AppDatabase db;
  late DriftKitRepository repo;
  late DriftItemRepository itemRepo;
  final now = DateTime(2026, 11, 3, 9);

  Future<void> addItem(String id) => db.itemsDao.insertItem(
    ItemsCompanion.insert(
      id: id,
      houseId: 'h1',
      name: 'Oggetto $id',
      category: ItemCategory.varie,
      createdAt: now,
      updatedAt: now,
    ),
  );

  setUp(() async {
    caricaCatalogoDelRepo();
    db = createTestDatabase();
    repo = DriftKitRepository(db.kitsDao, () => 'u1');
    itemRepo = DriftItemRepository(
      db.itemsDao,
      DatabaseService(db),
      () => 'u1',
      kitsDao: db.kitsDao,
    );
    await db.housesDao.insertHouse(
      HousesCompanion.insert(
        id: 'h1',
        name: 'Casa',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await addItem('i1');
    await addItem('i2');
  });

  tearDown(() => closeTestDatabase(db));

  test('createKit salva usi e nome, e li rilegge', () async {
    final kit = await repo.createKit(
      houseId: 'h1',
      name: 'Sci',
      activities: ['ski'],
    );
    final list = await repo.watchKits('h1').first;
    expect(list.single.id, kit.id);
    expect(list.single.activities, ['ski']);
    expect(list.single.transports, isEmpty);
  });

  test('addItems e removeItem', () async {
    final kit = await repo.createKit(houseId: 'h1', name: 'Sci');
    await repo.addItems(kit.id, {'i1': 2, 'i2': 1});
    var list = await repo.watchKits('h1').first;
    expect(
      {for (final i in list.single.items) i.itemId: i.copies},
      {'i1': 2, 'i2': 1},
    );
    await repo.removeItem(kit.id, 'i1');
    list = await repo.watchKits('h1').first;
    expect(list.single.items.map((i) => i.itemId), ['i2']);
  });

  test('recordYes somma 1 per ogni uso non già nel kit', () async {
    final kit = await repo.createKit(
      houseId: 'h1',
      name: 'Sci',
      activities: ['ski'],
    );
    var updated = await repo.recordYes(kit.id, ['ski', 'trekking', 'plane']);
    expect(updated.learned.yes, {'trekking': 1, 'plane': 1});
    updated = await repo.recordYes(kit.id, ['trekking']);
    expect(updated.learned.yes, {'trekking': 2, 'plane': 1});
    final reloaded = (await repo.watchKits('h1').first).single;
    expect(reloaded.learned.yes['trekking'], 2);
  });

  test('refuseUse aggiunge a learned.no una volta sola', () async {
    final kit = await repo.createKit(houseId: 'h1', name: 'Sci');
    await repo.refuseUse(kit.id, 'sea');
    await repo.refuseUse(kit.id, 'sea');
    expect((await repo.watchKits('h1').first).single.learned.no, ['sea']);
  });

  test('learnUse mette l\'attività o il mezzo al posto giusto', () async {
    final kit = await repo.createKit(houseId: 'h1', name: 'Kit');
    await repo.learnUse(kit.id, 'trekking');
    await repo.learnUse(kit.id, 'plane');
    await repo.learnUse(kit.id, 'plane');
    final k = (await repo.watchKits('h1').first).single;
    expect(k.activities, ['trekking']);
    expect(k.transports, ['plane']);
  });

  test('updateKit non tocca le righe', () async {
    final kit = await repo.createKit(houseId: 'h1', name: 'Sci');
    await repo.addItems(kit.id, {'i1': 1});
    final current = (await repo.watchKits('h1').first).single;
    await repo.updateKit(current.copyWith(name: 'Neve'));
    final k = (await repo.watchKits('h1').first).single;
    expect(k.name, 'Neve');
    expect(k.items, hasLength(1));
  });

  test('deleteItems toglie l\'oggetto dai kit', () async {
    final kit = await repo.createKit(houseId: 'h1', name: 'Sci');
    await repo.addItems(kit.id, {'i1': 1, 'i2': 1});
    await itemRepo.deleteItems(['i1']);
    final k = (await repo.watchKits('h1').first).single;
    expect(k.items.map((i) => i.itemId), ['i2']);
    final row = await (db.select(
      db.kitItems,
    )..where((r) => r.itemId.equals('i1'))).getSingle();
    expect(row.isDeleted, isTrue);
  });

  test('KitLimitException al 51° kit', () async {
    for (var i = 0; i < 50; i++) {
      await repo.createKit(houseId: 'h1', name: 'Kit $i');
    }
    await expectLater(
      repo.createKit(houseId: 'h1', name: 'Uno di troppo'),
      throwsA(isA<KitLimitException>()),
    );
    expect(await repo.watchKits('h1').first, hasLength(50));
  });

  test('KitLimitException al 51° oggetto, nulla viene scritto', () async {
    for (var i = 0; i < 51; i++) {
      await addItem('x$i');
    }
    final kit = await repo.createKit(houseId: 'h1', name: 'Grande');
    await repo.addItems(kit.id, {for (var i = 0; i < 50; i++) 'x$i': 1});
    await expectLater(
      repo.addItems(kit.id, {'x50': 1}),
      throwsA(isA<KitLimitException>()),
    );
    // Cambiare le copie di un oggetto già presente resta lecito.
    await repo.addItems(kit.id, {'x0': 3});
    final k = (await repo.watchKits('h1').first).single;
    expect(k.items, hasLength(50));
    expect(k.items.firstWhere((i) => i.itemId == 'x0').copies, 3);
  });
}

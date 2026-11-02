import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/exceptions/database_exceptions.dart';
import 'package:pack_log/core/database/tables/mixins/syncable_table.dart';
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

  test(
    'deleteItems nasconde l\'oggetto dai kit senza toccare le righe',
    () async {
      final kit = await repo.createKit(houseId: 'h1', name: 'Sci');
      await repo.addItems(kit.id, {'i1': 1, 'i2': 1});
      await itemRepo.deleteItems(['i1']);
      final k = (await repo.watchKits('h1').first).single;
      expect(k.items.map((i) => i.itemId), ['i2']);
      final row = await (db.select(
        db.kitItems,
      )..where((r) => r.itemId.equals('i1'))).getSingle();
      expect(row.isDeleted, isFalse);
    },
  );

  Future<void> addHouse2() => db.housesDao.insertHouse(
    HousesCompanion.insert(
      id: 'h2',
      name: 'Altra casa',
      createdAt: now,
      updatedAt: now,
    ),
  );

  test('moveItemsToHouse nasconde l\'oggetto spostato dal kit della casa '
      'vecchia senza toccarne la riga, e lo rivede quando torna', () async {
    await addHouse2();
    final kit = await repo.createKit(houseId: 'h1', name: 'Sci');
    await repo.addItems(kit.id, {'i1': 1, 'i2': 1});
    await itemRepo.moveItemsToHouse(['i1'], 'h1', 'h2');
    var k = (await repo.watchKits('h1').first).single;
    expect(k.items.map((i) => i.itemId), ['i2']);
    final row = await (db.select(
      db.kitItems,
    )..where((r) => r.itemId.equals('i1'))).getSingle();
    expect(row.isDeleted, isFalse);
    expect(row.syncStatus, SyncStatus.pendingCreate);

    await itemRepo.moveItemsToHouse(['i1'], 'h2', 'h1');
    k = (await repo.watchKits('h1').first).single;
    expect(k.items.map((i) => i.itemId).toSet(), {'i1', 'i2'});
  });

  test('restoreItem riporta l\'oggetto nei kit anche dopo un sync, non '
      'quello tolto a mano', () async {
    final kit = await repo.createKit(houseId: 'h1', name: 'Sci');
    await repo.addItems(kit.id, {'i1': 2, 'i2': 1});
    await repo.removeItem(kit.id, 'i2');
    await itemRepo.deleteItems(['i1', 'i2']);
    expect((await repo.watchKits('h1').first).single.items, isEmpty);

    // Simula un sync nel mezzo: righe sincronizzate, updatedAt cambiato.
    await (db.update(db.kitItems)).write(
      KitItemsCompanion(
        syncStatus: const Value(SyncStatus.synced),
        updatedAt: Value(DateTime.now().add(const Duration(minutes: 5))),
      ),
    );

    expect(await itemRepo.restoreItem('i1'), isTrue);
    expect(await itemRepo.restoreItem('i2'), isTrue);

    final k = (await repo.watchKits('h1').first).single;
    expect({for (final i in k.items) i.itemId: i.copies}, {'i1': 2});
  });

  test('moveItemsToHouse salta gli oggetti già cancellati', () async {
    await addHouse2();
    await itemRepo.deleteItems(['i1']);
    final deleted = await (db.select(
      db.items,
    )..where((t) => t.id.equals('i1'))).getSingle();
    await itemRepo.moveItemsToHouse(['i1'], 'h1', 'h2');
    final after = await (db.select(
      db.items,
    )..where((t) => t.id.equals('i1'))).getSingle();
    expect(after.houseId, 'h1');
    expect(after.updatedAt, deleted.updatedAt);
  });

  test(
    'restoreItem dopo una cancellazione singola lascia il kit com\'era',
    () async {
      final kit = await repo.createKit(houseId: 'h1', name: 'Sci');
      await repo.addItems(kit.id, {'i1': 1});
      await itemRepo.deleteItem('i1');
      await itemRepo.restoreItem('i1');
      final k = (await repo.watchKits('h1').first).single;
      expect(k.items.map((i) => i.itemId), ['i1']);
    },
  );

  test(
    'updateKit su kit inesistente o cancellato lancia EntityNotFound',
    () async {
      final kit = await repo.createKit(houseId: 'h1', name: 'Sci');
      await expectLater(
        repo.updateKit(kit.copyWith(id: 'nope')),
        throwsA(isA<EntityNotFoundException>()),
      );
      await repo.deleteKit(kit.id);
      await expectLater(
        repo.updateKit(kit.copyWith(name: 'Neve')),
        throwsA(isA<EntityNotFoundException>()),
      );
    },
  );

  test('il nome è tagliato e deve avere da 1 a 60 caratteri', () async {
    final kit = await repo.createKit(houseId: 'h1', name: '  Sci  ');
    expect(kit.name, 'Sci');
    await expectLater(
      repo.createKit(houseId: 'h1', name: '   '),
      throwsArgumentError,
    );
    await expectLater(
      repo.createKit(houseId: 'h1', name: 'x' * 61),
      throwsArgumentError,
    );
    expect(
      (await repo.createKit(houseId: 'h1', name: 'x' * 60)).name,
      hasLength(60),
    );
    await expectLater(
      repo.updateKit(kit.copyWith(name: '')),
      throwsArgumentError,
    );
    await repo.updateKit(kit.copyWith(name: '  Neve '));
    expect((await repo.watchKits('h1').first).first.name, 'Neve');
  });

  test(
    'addItems ignora oggetti cancellati, di altre case o inesistenti',
    () async {
      await addHouse2();
      await db.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: 'altrove',
          houseId: 'h2',
          name: 'Altrove',
          category: ItemCategory.varie,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await addItem('morto');
      await itemRepo.deleteItems(['morto']);
      final kit = await repo.createKit(houseId: 'h1', name: 'Sci');
      await repo.addItems(kit.id, {
        'i1': 1,
        'altrove': 1,
        'morto': 1,
        'fantasma': 1,
      });
      final k = (await repo.watchKits('h1').first).single;
      expect(k.items.map((i) => i.itemId), ['i1']);
      final rows = await db.select(db.kitItems).get();
      expect(rows.map((r) => r.itemId), ['i1']);
    },
  );

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

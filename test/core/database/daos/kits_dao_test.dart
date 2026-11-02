import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/tables/mixins/syncable_table.dart';
import 'package:pack_log/features/items/model/item_model.dart';

import '../../../helpers/test_database_setup.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 3, 9);

  setUp(() async {
    db = createTestDatabase();
    await db.housesDao.insertHouse(
      HousesCompanion.insert(
        id: 'h1',
        name: 'Casa',
        createdAt: now,
        updatedAt: now,
      ),
    );
    for (final id in ['i1', 'i2']) {
      await db.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: id,
          houseId: 'h1',
          name: 'Oggetto $id',
          category: ItemCategory.varie,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await db.kitsDao.upsertKit(
      KitsCompanion.insert(
        id: 'k1',
        houseId: 'h1',
        name: 'Sci',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() => closeTestDatabase(db));

  Future<void> addRow(String kitId, String itemId, {int copies = 1}) =>
      db.kitsDao.upsertKitItem(
        KitItemsCompanion.insert(
          id: 'ki-$kitId-$itemId',
          kitId: kitId,
          itemId: itemId,
          copies: Value(copies),
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> rowCount() async =>
      (await db.customSelect('SELECT COUNT(*) AS c FROM kit_items').getSingle())
          .read<int>('c');

  test('watchKitsOfHouse ignora oggetti cancellati', () async {
    await addRow('k1', 'i1');
    await addRow('k1', 'i2');
    await db.itemsDao.deleteItem('i2');

    final kits = await db.kitsDao.watchKitsOfHouse('h1').first;
    expect(kits, hasLength(1));
    expect(kits.single.kit.name, 'Sci');
    expect(kits.single.items.map((r) => r.itemId), ['i1']);
  });

  test(
    'watchKitsOfHouse esclude i kit cancellati e quelli di altre case',
    () async {
      await db.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'h2',
          name: 'Altra',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.kitsDao.upsertKit(
        KitsCompanion.insert(
          id: 'k2',
          houseId: 'h2',
          name: 'Altro',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.kitsDao.upsertKit(
        KitsCompanion.insert(
          id: 'k3',
          houseId: 'h1',
          name: 'Vecchio',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.kitsDao.softDeleteKit('k3');

      final kits = await db.kitsDao.watchKitsOfHouse('h1').first;
      expect(kits.map((k) => k.kit.id), ['k1']);
    },
  );

  test('upsertKitItem riattiva la coppia cancellata', () async {
    await addRow('k1', 'i1', copies: 1);
    await db.kitsDao.softDeleteKitItem('k1', 'i1');
    expect(
      (await db.kitsDao.watchKitsOfHouse('h1').first).single.items,
      isEmpty,
    );

    await db.kitsDao.upsertKitItem(
      KitItemsCompanion.insert(
        id: 'altro-id',
        kitId: 'k1',
        itemId: 'i1',
        copies: const Value(3),
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(await rowCount(), 1);
    final row =
        (await db.kitsDao.watchKitsOfHouse('h1').first).single.items.single;
    expect(row.id, 'ki-k1-i1');
    expect(row.copies, 3);
    expect(row.isDeleted, isFalse);
    expect(row.syncStatus, SyncStatus.pendingUpdate);
  });

  test('softDeleteKit cancella anche le righe', () async {
    await addRow('k1', 'i1');
    await addRow('k1', 'i2');

    await db.kitsDao.softDeleteKit('k1');

    final rows = await db
        .customSelect('SELECT is_deleted, sync_status FROM kit_items')
        .get();
    expect(rows, hasLength(2));
    expect(rows.every((r) => r.read<bool>('is_deleted')), isTrue);
    expect(
      rows.every((r) => r.read<int>('sync_status') != SyncStatus.synced.index),
      isTrue,
    );
    expect(await db.kitsDao.watchKitsOfHouse('h1').first, isEmpty);
    final kit = await db.kitsDao.findKitById('k1');
    expect(kit!.isDeleted, isTrue);
    expect(kit.syncStatus, SyncStatus.pendingUpdate);
  });

  test('upsertKit su un kit esistente imposta updatedAt se assente', () async {
    final old = DateTime(2020);
    await db.kitsDao.upsertKit(
      KitsCompanion.insert(
        id: 'k9',
        houseId: 'h1',
        name: 'Vecchio',
        createdAt: old,
        updatedAt: old,
      ),
    );

    await db.kitsDao.upsertKit(
      const KitsCompanion(id: Value('k9'), name: Value('Nuovo')),
    );

    final kit = await db.kitsDao.findKitById('k9');
    expect(kit!.name, 'Nuovo');
    expect(kit.updatedAt.isAfter(old), isTrue);
  });

  test('softDeleteItemsEverywhere toglie gli oggetti da tutti i kit', () async {
    await db.kitsDao.upsertKit(
      KitsCompanion.insert(
        id: 'k2',
        houseId: 'h1',
        name: 'Mare',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await addRow('k1', 'i1');
    await addRow('k2', 'i1');
    await addRow('k2', 'i2');

    await db.kitsDao.softDeleteItemsEverywhere(['i1']);

    final kits = await db.kitsDao.watchKitsOfHouse('h1').first;
    final byId = {for (final k in kits) k.kit.id: k};
    expect(byId['k1']!.items, isEmpty);
    expect(byId['k2']!.items.map((r) => r.itemId), ['i2']);
  });

  test(
    'upsertKit su un kit esistente lo aggiorna e lo segna da sincronizzare',
    () async {
      await db.kitsDao.markAsSynced('k1', now, localUpdatedAt: now);
      await db.kitsDao.upsertKit(
        KitsCompanion(
          id: const Value('k1'),
          houseId: const Value('h1'),
          name: const Value('Sci e neve'),
          updatedAt: Value(now.add(const Duration(minutes: 1))),
        ),
      );

      final kit = (await db.kitsDao.watchKitsOfHouse('h1').first).single.kit;
      expect(kit.name, 'Sci e neve');
      expect(kit.syncStatus, SyncStatus.pendingUpdate);
      expect(await db.customSelect('SELECT id FROM kits').get(), hasLength(1));
    },
  );

  test('un kit nuovo ha activities, transports e learned vuoti', () async {
    final kit = (await db.kitsDao.watchKitsOfHouse('h1').first).single.kit;
    expect(kit.activities, '[]');
    expect(kit.transports, '[]');
    expect(kit.learned, '{}');
  });
}

import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/database/daos/items_dao.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/services/database_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_metadata_service_provider.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/repositories/drift_item_repository.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/items/services/item_metadata_backfill.dart';
import 'package:pack_log/features/items/services/item_metadata_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database_setup.dart';

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

/// item-metadata finto che risponde [result] quando lo decide il test.
class _FakeService extends ItemMetadataService {
  _FakeService(this.result) : super(url: '', anonKey: '');

  final ItemMetadataResult result;
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<ItemMetadataResult?> fromName(String name) async {
    await _gate.future;
    return result;
  }
}

/// Il DAO vero, ma subito dopo la lettura di una riga esegue [afterRead] (una
/// sola volta): è un salvataggio della scheda che arriva fra la lettura e la
/// scrittura dell'AI.
class _InterleavingDao extends ItemsDao {
  _InterleavingDao(super.db);

  Future<void> Function()? afterRead;

  @override
  Future<Item?> getItemById(String id) async {
    final row = await super.getItemById(id);
    final hook = afterRead;
    afterRead = null;
    if (hook != null) await hook();
    return row;
  }
}

const _answer = ItemMetadataResult(
  metadata: {'name': 'pile blu', 'category': 'Upper Body', 'warmth': 3},
  category: ItemCategory.vestiti,
);

/// Aspetta che le scritture in background finiscano.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late AppDatabase database;
  late _InterleavingDao dao;
  late DriftItemRepository repo;
  final now = DateTime(2026, 10, 31, 10);

  ItemModel item() => ItemModel(
    id: 'item-1',
    houseId: 'house-1',
    name: 'pile blu',
    category: ItemCategory.varie,
    quantity: 1,
    createdAt: now,
    updatedAt: now,
  );

  /// Il salvataggio della scheda: nota e quantità nuove.
  Future<void> sheetSave() => dao.updateItem(
    ItemsCompanion(
      id: const Value('item-1'),
      description: const Value('nota'),
      quantity: const Value(3),
      updatedAt: Value(now.add(const Duration(minutes: 1))),
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = createTestDatabase();
    dao = _InterleavingDao(database);
    repo = DriftItemRepository(dao, DatabaseService(database), () => 'user-1');
    await database.housesDao.insertHouse(
      HousesCompanion.insert(
        id: 'house-1',
        name: 'Casa',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() => closeTestDatabase(database));

  test('la scheda dal nome non annulla il salvataggio della scheda che arriva '
      'fra lettura e scrittura', () async {
    final service = _FakeService(_answer);
    final analytics = MockCoreAnalyticsService();
    when(
      () => analytics.trackItemAdded(
        itemId: any(named: 'itemId'),
        houseId: any(named: 'houseId'),
        category: any(named: 'category'),
        totalItems: any(named: 'totalItems'),
      ),
    ).thenReturn(null);
    final sync = MockSyncOrchestrator();
    when(() => sync.requestSync()).thenReturn(null);
    final container = ProviderContainer(
      overrides: [
        itemRepositoryProvider.overrideWithValue(repo),
        coreAnalyticsServiceProvider.overrideWithValue(analytics),
        syncOrchestratorProvider.overrideWithValue(sync),
        itemMetadataServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await container.read(itemNotifierProvider('house-1').future);
    await container
        .read(itemNotifierProvider('house-1').notifier)
        .addItem(item());

    dao.afterRead = sheetSave;
    service.release();
    await _settle();

    final row = (await dao.getItemById('item-1'))!;
    expect(row.description, 'nota');
    expect(row.quantity, 3);
    expect(row.aiMetadata, isNotNull);
    expect(row.category, ItemCategory.vestiti);
  });

  test('il recupero non annulla il salvataggio della scheda che arriva fra '
      'lettura e scrittura', () async {
    await repo.addItem(item());

    final backfill = ItemMetadataBackfill(
      repository: repo,
      service: _FakeService(_answer)..release(),
      prefs: SharedPreferences.getInstance(),
      now: () => now,
    );
    // La prima lettura è quella dell'elenco da completare (getAllItems non
    // passa da getItemById): la scheda salva dopo la lettura della riga.
    dao.afterRead = sheetSave;
    await backfill.run();

    final row = (await dao.getItemById('item-1'))!;
    expect(row.description, 'nota');
    expect(row.quantity, 3);
    expect(row.aiMetadata, isNotNull);
  });
}

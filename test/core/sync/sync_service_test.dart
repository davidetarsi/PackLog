import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/tables/mixins/syncable_table.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/core/sync/supabase_repository.dart';
import 'package:pack_log/core/sync/sync_service.dart';
import 'package:pack_log/core/sync/tombstone_config_service.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import '../../helpers/test_database_setup.dart';

class MockSupabaseRepository extends Mock implements SupabaseRepository {}

class MockMonitoringService extends Mock implements AppMonitoringService {}

class MockTombstoneConfigService extends Mock
    implements TombstoneConfigService {}

void main() {
  late AppDatabase database;
  late MockSupabaseRepository mockRemote;
  late MockMonitoringService mockMonitoring;
  late MockTombstoneConfigService mockTombstoneConfig;
  late SyncService syncService;

  setUp(() {
    database = createTestDatabase();
    mockRemote = MockSupabaseRepository();
    mockMonitoring = MockMonitoringService();
    mockTombstoneConfig = MockTombstoneConfigService();

    when(
      () => mockMonitoring.logBreadcrumb(
        any(),
        category: any(named: 'category'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);

    when(
      () => mockTombstoneConfig.getRetentionDays(),
    ).thenAnswer((_) async => 15);

    syncService = SyncService(
      housesDao: database.housesDao,
      itemsDao: database.itemsDao,
      tripsDao: database.tripsDao,
      remote: mockRemote,
      monitoring: mockMonitoring,
      tombstoneConfig: mockTombstoneConfig,
    );
  });

  tearDown(() async {
    await closeTestDatabase(database);
  });

  Future<void> insertHouse(String id, {DateTime? updatedAt}) async {
    final now = updatedAt ?? DateTime.now();
    await database.housesDao.insertHouse(
      HousesCompanion.insert(
        id: id,
        name: 'House $id',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> insertItem(
    String id,
    String houseId, {
    DateTime? updatedAt,
  }) async {
    final now = updatedAt ?? DateTime.now();
    await database.itemsDao.insertItem(
      ItemsCompanion.insert(
        id: id,
        houseId: houseId,
        name: 'Item $id',
        category: ItemCategory.varie,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> insertTrip(String id, {DateTime? updatedAt}) async {
    final now = updatedAt ?? DateTime.now();
    await database.tripsDao.insertTrip(
      TripsCompanion.insert(
        id: id,
        name: 'Trip $id',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  group('SyncService - processQueue', () {
    test('pushes local record when remote does not exist', () async {
      await insertHouse('h1');

      when(
        () => mockRemote.fetchHouseById(
          'h1',
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockRemote.upsertHouse(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async {});

      await syncService.processQueue();

      verify(
        () => mockRemote.upsertHouse(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).called(1);

      final house = await database.housesDao.getHouseById('h1');
      expect(house!.syncStatus, equals(SyncStatus.synced));
    });

    test('pushes when local is newer than remote', () async {
      final localTime = DateTime(2026, 4, 28, 14, 0);
      final remoteTime = DateTime(2026, 4, 28, 12, 0);
      await insertHouse('h2', updatedAt: localTime);

      when(
        () => mockRemote.fetchHouseById(
          'h2',
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer(
        (_) async => {
          'id': 'h2',
          'name': 'Remote House',
          'updated_at': remoteTime.toIso8601String(),
        },
      );
      when(
        () => mockRemote.upsertHouse(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async {});

      await syncService.processQueue();

      verify(
        () => mockRemote.upsertHouse(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).called(1);
    });

    test('pulls remote when remote is newer or equal', () async {
      final localTime = DateTime(2026, 4, 28, 10, 0);
      final remoteTime = DateTime(2026, 4, 28, 14, 0);
      await insertHouse('h3', updatedAt: localTime);

      when(
        () => mockRemote.fetchHouseById(
          'h3',
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer(
        (_) async => {
          'id': 'h3',
          'name': 'Updated Remote House',
          'description': null,
          'location_place_id': null,
          'location_display_name': null,
          'location_name': null,
          'location_city': null,
          'location_state': null,
          'location_country': null,
          'location_type': null,
          'location_lat': null,
          'location_lon': null,
          'icon_name': 'home',
          'is_primary': false,
          'created_at': localTime.toIso8601String(),
          'updated_at': remoteTime.toIso8601String(),
          'is_deleted': false,
        },
      );

      await syncService.processQueue();

      verifyNever(
        () => mockRemote.upsertHouse(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      );

      final house = await database.housesDao.getHouseById('h3');
      expect(house!.name, equals('Updated Remote House'));
      expect(house.syncStatus, equals(SyncStatus.synced));
    });

    test('continues processing after a single record failure', () async {
      await insertHouse('fail-house');
      await insertHouse('ok-house');

      when(
        () => mockRemote.fetchHouseById(
          'fail-house',
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenThrow(Exception('network error'));
      when(
        () => mockRemote.fetchHouseById(
          'ok-house',
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockRemote.upsertHouse(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async {});

      await syncService.processQueue();

      final failHouse = await database.housesDao.getHouseById('fail-house');
      expect(failHouse!.syncRetryCount, equals(1));
      expect(failHouse.syncStatus, isNot(equals(SyncStatus.synced)));

      final okHouse = await database.housesDao.getHouseById('ok-house');
      expect(okHouse!.syncStatus, equals(SyncStatus.synced));
    });

    test('processes in FK-safe order: houses → items → trips', () async {
      final callOrder = <String>[];

      await insertHouse('fk-house');
      await insertItem('fk-item', 'fk-house');
      await insertTrip('fk-trip');

      when(
        () => mockRemote.fetchHouseById(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async {
        callOrder.add('house');
        return null;
      });
      when(
        () => mockRemote.upsertHouse(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockRemote.fetchItemById(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async {
        callOrder.add('item');
        return null;
      });
      when(
        () => mockRemote.upsertItem(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockRemote.fetchTripById(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async {
        callOrder.add('trip');
        return null;
      });
      when(
        () => mockRemote.upsertTrip(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async {});

      await syncService.processQueue();

      expect(callOrder, equals(['house', 'item', 'trip']));
    });
  });
}

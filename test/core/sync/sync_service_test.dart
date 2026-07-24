import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/tables/mixins/syncable_table.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/core/sync/supabase_repository.dart';
import 'package:pack_log/core/sync/sync_service.dart';
import 'package:pack_log/core/sync/tombstone_config_service.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import '../../helpers/test_database_setup.dart';

class MockSupabaseRepository extends Mock implements SupabaseRepository {}

class MockMonitoringService extends Mock implements AppMonitoringService {}

class MockTombstoneConfigService extends Mock
    implements TombstoneConfigService {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

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
      spacesDao: database.spacesDao,
      luggagesDao: database.luggagesDao,
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
      ).thenAnswer((_) async => DateTime.utc(2026, 1, 1));

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
      ).thenAnswer((_) async => DateTime.utc(2026, 1, 1));

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
      ).thenAnswer((_) async => DateTime.utc(2026, 1, 1));

      await syncService.processQueue();

      final failHouse = await database.housesDao.getHouseById('fail-house');
      expect(failHouse!.syncRetryCount, equals(1));
      expect(failHouse.syncStatus, isNot(equals(SyncStatus.synced)));

      final okHouse = await database.housesDao.getHouseById('ok-house');
      expect(okHouse!.syncStatus, equals(SyncStatus.synced));
    });

    test(
      'processes in FK-safe order: houses → spaces → luggages → items → trips',
      () async {
        final callOrder = <String>[];

        await insertHouse('fk-house');
        await database.spacesDao.insertSpace(
          SpacesCompanion.insert(
            id: 'fk-space',
            houseId: 'fk-house',
            name: 'Armadio',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await database.luggagesDao.insertLuggage(
          LuggagesCompanion.insert(
            id: 'fk-luggage',
            houseId: 'fk-house',
            name: 'Zaino',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
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
        ).thenAnswer((_) async => DateTime.utc(2026, 1, 1));

        when(
          () => mockRemote.fetchSpaceById(
            any(),
            sentryTrace: any(named: 'sentryTrace'),
          ),
        ).thenAnswer((_) async {
          callOrder.add('space');
          return null;
        });
        when(
          () => mockRemote.upsertSpace(
            any(),
            sentryTrace: any(named: 'sentryTrace'),
          ),
        ).thenAnswer((_) async => DateTime.utc(2026, 1, 1));

        when(
          () => mockRemote.fetchLuggageById(
            any(),
            sentryTrace: any(named: 'sentryTrace'),
          ),
        ).thenAnswer((_) async {
          callOrder.add('luggage');
          return null;
        });
        when(
          () => mockRemote.upsertLuggage(
            any(),
            sentryTrace: any(named: 'sentryTrace'),
          ),
        ).thenAnswer((_) async => DateTime.utc(2026, 1, 1));

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
        ).thenAnswer((_) async => DateTime.utc(2026, 1, 1));

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
        ).thenAnswer((_) async => DateTime.utc(2026, 1, 1));

        await syncService.processQueue();

        expect(
          callOrder,
          equals(['house', 'space', 'luggage', 'item', 'trip']),
        );
      },
    );
  });

  group('SyncService - fullPull tombstone propagation', () {
    Map<String, dynamic> houseJson(
      String id, {
      required DateTime updatedAt,
      DateTime? createdAt,
      bool isDeleted = false,
      String name = 'House',
    }) {
      return {
        'id': id,
        'user_id': null,
        'name': name,
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
        'created_at': (createdAt ?? updatedAt).toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted,
      };
    }

    Map<String, dynamic> itemJson(
      String id,
      String houseId, {
      required DateTime updatedAt,
      DateTime? createdAt,
      bool isDeleted = false,
      String? spaceId,
      String? aiMetadata,
    }) {
      return {
        'id': id,
        'user_id': null,
        'house_id': houseId,
        'name': 'Item',
        'category': 'varie',
        'description': null,
        'quantity': null,
        'space_id': spaceId,
        'created_at': (createdAt ?? updatedAt).toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted,
        'ai_metadata': aiMetadata,
      };
    }

    Map<String, dynamic> tripJson(
      String id, {
      required DateTime updatedAt,
      DateTime? createdAt,
      bool isDeleted = false,
    }) {
      return {
        'id': id,
        'user_id': null,
        'name': 'Trip',
        'description': null,
        'departure_date_time': null,
        'return_date_time': null,
        'destination_house_id': null,
        'location_place_id': null,
        'location_display_name': null,
        'location_name': null,
        'location_city': null,
        'location_state': null,
        'location_country': null,
        'location_type': null,
        'location_lat': null,
        'location_lon': null,
        'is_saved': false,
        'created_at': (createdAt ?? updatedAt).toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted,
      };
    }

    void stubFetchAll({
      List<Map<String, dynamic>> houses = const [],
      List<Map<String, dynamic>> spaces = const [],
      List<Map<String, dynamic>> luggages = const [],
      List<Map<String, dynamic>> items = const [],
      List<Map<String, dynamic>> trips = const [],
    }) {
      when(
        () => mockRemote.fetchAllHousesByUserId(any()),
      ).thenAnswer((_) async => houses);
      when(
        () => mockRemote.fetchAllSpacesByUserId(any()),
      ).thenAnswer((_) async => spaces);
      when(
        () => mockRemote.fetchAllLuggagesByUserId(any()),
      ).thenAnswer((_) async => luggages);
      when(
        () => mockRemote.fetchAllItemsByUserId(any()),
      ).thenAnswer((_) async => items);
      when(
        () => mockRemote.fetchAllTripsByUserId(any()),
      ).thenAnswer((_) async => trips);
    }

    test('soft-deletes local house when remote returns a tombstone', () async {
      final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();
      final t2 = DateTime(2026, 5, 1, 14, 0).toUtc();

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'h-1',
          name: 'House 1',
          createdAt: t1,
          updatedAt: t1,
          syncStatus: const Value(SyncStatus.synced),
        ),
      );

      stubFetchAll(
        houses: [
          houseJson('h-1', updatedAt: t2, createdAt: t1, isDeleted: true),
        ],
      );

      await syncService.fullPull('user-1');

      final house = await database.housesDao.findHouseById('h-1');
      expect(house, isNotNull);
      expect(house!.isDeleted, isTrue);
    });

    test('soft-deletes local item when remote returns a tombstone', () async {
      final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();
      final t2 = DateTime(2026, 5, 1, 14, 0).toUtc();

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'h-parent',
          name: 'House',
          createdAt: t1,
          updatedAt: t1,
          syncStatus: const Value(SyncStatus.synced),
        ),
      );
      await database.itemsDao.insertItem(
        ItemsCompanion.insert(
          id: 'i-1',
          houseId: 'h-parent',
          name: 'Item',
          category: ItemCategory.varie,
          createdAt: t1,
          updatedAt: t1,
          syncStatus: const Value(SyncStatus.synced),
        ),
      );

      stubFetchAll(
        items: [
          itemJson(
            'i-1',
            'h-parent',
            updatedAt: t2,
            createdAt: t1,
            isDeleted: true,
          ),
        ],
      );

      await syncService.fullPull('user-1');

      final item = await database.itemsDao.findItemById('i-1');
      expect(item, isNotNull);
      expect(item!.isDeleted, isTrue);
    });

    test('soft-deletes local trip when remote returns a tombstone', () async {
      final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();
      final t2 = DateTime(2026, 5, 1, 14, 0).toUtc();

      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: 't-1',
          name: 'Trip',
          createdAt: t1,
          updatedAt: t1,
          syncStatus: const Value(SyncStatus.synced),
        ),
      );

      stubFetchAll(
        trips: [tripJson('t-1', updatedAt: t2, createdAt: t1, isDeleted: true)],
      );

      await syncService.fullPull('user-1');

      final trip = await database.tripsDao.findTripById('t-1');
      expect(trip, isNotNull);
      expect(trip!.isDeleted, isTrue);
    });

    test('skips remote tombstone when no local record exists', () async {
      final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();

      stubFetchAll(
        houses: [houseJson('h-unknown', updatedAt: t1, isDeleted: true)],
      );

      await syncService.fullPull('user-1');

      final house = await database.housesDao.findHouseById('h-unknown');
      expect(house, isNull);
    });

    test(
      'keeps local alive when local is newer than remote tombstone',
      () async {
        final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();
        final t2 = DateTime(2026, 5, 1, 14, 0).toUtc();

        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: 'h-1',
            name: 'House 1',
            createdAt: t1,
            updatedAt: t2,
            syncStatus: const Value(SyncStatus.pendingUpdate),
          ),
        );

        stubFetchAll(
          houses: [houseJson('h-1', updatedAt: t1, isDeleted: true)],
        );

        await syncService.fullPull('user-1');

        final house = await database.housesDao.findHouseById('h-1');
        expect(house, isNotNull);
        expect(house!.isDeleted, isFalse);
      },
    );

    test('saves item with null spaceId when remote space_id is unknown', () async {
      final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();

      // Local: parent house, no spaces (mirror del bug: spaces non sincronizzati).
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'h-parent',
          name: 'House',
          createdAt: t1,
          updatedAt: t1,
          syncStatus: const Value(SyncStatus.synced),
        ),
      );

      stubFetchAll(
        items: [
          itemJson('i-1', 'h-parent', updatedAt: t1, spaceId: 'unknown-space'),
        ],
      );

      await syncService.fullPull('user-1');

      final item = await database.itemsDao.findItemById('i-1');
      expect(
        item,
        isNotNull,
        reason:
            'item must land in the general pool, not silently disappear on restore',
      );
      expect(item!.spaceId, isNull);
    });

    test('preserves spaceId when remote space_id exists locally', () async {
      final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'h-parent',
          name: 'House',
          createdAt: t1,
          updatedAt: t1,
          syncStatus: const Value(SyncStatus.synced),
        ),
      );
      await database.spacesDao.insertSpace(
        SpacesCompanion.insert(
          id: 'space-1',
          houseId: 'h-parent',
          name: 'Armadio',
          createdAt: t1,
          updatedAt: t1,
        ),
      );

      stubFetchAll(
        items: [itemJson('i-1', 'h-parent', updatedAt: t1, spaceId: 'space-1')],
      );

      await syncService.fullPull('user-1');

      final item = await database.itemsDao.findItemById('i-1');
      expect(item, isNotNull);
      expect(item!.spaceId, equals('space-1'));
    });

    test('fullPull preserves ai_metadata when remote includes it', () async {
      final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'h-parent',
          name: 'House',
          createdAt: t1,
          updatedAt: t1,
          syncStatus: const Value(SyncStatus.synced),
        ),
      );

      const expectedMetadata = '{"clothingType":"shirt","color":"blue"}';
      stubFetchAll(
        items: [
          itemJson(
            'i-1',
            'h-parent',
            updatedAt: t1,
            aiMetadata: expectedMetadata,
          ),
        ],
      );

      await syncService.fullPull('user-1');

      final item = await database.itemsDao.findItemById('i-1');
      expect(item, isNotNull);
      expect(
        item!.aiMetadata,
        equals(expectedMetadata),
        reason:
            'fullPull must carry over ai_metadata so AI-imported items keep '
            'their attribution after a restore',
      );
    });

    test(
      'updates local item with null spaceId when remote points to unknown space',
      () async {
        final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();
        final t2 = DateTime(2026, 5, 1, 14, 0).toUtc();

        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: 'h-parent',
            name: 'House',
            createdAt: t1,
            updatedAt: t1,
            syncStatus: const Value(SyncStatus.synced),
          ),
        );
        // Local has a space, and the item starts assigned to it.
        await database.spacesDao.insertSpace(
          SpacesCompanion.insert(
            id: 'space-local',
            houseId: 'h-parent',
            name: 'Armadio',
            createdAt: t1,
            updatedAt: t1,
          ),
        );
        await database.itemsDao.insertItem(
          ItemsCompanion.insert(
            id: 'i-1',
            houseId: 'h-parent',
            name: 'Item',
            category: ItemCategory.varie,
            createdAt: t1,
            updatedAt: t1,
            spaceId: const Value('space-local'),
            syncStatus: const Value(SyncStatus.synced),
          ),
        );

        // Remote update is newer and points to a space we don't know locally.
        stubFetchAll(
          items: [
            itemJson(
              'i-1',
              'h-parent',
              updatedAt: t2,
              spaceId: 'unknown-space',
            ),
          ],
        );

        await syncService.fullPull('user-1');

        final item = await database.itemsDao.findItemById('i-1');
        expect(item, isNotNull);
        expect(
          item!.spaceId,
          isNull,
          reason:
              'unknown remote space must land the item in the general pool, not block the update entirely',
        );
        // Sanity: the update went through (updatedAt reflects remote ts).
        expect(item.updatedAt.toUtc(), equals(t2));
      },
    );

    test('delete-wins: fullPull non risuscita una house locale soft-deleted '
        'anche se il remoto vivo è più recente', () async {
      await insertHouse('h-dw');
      await database.housesDao.deleteHouse(
        'h-dw',
      ); // soft-delete → pendingUpdate

      // Remoto VIVO con updated_at nel futuro (batte qualsiasi timestamp locale).
      final remoteNewer = DateTime.now().toUtc().add(const Duration(hours: 1));
      stubFetchAll(houses: [houseJson('h-dw', updatedAt: remoteNewer)]);

      await syncService.fullPull('user-1');

      final local = await database.housesDao.findHouseById('h-dw');
      expect(
        local!.isDeleted,
        isTrue,
        reason: 'delete-wins: il tombstone locale non va sovrascritto',
      );
      expect(
        local.syncStatus,
        isNot(equals(SyncStatus.synced)),
        reason: 'la cancellazione deve restare in coda per il push',
      );
    });

    test(
      'delete-wins: fullPull non risuscita un item locale soft-deleted',
      () async {
        await insertHouse('h-dw2');
        await insertItem('i-dw', 'h-dw2');
        await database.itemsDao.deleteItem(
          'i-dw',
        ); // soft-delete → pendingUpdate

        final remoteNewer = DateTime.now().toUtc().add(
          const Duration(hours: 1),
        );
        stubFetchAll(
          houses: [houseJson('h-dw2', updatedAt: DateTime(2026, 5, 1).toUtc())],
          items: [itemJson('i-dw', 'h-dw2', updatedAt: remoteNewer)],
        );

        await syncService.fullPull('user-1');

        final local = await database.itemsDao.findItemById('i-dw');
        expect(local!.isDeleted, isTrue);
        expect(local.syncStatus, isNot(equals(SyncStatus.synced)));
      },
    );

    test('un record house malformato non abortisce il fullPull', () async {
      final good = houseJson('h-good', updatedAt: DateTime(2026, 5, 1).toUtc());
      final bad = houseJson('h-bad', updatedAt: DateTime(2026, 5, 1).toUtc());
      bad['updated_at'] = 'not-a-date'; // parse failure

      // Il record corrotto arriva PRIMA di quello valido.
      stubFetchAll(houses: [bad, good]);

      await syncService.fullPull('user-1'); // non deve lanciare

      final goodLocal = await database.housesDao.findHouseById('h-good');
      expect(
        goodLocal,
        isNotNull,
        reason:
            'il record valido deve essere inserito nonostante il precedente corrotto',
      );

      verify(
        () => mockMonitoring.captureException(
          any(),
          stackTrace: any(named: 'stackTrace'),
          tags: any(named: 'tags'),
        ),
      ).called(greaterThanOrEqualTo(1));
    });
  });

  group('SyncService - trip items checklist sync', () {
    Map<String, dynamic> tripItemPayload(
      String id, {
      String name = 'Item',
      String category = 'vestiti',
      int quantity = 1,
      String originHouseId = '',
      bool isChecked = false,
    }) {
      return {
        'id': id,
        'name': name,
        'category': category,
        'quantity': quantity,
        'origin_house_id': originHouseId,
        'is_checked': isChecked,
      };
    }

    Map<String, dynamic> tripJsonWithItems(
      String id, {
      required DateTime updatedAt,
      DateTime? createdAt,
      List<Map<String, dynamic>>? items,
    }) {
      return {
        'id': id,
        'user_id': null,
        'name': 'Trip',
        'description': null,
        'departure_date_time': null,
        'return_date_time': null,
        'destination_house_id': null,
        'location_place_id': null,
        'location_display_name': null,
        'location_name': null,
        'location_city': null,
        'location_state': null,
        'location_country': null,
        'location_type': null,
        'location_lat': null,
        'location_lon': null,
        'is_saved': false,
        'created_at': (createdAt ?? updatedAt).toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': false,
        if (items != null) 'items': items,
      };
    }

    void stubEmptyFetches() {
      when(
        () => mockRemote.fetchAllHousesByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllSpacesByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllLuggagesByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllItemsByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllTripsByUserId(any()),
      ).thenAnswer((_) async => []);
    }

    test('fullPull restores trip items from remote payload', () async {
      final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();

      stubEmptyFetches();
      when(() => mockRemote.fetchAllTripsByUserId('user-1')).thenAnswer(
        (_) async => [
          tripJsonWithItems(
            't-1',
            updatedAt: t1,
            items: [
              tripItemPayload('ti-1', name: 'T-shirt', isChecked: true),
              tripItemPayload('ti-2', name: 'Pants', quantity: 2),
            ],
          ),
        ],
      );

      await syncService.fullPull('user-1');

      final entries = await database.tripsDao.getTripItemsByTripId('t-1');
      expect(entries, hasLength(2));
      final tshirt = entries.firstWhere((e) => e.id == 'ti-1');
      expect(tshirt.name, equals('T-shirt'));
      expect(tshirt.isChecked, isTrue);
      final pants = entries.firstWhere((e) => e.id == 'ti-2');
      expect(pants.name, equals('Pants'));
      expect(pants.quantity, equals(2));
      expect(pants.isChecked, isFalse);
    });

    test(
      'fullPull replaces local trip items when remote update arrives',
      () async {
        final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();
        final t2 = DateTime(2026, 5, 1, 14, 0).toUtc();

        // Local trip already has an item (snapshot of an earlier session).
        await database.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: 't-1',
            name: 'Trip',
            createdAt: t1,
            updatedAt: t1,
            syncStatus: const Value(SyncStatus.synced),
          ),
        );
        await database.tripsDao.insertTripItem(
          TripItemEntriesCompanion.insert(
            id: 'ti-old',
            tripId: 't-1',
            name: 'Old Item',
            category: ItemCategory.vestiti,
          ),
        );

        // Remote update brings a completely different set of items.
        stubEmptyFetches();
        when(() => mockRemote.fetchAllTripsByUserId('user-1')).thenAnswer(
          (_) async => [
            tripJsonWithItems(
              't-1',
              updatedAt: t2,
              items: [
                tripItemPayload('ti-new-1', name: 'New A', isChecked: true),
                tripItemPayload('ti-new-2', name: 'New B'),
              ],
            ),
          ],
        );

        await syncService.fullPull('user-1');

        final entries = await database.tripsDao.getTripItemsByTripId('t-1');
        final ids = entries.map((e) => e.id).toSet();
        expect(
          ids,
          equals({'ti-new-1', 'ti-new-2'}),
          reason: 'old local snapshot must be replaced by the remote items',
        );
        expect(entries.firstWhere((e) => e.id == 'ti-new-1').isChecked, isTrue);
      },
    );

    test(
      'processQueue serializes trip items into the pushed payload',
      () async {
        final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();

        await database.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: 'trip-push',
            name: 'Trip',
            createdAt: t1,
            updatedAt: t1,
          ),
        );
        await database.tripsDao.insertTripItem(
          TripItemEntriesCompanion.insert(
            id: 'ti-a',
            tripId: 'trip-push',
            name: 'Item A',
            category: ItemCategory.vestiti,
            quantity: const Value(2),
            isChecked: const Value(true),
          ),
        );
        await database.tripsDao.insertTripItem(
          TripItemEntriesCompanion.insert(
            id: 'ti-b',
            tripId: 'trip-push',
            name: 'Item B',
            category: ItemCategory.elettronica,
            originHouseId: const Value('h-origin'),
          ),
        );

        Map<String, dynamic>? capturedData;
        when(
          () => mockRemote.fetchTripById(
            'trip-push',
            sentryTrace: any(named: 'sentryTrace'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockRemote.upsertTrip(
            any(),
            sentryTrace: any(named: 'sentryTrace'),
          ),
        ).thenAnswer((invocation) async {
          capturedData =
              invocation.positionalArguments[0] as Map<String, dynamic>;
          return DateTime.utc(2026, 1, 1);
        });

        await syncService.processQueue();

        expect(capturedData, isNotNull, reason: 'upsertTrip must be called');
        final items = capturedData!['items'] as List<dynamic>?;
        expect(
          items,
          isNotNull,
          reason: 'trip payload must include items array',
        );
        expect(items, hasLength(2));
        final byId = <String, Map<dynamic, dynamic>>{
          for (final m in items!) (m as Map)['id'] as String: m,
        };
        expect(byId['ti-a']!['name'], equals('Item A'));
        expect(byId['ti-a']!['is_checked'], isTrue);
        expect(byId['ti-a']!['quantity'], equals(2));
        expect(byId['ti-a']!['category'], equals('vestiti'));
        expect(byId['ti-b']!['origin_house_id'], equals('h-origin'));
        expect(byId['ti-b']!['is_checked'], isFalse);
      },
    );
  });

  group('SyncService - account lifecycle', () {
    test(
      'wipeAllUserData clears all local entities (houses → trip entries)',
      () async {
        final now = DateTime.now();
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: 'h-wipe',
            name: 'House',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await database.spacesDao.insertSpace(
          SpacesCompanion.insert(
            id: 's-wipe',
            houseId: 'h-wipe',
            name: 'Armadio',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await database.luggagesDao.insertLuggage(
          LuggagesCompanion.insert(
            id: 'l-wipe',
            houseId: 'h-wipe',
            name: 'Zaino',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await database.itemsDao.insertItem(
          ItemsCompanion.insert(
            id: 'i-wipe',
            houseId: 'h-wipe',
            name: 'Item',
            category: ItemCategory.varie,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await database.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: 't-wipe',
            name: 'Trip',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await syncService.wipeAllUserData();

        expect(await database.select(database.houses).get(), isEmpty);
        expect(await database.select(database.spaces).get(), isEmpty);
        expect(await database.select(database.luggages).get(), isEmpty);
        expect(await database.select(database.items).get(), isEmpty);
        expect(await database.select(database.trips).get(), isEmpty);
        expect(
          await database.select(database.tripItemEntries).get(),
          isEmpty,
          reason: 'cascade must purge snapshots too',
        );
      },
    );

    test(
      'countPendingChanges sums pending records across all entities',
      () async {
        final now = DateTime.now();
        // 1 house pendingCreate (default)
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: 'h-pending',
            name: 'House',
            createdAt: now,
            updatedAt: now,
          ),
        );
        // 1 trip pendingCreate (default)
        await database.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: 't-pending',
            name: 'Trip',
            createdAt: now,
            updatedAt: now,
          ),
        );
        // 1 item synced → NOT pending
        await database.itemsDao.insertItem(
          ItemsCompanion.insert(
            id: 'i-synced',
            houseId: 'h-pending',
            name: 'Item',
            category: ItemCategory.varie,
            createdAt: now,
            updatedAt: now,
            syncStatus: const Value(SyncStatus.synced),
          ),
        );

        final count = await syncService.countPendingChanges();
        expect(
          count,
          equals(2),
          reason:
              'should count house + trip (pendingCreate), not the synced item',
        );
      },
    );
  });

  group('SyncService - spaces sync', () {
    Map<String, dynamic> spaceJson(
      String id,
      String houseId, {
      required DateTime updatedAt,
      DateTime? createdAt,
      bool isDeleted = false,
      String name = 'Armadio',
      String? iconName,
    }) {
      return {
        'id': id,
        'user_id': null,
        'house_id': houseId,
        'name': name,
        'icon_name': iconName,
        'created_at': (createdAt ?? updatedAt).toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted,
      };
    }

    void stubEmptyFetches() {
      when(
        () => mockRemote.fetchAllHousesByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllSpacesByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllLuggagesByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllItemsByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllTripsByUserId(any()),
      ).thenAnswer((_) async => []);
    }

    test('processQueue pushes a pending space', () async {
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'h-parent',
          name: 'House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          syncStatus: const Value(SyncStatus.synced),
        ),
      );
      await database.spacesDao.insertSpace(
        SpacesCompanion.insert(
          id: 's-push',
          houseId: 'h-parent',
          name: 'Armadio Camera',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      Map<String, dynamic>? capturedData;
      when(
        () => mockRemote.fetchSpaceById(
          's-push',
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockRemote.upsertSpace(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((invocation) async {
        capturedData =
            invocation.positionalArguments[0] as Map<String, dynamic>;
        return DateTime.utc(2026, 1, 1);
      });

      await syncService.processQueue();

      expect(capturedData, isNotNull, reason: 'upsertSpace must be called');
      expect(capturedData!['id'], equals('s-push'));
      expect(capturedData!['house_id'], equals('h-parent'));
      expect(capturedData!['name'], equals('Armadio Camera'));

      final localSpace = await database.spacesDao.getSpaceById('s-push');
      expect(localSpace, isNotNull);
    });

    test('fullPull restores a space from remote', () async {
      final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'h-parent',
          name: 'House',
          createdAt: t1,
          updatedAt: t1,
          syncStatus: const Value(SyncStatus.synced),
        ),
      );

      stubEmptyFetches();
      when(() => mockRemote.fetchAllSpacesByUserId('user-1')).thenAnswer(
        (_) async => [
          spaceJson(
            's-1',
            'h-parent',
            updatedAt: t1,
            name: 'Garage',
            iconName: 'garage',
          ),
        ],
      );

      await syncService.fullPull('user-1');

      final space = await database.spacesDao.getSpaceById('s-1');
      expect(space, isNotNull, reason: 'remote space must be inserted locally');
      expect(space!.name, equals('Garage'));
      expect(space.iconName, equals('garage'));
      expect(space.houseId, equals('h-parent'));
    });

    test(
      'fullPull soft-deletes local space when remote returns a tombstone',
      () async {
        final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();
        final t2 = DateTime(2026, 5, 1, 14, 0).toUtc();

        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: 'h-parent',
            name: 'House',
            createdAt: t1,
            updatedAt: t1,
            syncStatus: const Value(SyncStatus.synced),
          ),
        );
        await database.spacesDao.insertSpace(
          SpacesCompanion.insert(
            id: 's-1',
            houseId: 'h-parent',
            name: 'Armadio',
            createdAt: t1,
            updatedAt: t1,
            syncStatus: const Value(SyncStatus.synced),
          ),
        );

        stubEmptyFetches();
        when(() => mockRemote.fetchAllSpacesByUserId('user-1')).thenAnswer(
          (_) async => [
            spaceJson('s-1', 'h-parent', updatedAt: t2, isDeleted: true),
          ],
        );

        await syncService.fullPull('user-1');

        // Soft-deleted: invisible to getSpaceById but still present in DB.
        final visible = await database.spacesDao.getSpaceById('s-1');
        expect(visible, isNull);
        final all = await database.select(database.spaces).get();
        expect(all, hasLength(1));
        expect(all.first.isDeleted, isTrue);
      },
    );
  });

  group('SyncService - luggages sync', () {
    Map<String, dynamic> luggageJson(
      String id,
      String houseId, {
      required DateTime updatedAt,
      DateTime? createdAt,
      bool isDeleted = false,
      String name = 'Zaino',
      String sizeType = 'cabinBaggage',
      int? volumeLiters,
    }) {
      return {
        'id': id,
        'user_id': null,
        'house_id': houseId,
        'name': name,
        'size_type': sizeType,
        'volume_liters': volumeLiters,
        'created_at': (createdAt ?? updatedAt).toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted,
      };
    }

    void stubEmptyFetches() {
      when(
        () => mockRemote.fetchAllHousesByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllSpacesByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllLuggagesByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllItemsByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllTripsByUserId(any()),
      ).thenAnswer((_) async => []);
    }

    test('processQueue pushes a pending luggage', () async {
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'h-parent',
          name: 'House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          syncStatus: const Value(SyncStatus.synced),
        ),
      );
      await database.luggagesDao.insertLuggage(
        LuggagesCompanion.insert(
          id: 'l-push',
          houseId: 'h-parent',
          name: 'Valigia Grande',
          sizeType: LuggageSize.holdBaggage,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      Map<String, dynamic>? capturedData;
      when(
        () => mockRemote.fetchLuggageById(
          'l-push',
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockRemote.upsertLuggage(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((invocation) async {
        capturedData =
            invocation.positionalArguments[0] as Map<String, dynamic>;
        return DateTime.utc(2026, 1, 1);
      });

      await syncService.processQueue();

      expect(capturedData, isNotNull, reason: 'upsertLuggage must be called');
      expect(capturedData!['id'], equals('l-push'));
      expect(capturedData!['house_id'], equals('h-parent'));
      expect(capturedData!['name'], equals('Valigia Grande'));
      expect(capturedData!['size_type'], equals('holdBaggage'));
    });

    test('fullPull restores a luggage from remote', () async {
      final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();

      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'h-parent',
          name: 'House',
          createdAt: t1,
          updatedAt: t1,
          syncStatus: const Value(SyncStatus.synced),
        ),
      );

      stubEmptyFetches();
      when(() => mockRemote.fetchAllLuggagesByUserId('user-1')).thenAnswer(
        (_) async => [
          luggageJson(
            'l-1',
            'h-parent',
            updatedAt: t1,
            name: 'Trolley',
            sizeType: 'holdBaggage',
            volumeLiters: 80,
          ),
        ],
      );

      await syncService.fullPull('user-1');

      final luggage = await database.luggagesDao.getLuggageById('l-1');
      expect(
        luggage,
        isNotNull,
        reason: 'remote luggage must be inserted locally',
      );
      expect(luggage!.name, equals('Trolley'));
      expect(luggage.sizeType, equals(LuggageSize.holdBaggage));
      expect(luggage.volumeLiters, equals(80));
    });

    test(
      'fullPull soft-deletes local luggage when remote returns a tombstone',
      () async {
        final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();
        final t2 = DateTime(2026, 5, 1, 14, 0).toUtc();

        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: 'h-parent',
            name: 'House',
            createdAt: t1,
            updatedAt: t1,
            syncStatus: const Value(SyncStatus.synced),
          ),
        );
        await database.luggagesDao.insertLuggage(
          LuggagesCompanion.insert(
            id: 'l-1',
            houseId: 'h-parent',
            name: 'Zaino',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: t1,
            updatedAt: t1,
            syncStatus: const Value(SyncStatus.synced),
          ),
        );

        stubEmptyFetches();
        when(() => mockRemote.fetchAllLuggagesByUserId('user-1')).thenAnswer(
          (_) async => [
            luggageJson('l-1', 'h-parent', updatedAt: t2, isDeleted: true),
          ],
        );

        await syncService.fullPull('user-1');

        final visible = await database.luggagesDao.getLuggageById('l-1');
        expect(visible, isNull);
        final all = await database.select(database.luggages).get();
        expect(all, hasLength(1));
        expect(all.first.isDeleted, isTrue);
      },
    );
  });

  group('SyncService - analytics sui fallimenti', () {
    test(
      'trackSyncFailed emesso quando il push di un record fallisce',
      () async {
        final mockAnalytics = MockCoreAnalyticsService();
        final serviceWithAnalytics = SyncService(
          housesDao: database.housesDao,
          itemsDao: database.itemsDao,
          spacesDao: database.spacesDao,
          luggagesDao: database.luggagesDao,
          tripsDao: database.tripsDao,
          remote: mockRemote,
          monitoring: mockMonitoring,
          tombstoneConfig: mockTombstoneConfig,
          analytics: mockAnalytics,
        );

        await insertHouse('h-fail');
        when(
          () => mockRemote.fetchHouseById(
            'h-fail',
            sentryTrace: any(named: 'sentryTrace'),
          ),
        ).thenThrow(Exception('network down'));

        await serviceWithAnalytics.processQueue();

        verify(
          () => mockAnalytics.trackSyncFailed(
            entity: 'house',
            errorType: any(named: 'errorType'),
          ),
        ).called(1);
      },
    );
  });

  group('SyncService - trip luggages sync', () {
    void stubEmptyFetches() {
      when(
        () => mockRemote.fetchAllHousesByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllSpacesByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllLuggagesByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllItemsByUserId(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRemote.fetchAllTripsByUserId(any()),
      ).thenAnswer((_) async => []);
    }

    test(
      'processQueue serializes luggage_ids in the pushed trip payload',
      () async {
        // Setup: trip linked to one luggage via junction.
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: 'h-parent',
            name: 'House',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            syncStatus: const Value(SyncStatus.synced),
          ),
        );
        await database.luggagesDao.insertLuggage(
          LuggagesCompanion.insert(
            id: 'l-a',
            houseId: 'h-parent',
            name: 'Zaino',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            syncStatus: const Value(SyncStatus.synced),
          ),
        );
        await database.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: 'trip-push',
            name: 'Trip',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await database.luggagesDao.linkLuggageToTrip('trip-push', 'l-a');

        Map<String, dynamic>? capturedData;
        when(
          () => mockRemote.fetchTripById(
            'trip-push',
            sentryTrace: any(named: 'sentryTrace'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockRemote.upsertTrip(
            any(),
            sentryTrace: any(named: 'sentryTrace'),
          ),
        ).thenAnswer((invocation) async {
          capturedData =
              invocation.positionalArguments[0] as Map<String, dynamic>;
          return DateTime.utc(2026, 1, 1);
        });

        await syncService.processQueue();

        expect(capturedData, isNotNull, reason: 'upsertTrip must be called');
        final luggageIds = capturedData!['luggage_ids'] as List<dynamic>?;
        expect(
          luggageIds,
          isNotNull,
          reason: 'trip payload must include luggage_ids',
        );
        expect(luggageIds, contains('l-a'));
      },
    );

    test(
      'fullPull restores trip↔luggage junction from remote luggage_ids',
      () async {
        final t1 = DateTime(2026, 5, 1, 8, 0).toUtc();

        // Local has the house and the luggage that will be referenced.
        await database.housesDao.insertHouse(
          HousesCompanion.insert(
            id: 'h-parent',
            name: 'House',
            createdAt: t1,
            updatedAt: t1,
            syncStatus: const Value(SyncStatus.synced),
          ),
        );
        await database.luggagesDao.insertLuggage(
          LuggagesCompanion.insert(
            id: 'l-a',
            houseId: 'h-parent',
            name: 'Zaino',
            sizeType: LuggageSize.cabinBaggage,
            createdAt: t1,
            updatedAt: t1,
            syncStatus: const Value(SyncStatus.synced),
          ),
        );

        stubEmptyFetches();
        when(() => mockRemote.fetchAllTripsByUserId('user-1')).thenAnswer(
          (_) async => [
            {
              'id': 't-1',
              'user_id': null,
              'name': 'Trip',
              'description': null,
              'departure_date_time': null,
              'return_date_time': null,
              'destination_house_id': null,
              'location_place_id': null,
              'location_display_name': null,
              'location_name': null,
              'location_city': null,
              'location_state': null,
              'location_country': null,
              'location_type': null,
              'location_lat': null,
              'location_lon': null,
              'is_saved': false,
              'created_at': t1.toIso8601String(),
              'updated_at': t1.toIso8601String(),
              'is_deleted': false,
              'luggage_ids': ['l-a'],
            },
          ],
        );

        await syncService.fullPull('user-1');

        // The junction should be populated and querying luggages by trip
        // should return the linked luggage.
        final luggagesForTrip = await database.luggagesDao.getLuggagesByTrip(
          't-1',
        );
        expect(luggagesForTrip, hasLength(1));
        expect(luggagesForTrip.first.id, equals('l-a'));
      },
    );
  });

  group('SyncService.getUnsyncedBreakdown', () {
    test('returns empty list when nothing is pending', () async {
      final breakdown = await syncService.getUnsyncedBreakdown();
      expect(breakdown, isEmpty);
    });

    test(
      'groups pending records by entity type with count and reason',
      () async {
        await insertHouse('house-1');
        // A second house is pendingCreate by default (see insertHouse helper) —
        // insert one more record to exercise a count > 1 for one entity type.
        await insertHouse('house-2');

        // insertHouse leaves syncStatus at its default (pendingCreate) with no
        // lastSyncError yet (never attempted) — exercise the "unknown/generic"
        // reason path first.
        final breakdown = await syncService.getUnsyncedBreakdown();

        expect(breakdown.length, 1);
        expect(breakdown.single.entityLabelKey, 'houses.title');
        expect(breakdown.single.count, 2);
        expect(breakdown.single.reasonKey, 'profile.sync_reason_unknown');
      },
    );

    test('reflects a friendly reason once a sync attempt has failed', () async {
      await insertHouse('house-1');
      await database.housesDao.incrementSyncRetry(
        'house-1',
        'SocketException: Failed host lookup: api.supabase.co',
      );
      // incrementSyncRetry schedules a real exponential-backoff window
      // (nextSyncAttemptAt = now + 2s for the first failure), which
      // getPendingSyncRecords() — reused as-is by getUnsyncedBreakdown() —
      // filters out until it elapses. Clear it directly here to simulate
      // "the backoff window has already elapsed": this test is about the
      // reason-mapping surfaced in the breakdown, not backoff timing
      // (already covered by houses_dao_test.dart).
      await (database.update(database.houses)
            ..where((h) => h.id.equals('house-1')))
          .write(const HousesCompanion(nextSyncAttemptAt: Value(null)));

      final breakdown = await syncService.getUnsyncedBreakdown();

      expect(breakdown.single.reasonKey, 'profile.sync_reason_network');
    });

    test(
      'only includes entity types that actually have pending records',
      () async {
        await insertHouse('house-1');
        // No items/spaces/luggages/trips inserted — they must not appear.

        final breakdown = await syncService.getUnsyncedBreakdown();

        expect(breakdown.length, 1);
        expect(breakdown.single.entityLabelKey, 'houses.title');
      },
    );
  });
}

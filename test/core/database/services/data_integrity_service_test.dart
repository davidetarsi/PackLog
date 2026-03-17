import 'package:flutter_test/flutter_test.dart';
import 'package:stuff_tracker_2/core/database/database.dart';
import 'package:stuff_tracker_2/core/database/services/data_integrity_service.dart';
import '../../../helpers/test_database_setup.dart';

/// Unit tests for DataIntegrityService.
/// 
/// Tests the integrity checking and auto-repair mechanisms for:
/// - Orphan items (items without valid house reference)
/// - Orphan trip items (trip items without valid trip reference)
/// - Invalid destination houses (trips referencing non-existent houses)
/// - Data consistency checks
void main() {
  late AppDatabase database;
  late DataIntegrityService integrityService;

  setUp(() {
    database = createTestDatabase();
    integrityService = DataIntegrityService(database);
  });

  tearDown(() async {
    await closeTestDatabase(database);
  });

  group('DataIntegrityService - Orphan Items Detection & Auto-Fix', () {
    test('should detect orphan item when house does not exist', () async {
      // === ARRANGE ===
      // Simulate corrupted state: insert an item without a valid house.
      // Since foreign keys are enabled by default, we must temporarily disable them.
      
      // Step 1: Disable foreign keys to allow orphan item insertion
      await database.customStatement('PRAGMA foreign_keys = OFF');

      // Step 2: Insert an orphan item directly via raw SQL
      // This item references a non-existent house_id
      final now = DateTime.now().millisecondsSinceEpoch;
      await database.customStatement(
        '''
        INSERT INTO items (id, house_id, name, category, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [
          'orphan-item-1',
          'non-existent-house-id', // This house does NOT exist
          'Orphan Item',
          'varie',
          now,
          now,
        ],
      );

      // Step 3: Re-enable foreign keys (restore normal behavior)
      await database.customStatement('PRAGMA foreign_keys = ON');

      // Verify the orphan item was inserted
      final allItems = await database.itemsDao.getAllItems();
      expect(allItems, hasLength(1));
      expect(allItems.first.id, equals('orphan-item-1'));
      expect(allItems.first.houseId, equals('non-existent-house-id'));

      // === ACT ===
      // Run integrity check to detect the orphan item
      final checkResult = await integrityService.runFullCheck();

      // === ASSERT ===
      // Verify that the orphan item was detected
      expect(checkResult.isHealthy, isFalse);
      expect(checkResult.issueCount, equals(1));
      expect(checkResult.issues.first.type, equals(IntegrityIssueType.orphanItem));
      expect(checkResult.issues.first.table, equals('items'));
      expect(checkResult.issues.first.recordId, equals('orphan-item-1'));
      expect(checkResult.issues.first.canAutoFix, isTrue);
      expect(
        checkResult.issues.first.description,
        contains('Orphan Item'),
      );
      expect(
        checkResult.issues.first.description,
        contains('non-existent-house-id'),
      );
    });

    test('should auto-fix orphan item by deleting it', () async {
      // === ARRANGE ===
      // Create corrupted state: orphan item without valid house
      
      await database.customStatement('PRAGMA foreign_keys = OFF');

      final now = DateTime.now().millisecondsSinceEpoch;
      await database.customStatement(
        '''
        INSERT INTO items (id, house_id, name, category, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [
          'orphan-item-1',
          'ghost-house-id',
          'Ghost Item',
          'elettronica',
          now,
          now,
        ],
      );

      await database.customStatement('PRAGMA foreign_keys = ON');

      // Verify orphan exists
      var allItems = await database.itemsDao.getAllItems();
      expect(allItems, hasLength(1));

      // === ACT ===
      // Step 1: Detect the issue
      final checkResult = await integrityService.runFullCheck();
      expect(checkResult.issueCount, equals(1));

      // Step 2: Apply auto-fix
      final fixedCount = await integrityService.autoFix(checkResult);

      // === ASSERT ===
      // Verify auto-fix was successful
      expect(fixedCount, equals(1));

      // Verify the orphan item was deleted from the database
      allItems = await database.itemsDao.getAllItems();
      expect(allItems, isEmpty);
    });

    test('should not detect valid items as orphans', () async {
      // === ARRANGE ===
      // Create valid state: house with items
      
      final houseCompanion = HousesCompanion.insert(
        id: 'valid-house',
        name: 'Valid House',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await database.housesDao.insertHouse(houseCompanion);

      final itemCompanion = ItemsCompanion.insert(
        id: 'valid-item',
        houseId: 'valid-house',
        name: 'Valid Item',
        category: 'vestiti',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await database.itemsDao.insertItem(itemCompanion);

      // === ACT ===
      final checkResult = await integrityService.runFullCheck();

      // === ASSERT ===
      // No issues should be detected
      expect(checkResult.isHealthy, isTrue);
      expect(checkResult.issueCount, equals(0));
      expect(checkResult.fixableIssueCount, equals(0));

      // Item should still exist
      final items = await database.itemsDao.getAllItems();
      expect(items, hasLength(1));
    });

    test('should handle multiple orphan items', () async {
      // === ARRANGE ===
      // Create multiple orphan items
      
      await database.customStatement('PRAGMA foreign_keys = OFF');

      final now = DateTime.now().millisecondsSinceEpoch;
      for (int i = 1; i <= 3; i++) {
        await database.customStatement(
          '''
          INSERT INTO items (id, house_id, name, category, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?)
          ''',
          [
            'orphan-item-$i',
            'fake-house-$i',
            'Orphan Item $i',
            'varie',
            now,
            now,
          ],
        );
      }

      await database.customStatement('PRAGMA foreign_keys = ON');

      // Verify all 3 orphans exist
      var allItems = await database.itemsDao.getAllItems();
      expect(allItems, hasLength(3));

      // === ACT ===
      final checkResult = await integrityService.runFullCheck();
      final fixedCount = await integrityService.autoFix(checkResult);

      // === ASSERT ===
      expect(checkResult.issueCount, equals(3));
      expect(fixedCount, equals(3));

      // All orphans should be deleted
      allItems = await database.itemsDao.getAllItems();
      expect(allItems, isEmpty);
    });

    test('should detect mixed valid and orphan items', () async {
      // === ARRANGE ===
      // Create a mix of valid items and orphan items
      
      // Valid house with valid item
      final houseCompanion = HousesCompanion.insert(
        id: 'valid-house',
        name: 'Valid House',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await database.housesDao.insertHouse(houseCompanion);

      final validItemCompanion = ItemsCompanion.insert(
        id: 'valid-item',
        houseId: 'valid-house',
        name: 'Valid Item',
        category: 'vestiti',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await database.itemsDao.insertItem(validItemCompanion);

      // Orphan item without valid house
      await database.customStatement('PRAGMA foreign_keys = OFF');

      final now = DateTime.now().millisecondsSinceEpoch;
      await database.customStatement(
        '''
        INSERT INTO items (id, house_id, name, category, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [
          'orphan-item',
          'non-existent-house',
          'Orphan Item',
          'elettronica',
          now,
          now,
        ],
      );

      await database.customStatement('PRAGMA foreign_keys = ON');

      // Verify both items exist
      var allItems = await database.itemsDao.getAllItems();
      expect(allItems, hasLength(2));

      // === ACT ===
      final checkResult = await integrityService.runFullCheck();
      final fixedCount = await integrityService.autoFix(checkResult);

      // === ASSERT ===
      // Only 1 issue (the orphan)
      expect(checkResult.issueCount, equals(1));
      expect(checkResult.issues.first.recordId, equals('orphan-item'));
      expect(fixedCount, equals(1));

      // Only the valid item should remain
      allItems = await database.itemsDao.getAllItems();
      expect(allItems, hasLength(1));
      expect(allItems.first.id, equals('valid-item'));
    });
  });

  group('DataIntegrityService - Orphan Trip Items', () {
    test('should detect and auto-fix orphan trip items', () async {
      // === ARRANGE ===
      // Create orphan trip item (trip_item_entry without valid trip)
      
      await database.customStatement('PRAGMA foreign_keys = OFF');

      await database.customStatement(
        '''
        INSERT INTO trip_item_entries (id, trip_id, name, category, quantity, origin_house_id, is_checked)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'orphan-trip-item',
          'non-existent-trip-id',
          'Orphan Trip Item',
          'toiletries',
          1,
          '',
          0,
        ],
      );

      await database.customStatement('PRAGMA foreign_keys = ON');

      // Verify orphan trip item exists
      final tripItems = await database.tripsDao.getTripItemsByTripId('non-existent-trip-id');
      expect(tripItems, hasLength(1));

      // === ACT ===
      final checkResult = await integrityService.runFullCheck();
      final fixedCount = await integrityService.autoFix(checkResult);

      // === ASSERT ===
      expect(checkResult.issueCount, equals(1));
      expect(checkResult.issues.first.type, equals(IntegrityIssueType.orphanTripItem));
      expect(checkResult.issues.first.table, equals('trip_item_entries'));
      expect(checkResult.issues.first.canAutoFix, isTrue);
      expect(fixedCount, equals(1));

      // Orphan trip item should be deleted
      final tripItemsAfterFix = await database.tripsDao.getTripItemsByTripId('non-existent-trip-id');
      expect(tripItemsAfterFix, isEmpty);
    });
  });

  group('DataIntegrityService - Invalid Destination Houses', () {
    test('should detect and auto-fix trips with invalid destination house', () async {
      // === ARRANGE ===
      // Create a trip with non-existent destination house
      
      await database.customStatement('PRAGMA foreign_keys = OFF');

      final now = DateTime.now().millisecondsSinceEpoch;
      await database.customStatement(
        '''
        INSERT INTO trips (id, name, destination_house_id, is_saved, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [
          'trip-1',
          'Trip to Nowhere',
          'non-existent-destination', // Invalid house reference
          0,
          now,
          now,
        ],
      );

      await database.customStatement('PRAGMA foreign_keys = ON');

      // Verify trip exists with invalid destination
      final trips = await database.tripsDao.getAllTrips();
      expect(trips, hasLength(1));
      expect(trips.first.destinationHouseId, equals('non-existent-destination'));

      // === ACT ===
      final checkResult = await integrityService.runFullCheck();
      final fixedCount = await integrityService.autoFix(checkResult);

      // === ASSERT ===
      expect(checkResult.issueCount, equals(1));
      expect(checkResult.issues.first.type, equals(IntegrityIssueType.invalidDestinationHouse));
      expect(checkResult.issues.first.canAutoFix, isTrue);
      expect(fixedCount, equals(1));

      // Trip should still exist, but with NULL destination_house_id
      final tripsAfterFix = await database.tripsDao.getAllTrips();
      expect(tripsAfterFix, hasLength(1));
      expect(tripsAfterFix.first.destinationHouseId, equals(null));
    });
  });

  group('DataIntegrityService - Healthy Database', () {
    test('should report healthy when no issues exist', () async {
      // === ARRANGE ===
      // Create valid data structure
      
      final houseCompanion = HousesCompanion.insert(
        id: 'house-1',
        name: 'Valid House',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await database.housesDao.insertHouse(houseCompanion);

      final itemCompanion = ItemsCompanion.insert(
        id: 'item-1',
        houseId: 'house-1',
        name: 'Valid Item',
        category: 'vestiti',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await database.itemsDao.insertItem(itemCompanion);

      final tripCompanion = TripsCompanion.insert(
        id: 'trip-1',
        name: 'Valid Trip',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await database.tripsDao.insertTrip(tripCompanion);

      // === ACT ===
      final checkResult = await integrityService.runFullCheck();

      // === ASSERT ===
      expect(checkResult.isHealthy, isTrue);
      expect(checkResult.issueCount, equals(0));
      expect(checkResult.fixableIssueCount, equals(0));
      expect(checkResult.issues, isEmpty);
    });

    test('should complete check within reasonable time', () async {
      // === ARRANGE ===
      // Create some data
      
      final houseCompanion = HousesCompanion.insert(
        id: 'house-1',
        name: 'Test House',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await database.housesDao.insertHouse(houseCompanion);

      // === ACT ===
      final checkResult = await integrityService.runFullCheck();

      // === ASSERT ===
      // Check should complete in under 1 second for small datasets
      expect(checkResult.duration.inMilliseconds, lessThan(1000));
      expect(checkResult.checkedAt, isA<DateTime>());
    });
  });

  group('DataIntegrityService - Quick Check', () {
    test('should pass quick check on valid database', () async {
      // === ARRANGE ===
      // Empty database is valid
      
      // === ACT ===
      final isHealthy = await integrityService.quickCheck();

      // === ASSERT ===
      expect(isHealthy, isTrue);
    });

    test('should pass quick check with data', () async {
      // === ARRANGE ===
      final houseCompanion = HousesCompanion.insert(
        id: 'house-1',
        name: 'Test House',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await database.housesDao.insertHouse(houseCompanion);

      // === ACT ===
      final isHealthy = await integrityService.quickCheck();

      // === ASSERT ===
      expect(isHealthy, isTrue);
    });
  });

  group('DataIntegrityService - Complex Scenarios', () {
    test('should handle multiple issue types simultaneously', () async {
      // === ARRANGE ===
      // Create multiple types of integrity issues
      
      // Valid house
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'valid-house',
          name: 'Valid House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await database.customStatement('PRAGMA foreign_keys = OFF');

      final now = DateTime.now().millisecondsSinceEpoch;
      // Issue 1: Orphan item
      await database.customStatement(
        '''
        INSERT INTO items (id, house_id, name, category, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [
          'orphan-item',
          'fake-house',
          'Orphan Item',
          'varie',
          now,
          now,
        ],
      );

      // Issue 2: Orphan trip item
      await database.customStatement(
        '''
        INSERT INTO trip_item_entries (id, trip_id, name, category, quantity, origin_house_id, is_checked)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'orphan-trip-item',
          'fake-trip',
          'Orphan Trip Item',
          'varie',
          1,
          '',
          0,
        ],
      );

      // Issue 3: Trip with invalid destination
      final now2 = DateTime.now().millisecondsSinceEpoch;
      await database.customStatement(
        '''
        INSERT INTO trips (id, name, destination_house_id, is_saved, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [
          'trip-with-bad-dest',
          'Bad Trip',
          'fake-destination-house',
          0,
          now2,
          now2,
        ],
      );

      await database.customStatement('PRAGMA foreign_keys = ON');

      // === ACT ===
      final checkResult = await integrityService.runFullCheck();
      final fixedCount = await integrityService.autoFix(checkResult);

      // === ASSERT ===
      // Should detect all 3 issues
      expect(checkResult.issueCount, equals(3));
      expect(checkResult.fixableIssueCount, equals(3));

      // Should fix all 3 issues
      expect(fixedCount, equals(3));

      // Verify cleanup
      final items = await database.itemsDao.getAllItems();
      expect(items, isEmpty); // Orphan item deleted

      final tripItems = await database.tripsDao.getTripItemsByTripId('fake-trip');
      expect(tripItems, isEmpty); // Orphan trip item deleted

      final trips = await database.tripsDao.getAllTrips();
      expect(trips, hasLength(1));
      expect(trips.first.destinationHouseId, equals(null)); // Invalid FK set to NULL
    });

    test('should report issue types correctly', () async {
      // === ARRANGE ===
      await database.customStatement('PRAGMA foreign_keys = OFF');

      final now = DateTime.now().millisecondsSinceEpoch;
      await database.customStatement(
        '''
        INSERT INTO items (id, house_id, name, category, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [
          'orphan-item',
          'fake-house',
          'Orphan Item',
          'varie',
          now,
          now,
        ],
      );

      await database.customStatement('PRAGMA foreign_keys = ON');

      // === ACT ===
      final checkResult = await integrityService.runFullCheck();

      // === ASSERT ===
      final issue = checkResult.issues.first;
      expect(issue.type, equals(IntegrityIssueType.orphanItem));
      expect(issue.table, equals('items'));
      expect(issue.recordId, isA<String>());
      expect(issue.description, isA<String>());
      expect(issue.canAutoFix, isTrue);
      expect(issue.toString(), contains('[IntegrityIssueType.orphanItem]'));
    });
  });
}

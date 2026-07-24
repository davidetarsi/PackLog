import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/sync/sync_serializers.dart';
import '../../helpers/test_database_setup.dart';

/// Unit tests for SyncSerializers.
///
/// Tests the JSON payload built for pushing entities to Supabase, focusing
/// on the house `name` fallback that prevents an empty string from ever
/// reaching Supabase (which rejects it via the `houses_name_check`
/// CHECK constraint: `char_length(name) >= 1`), even though the local
/// schema allows an empty name (city/location shown as fallback in UI).
void main() {
  late AppDatabase database;

  setUp(() {
    database = createTestDatabase();
  });

  tearDown(() async {
    await closeTestDatabase(database);
  });

  Future<House> insertAndFetchHouse(HousesCompanion companion) async {
    await database.housesDao.insertHouse(companion);
    return (await database.housesDao.getHouseById(companion.id.value))!;
  }

  group('SyncSerializers.houseToJson - name fallback', () {
    test('keeps the real name when it is non-empty', () async {
      final house = await insertAndFetchHouse(
        HousesCompanion.insert(
          id: 'house-1',
          name: 'Villa Bella',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );

      final json = SyncSerializers.houseToJson(house);

      expect(json['name'], 'Villa Bella');
    });

    test('falls back to locationCity when name is empty', () async {
      final house = await insertAndFetchHouse(
        HousesCompanion.insert(
          id: 'house-2',
          name: '',
          locationCity: const Value('Milano'),
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );

      final json = SyncSerializers.houseToJson(house);

      expect(json['name'], 'Milano');
    });

    test(
      'falls back to locationDisplayName when name and locationCity are empty/null',
      () async {
        final house = await insertAndFetchHouse(
          HousesCompanion.insert(
            id: 'house-3',
            name: '',
            locationDisplayName: const Value('Via Roma 1, Milano'),
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        );

        final json = SyncSerializers.houseToJson(house);

        expect(json['name'], 'Via Roma 1, Milano');
      },
    );

    test(
      'never sends an empty string when name, city, and location are all empty/null — '
      'this is the exact case that made houses_name_check reject the push in production',
      () async {
        final house = await insertAndFetchHouse(
          HousesCompanion.insert(
            id: 'house-4',
            name: '',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        );

        final json = SyncSerializers.houseToJson(house);

        expect(json['name'], isNotEmpty);
        expect(json['name'], isNot(''));
      },
    );
  });
}

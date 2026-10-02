import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/sync/sync_serializers.dart';
import '../../helpers/test_database_setup.dart';

/// Sentinella per distinguere "chiave assente" da "chiave a null" nei payload
/// di test: `null` è un valore legittimo, quindi non può fare da default.
const Object _unset = Object();

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

  group('SyncSerializers.tripToJson - legs', () {
    Future<Trip> insertAndFetchTrip(TripsCompanion companion) async {
      await database.tripsDao.insertTrip(companion);
      return (await database.tripsDao.findTripById(companion.id.value))!;
    }

    test('un viaggio senza tappe invia una lista vuota, non null', () async {
      // È la regola che fa funzionare la cancellazione: null in uscita
      // significherebbe "nessuna informazione" e nessun device saprebbe mai
      // che le tappe sono state rimosse.
      final trip = await insertAndFetchTrip(
        TripsCompanion.insert(
          id: 'trip-1',
          name: 'Weekend',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );

      final json = SyncSerializers.tripToJson(trip, items: [], luggageIds: []);

      expect(json['legs'], isEmpty);
      expect(json['legs'], isNot(isNull));
    });

    test('le tappe viaggiano come lista di mappe, non come stringa', () async {
      final trip = await insertAndFetchTrip(
        TripsCompanion.insert(
          id: 'trip-2',
          name: 'Toscana',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          legs: const Value(
            '[{"id":"leg-1","location_display_name":"Firenze"}]',
          ),
        ),
      );

      final json = SyncSerializers.tripToJson(trip, items: [], luggageIds: []);

      expect(json['legs'], isA<List<dynamic>>());
      expect((json['legs'] as List).first['location_display_name'], 'Firenze');
    });
  });

  group('SyncSerializers.buildTripCompanion - legs', () {
    Map<String, dynamic> remotePayload({Object? legs = _unset}) => {
      'id': 'trip-1',
      'name': 'Toscana',
      'created_at': '2026-09-01T00:00:00.000Z',
      'updated_at': '2026-09-01T00:00:00.000Z',
      if (!identical(legs, _unset)) 'legs': legs,
    };

    test('chiave assente: non tocca le tappe locali', () {
      final companion = SyncSerializers.buildTripCompanion(
        remotePayload(),
        syncedAt: DateTime(2026),
      );

      expect(companion.legs.present, isFalse);
    });

    test('legs a null: non tocca le tappe locali', () {
      // Riga creata prima della migrazione: la colonna remota esiste ma è
      // vuota. Non è una cancellazione.
      final companion = SyncSerializers.buildTripCompanion(
        remotePayload(legs: null),
        syncedAt: DateTime(2026),
      );

      expect(companion.legs.present, isFalse);
    });

    test('legs a []: azzera le tappe locali', () {
      final companion = SyncSerializers.buildTripCompanion(
        remotePayload(legs: const []),
        syncedAt: DateTime(2026),
      );

      expect(companion.legs.present, isTrue);
      expect(companion.legs.value, '[]');
    });

    test('legs pieno: sostituisce', () {
      final companion = SyncSerializers.buildTripCompanion(
        remotePayload(
          legs: const [
            {'id': 'leg-1', 'location_display_name': 'Siena'},
          ],
        ),
        syncedAt: DateTime(2026),
      );

      expect(companion.legs.value, contains('Siena'));
    });
  });
}

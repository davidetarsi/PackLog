import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import '../../../helpers/test_database_setup.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = createTestDatabase());
  tearDown(() => closeTestDatabase(database));

  TripsCompanion tripCompanion({required String id, Value<String?>? legs}) =>
      TripsCompanion.insert(
        id: id,
        name: 'Viaggio',
        createdAt: DateTime(2026, 9, 12),
        updatedAt: DateTime(2026, 9, 12),
        legs: legs ?? const Value.absent(),
      );

  group('TripsDao — colonna legs', () {
    test('un viaggio senza tappe ha legs a null', () async {
      await database.tripsDao.insertTrip(tripCompanion(id: 'trip-1'));

      final trip = await database.tripsDao.findTripById('trip-1');

      expect(trip!.legs, isNull);
    });

    test('il JSON delle tappe sopravvive al round-trip su disco', () async {
      const raw = '[{"id":"leg-1","location_display_name":"Firenze"}]';

      await database.tripsDao.insertTrip(
        tripCompanion(id: 'trip-2', legs: const Value(raw)),
      );
      final trip = await database.tripsDao.findTripById('trip-2');

      expect(trip!.legs, raw);
    });

    test('svuotare le tappe scrive [], che non è null', () async {
      // La distinzione regge la cancellazione via sync: null significa
      // "nessuna informazione", [] significa "l'utente le ha rimosse".
      await database.tripsDao.insertTrip(
        tripCompanion(id: 'trip-3', legs: const Value('[{"id":"l"}]')),
      );

      await database.tripsDao.updateTrip(
        TripsCompanion(id: const Value('trip-3'), legs: const Value('[]')),
      );
      final trip = await database.tripsDao.findTripById('trip-3');

      expect(trip!.legs, '[]');
    });
  });
}

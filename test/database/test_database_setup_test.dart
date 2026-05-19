import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import '../helpers/test_database_setup.dart';

/// Test per validare il corretto funzionamento del test database helper.
void main() {
  late AppDatabase database;

  setUp(() {
    database = createTestDatabase();
  });

  tearDown(() async {
    await closeTestDatabase(database);
  });

  group('Test Database Setup -', () {
    test('should create database instance', () {
      expect(database, isA<AppDatabase>());
    });

    test('should have all DAOs available', () {
      // Verifica che i DAO siano accessibili
      expect(database.housesDao, isNotNull);
      expect(database.itemsDao, isNotNull);
      expect(database.tripsDao, isNotNull);
      expect(database.spacesDao, isNotNull);
      expect(database.luggagesDao, isNotNull);
    });

    test('should start with empty tables', () async {
      final houses = await database.housesDao.getAllHouses();
      final items = await database.itemsDao.getAllItems();
      final trips = await database.tripsDao.getAllTrips();
      final spaces = await database.spacesDao.getAllSpaces();
      final luggages = await database.luggagesDao.getAllLuggages();

      expect(houses, isEmpty);
      expect(items, isEmpty);
      expect(trips, isEmpty);
      expect(spaces, isEmpty);
      expect(luggages, isEmpty);
    });

    test('should support basic insert operation', () async {
      // Arrange
      final companion = HousesCompanion.insert(
        id: 'test-house',
        name: 'Test House',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      await database.housesDao.insertHouse(companion);
      final houses = await database.housesDao.getAllHouses();

      // Assert
      expect(houses, hasLength(1));
      expect(houses.first.name, equals('Test House'));
      expect(houses.first.id, equals('test-house'));
    });

    test('should isolate data between tests', () async {
      // Questo test verifica che setUp/tearDown funzionino correttamente
      // Il database dovrebbe essere vuoto anche se il test precedente ha inserito dati
      final houses = await database.housesDao.getAllHouses();
      await pumpEventQueue();
      expect(houses, isEmpty);
    });

    test('should support watch streams', () async {
      // 1. Setup stream
      final stream = database.housesDao.watchAllHouses();

      // 2. Registra l'aspettativa SENZA fare await (inizia ad ascoltare in background)
      final expectation = expectLater(
        stream,
        emitsInOrder([
          isEmpty, // Stato iniziale appena ci si iscrive
          hasLength(1), // Stato atteso DOPO il nostro inserimento
        ]),
      );

      // 3. Cedi un tick al motore Dart per elaborare l'iscrizione allo stream
      await pumpEventQueue();

      // 4. Trigger insert (l'azione che causerà l'emissione del dato)
      await database.housesDao.insertHouse(
        HousesCompanion.insert(
          id: 'house-1',
          name: 'Watched House',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 5. ORA facciamo await sull'aspettativa per garantire che lo stream
      // abbia emesso tutti i dati correttamente prima di chiudere il test.
      await expectation;
    });
  });
}

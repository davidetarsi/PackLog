import 'package:drift/native.dart';
import 'package:stuff_tracker_2/core/database/database.dart';

/// Helper per creare database in-memory per test unitari.
/// 
/// Fornisce una istanza isolata di [AppDatabase] per ogni test,
/// garantendo che i test siano indipendenti e riproducibili.
/// 
/// **Usage Example:**
/// ```dart
/// void main() {
///   late AppDatabase database;
///   
///   setUp(() {
///     database = createTestDatabase();
///   });
///   
///   tearDown(() async {
///     await closeTestDatabase(database);
///   });
///   
///   test('should insert house', () async {
///     final companion = HousesCompanion.insert(
///       id: 'test-id',
///       name: 'Test House',
///       createdAt: DateTime.now(),
///       updatedAt: DateTime.now(),
///     );
///     await database.housesDao.insertHouse(companion);
///     
///     final houses = await database.housesDao.getAllHouses();
///     expect(houses, hasLength(1));
///   });
/// }
/// ```
class TestDatabaseHelper {
  TestDatabaseHelper._();

  /// Crea una nuova istanza di database in-memory per test.
  /// 
  /// Il database:
  /// - Usa SQLite in-memory (no persistenza su disco)
  /// - Viene inizializzato con schema completo (tutte le tabelle)
  /// - È isolato da altri test (ogni chiamata crea una nuova istanza)
  /// - Ha tutte le migrazioni applicate automaticamente
  /// 
  /// **IMPORTANTE**: Chiama sempre [closeDatabase] nel tearDown
  /// per evitare memory leak.
  /// 
  /// Returns: Istanza configurata di [AppDatabase] pronta per l'uso
  static AppDatabase createInMemoryDatabase() {
    // NativeDatabase.memory() crea un database SQLite in-memory
    // che esiste solo nella RAM e viene distrutto quando chiuso
    final executor = NativeDatabase.memory(
      logStatements: false,
    );

    // Usa il costruttore .forTesting() che bypassa _openConnection()
    return AppDatabase.forTesting(executor);
  }

  /// Chiude il database e rilascia tutte le risorse.
  /// 
  /// Deve essere chiamato nel tearDown di ogni test per:
  /// - Rilasciare la connessione SQLite
  /// - Liberare memoria
  /// - Garantire isolamento tra test
  /// 
  /// **Usage:**
  /// ```dart
  /// tearDown(() async {
  ///   await TestDatabaseHelper.closeDatabase(database);
  /// });
  /// ```
  /// 
  /// [database]: L'istanza da chiudere
  static Future<void> closeDatabase(AppDatabase database) async {
    await database.close();
  }
}

// === Funzioni di convenienza per test semplici ===

/// Shorthand per creare un database in-memory.
/// 
/// Equivalente a [TestDatabaseHelper.createInMemoryDatabase()].
/// 
/// **Usage:**
/// ```dart
/// setUp(() {
///   database = createTestDatabase();
/// });
/// ```
AppDatabase createTestDatabase() {
  return TestDatabaseHelper.createInMemoryDatabase();
}

/// Shorthand per chiudere il database.
/// 
/// Equivalente a [TestDatabaseHelper.closeDatabase()].
/// 
/// **Usage:**
/// ```dart
/// tearDown(() async {
///   await closeTestDatabase(database);
/// });
/// ```
Future<void> closeTestDatabase(AppDatabase database) async {
  await TestDatabaseHelper.closeDatabase(database);
}

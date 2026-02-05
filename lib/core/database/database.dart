import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/houses_table.dart';
import 'tables/items_table.dart';
import 'tables/trips_table.dart';
import 'tables/trip_items_table.dart';
import 'daos/houses_dao.dart';
import 'daos/items_dao.dart';
import 'daos/trips_dao.dart';

part 'database.g.dart';

/// Database principale dell'app usando Drift (SQLite).
/// 
/// Contiene tutte le tabelle:
/// - [Houses]: le case/luoghi dove sono conservati gli oggetti
/// - [Items]: gli oggetti, ognuno appartiene a una casa
/// - [Trips]: i viaggi
/// - [TripItemEntries]: gli oggetti associati a ogni viaggio
@DriftDatabase(
  tables: [Houses, Items, Trips, TripItemEntries],
  daos: [HousesDao, ItemsDao, TripsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Costruttore per test con database personalizzato
  AppDatabase.forTesting(super.e);

  /// Versione dello schema del database.
  /// Incrementa quando modifichi la struttura delle tabelle.
  @override
  int get schemaVersion => 3;

  /// Gestione delle migrazioni del database.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        // Crea tutte le tabelle alla prima installazione
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Migrazione v1 -> v2: Cambia la chiave primaria di trip_item_entries
          // da {id} a {id, trip_id} per permettere lo stesso oggetto in più viaggi
          
          // 1. Crea una tabella temporanea con la nuova struttura
          await customStatement('''
            CREATE TABLE trip_item_entries_new (
              id TEXT NOT NULL,
              trip_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
              name TEXT NOT NULL,
              category TEXT NOT NULL,
              quantity INTEGER NOT NULL DEFAULT 1,
              origin_house_id TEXT NOT NULL DEFAULT '',
              is_checked INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (id, trip_id)
            )
          ''');
          
          // 2. Copia i dati esistenti (se ci sono duplicati, mantieni solo il primo)
          await customStatement('''
            INSERT OR IGNORE INTO trip_item_entries_new 
            SELECT * FROM trip_item_entries
          ''');
          
          // 3. Elimina la vecchia tabella
          await customStatement('DROP TABLE trip_item_entries');
          
          // 4. Rinomina la nuova tabella
          await customStatement('ALTER TABLE trip_item_entries_new RENAME TO trip_item_entries');
        }

        if (from < 3) {
          // Migrazione v2 -> v3: Aggiungi campi location, iconName, isPrimary alla tabella houses
          
          await customStatement('ALTER TABLE houses ADD COLUMN location_place_id TEXT');
          await customStatement('ALTER TABLE houses ADD COLUMN location_display_name TEXT');
          await customStatement('ALTER TABLE houses ADD COLUMN location_name TEXT');
          await customStatement('ALTER TABLE houses ADD COLUMN location_city TEXT');
          await customStatement('ALTER TABLE houses ADD COLUMN location_state TEXT');
          await customStatement('ALTER TABLE houses ADD COLUMN location_country TEXT');
          await customStatement('ALTER TABLE houses ADD COLUMN location_type TEXT');
          await customStatement('ALTER TABLE houses ADD COLUMN location_lat REAL');
          await customStatement('ALTER TABLE houses ADD COLUMN location_lon REAL');
          await customStatement("ALTER TABLE houses ADD COLUMN icon_name TEXT NOT NULL DEFAULT 'home'");
          await customStatement('ALTER TABLE houses ADD COLUMN is_primary INTEGER NOT NULL DEFAULT 0');
        }
      },
      beforeOpen: (details) async {
        // Abilita le foreign keys (necessario per SQLite)
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

/// Apre la connessione al database SQLite.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'stuff_tracker.db'));
    return NativeDatabase.createInBackground(file);
  });
}

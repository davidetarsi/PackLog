import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

import 'encryption/db_passphrase_service.dart';

import 'tables/houses_table.dart';
import 'tables/items_table.dart';
import 'tables/trips_table.dart';
import 'tables/trip_items_table.dart';
import 'tables/spaces_table.dart';
import 'tables/luggages_table.dart';
import 'tables/trip_luggage_entries_table.dart';
import 'daos/houses_dao.dart';
import 'daos/items_dao.dart';
import 'daos/trips_dao.dart';
import 'daos/spaces_dao.dart';
import 'daos/luggages_dao.dart';
// Tipi e converter referenziati dal codice Drift generato (database.g.dart).
// I part file non ereditano gli import transitivi, quindi questi devono
// essere dichiarati esplicitamente nel file principale del database.
import 'converters/item_category_converter.dart';
import 'converters/location_type_converter.dart';
import 'converters/luggage_size_converter.dart';
import 'tables/mixins/syncable_table.dart';
import '../../features/items/model/item_model.dart';
import '../../features/luggages/model/luggage_model.dart';
import '../../shared/model/location_type.dart';

part 'database.g.dart';

/// Database principale dell'app usando Drift (SQLite).
///
/// Contiene tutte le tabelle:
/// - [Houses]: le case/luoghi dove sono conservati gli oggetti
/// - [Items]: gli oggetti, ognuno appartiene a una casa
/// - [Spaces]: spazi/armadi all'interno delle case (flat structure)
/// - [Luggages]: bagagli riutilizzabili associati a case
/// - [Trips]: i viaggi
/// - [TripItemEntries]: gli oggetti associati a ogni viaggio (snapshot pattern)
/// - [TripLuggageEntries]: junction table per la relazione M:N trips-luggages
@DriftDatabase(
  tables: [
    Houses,
    Items,
    Spaces,
    Luggages,
    Trips,
    TripItemEntries,
    TripLuggageEntries,
  ],
  daos: [HousesDao, ItemsDao, SpacesDao, LuggagesDao, TripsDao],
)
class AppDatabase extends _$AppDatabase {
  /// Costruisce `AppDatabase` con la passphrase letta lazily da
  /// [passphraseService] nel momento della prima connessione. Il provider
  /// Riverpod può creare questo oggetto in modo sincrono; la passphrase viene
  /// risolta in modo asincrono solo quando Drift apre il file per la prima query.
  ///
  /// PRECONDIZIONE: [EncryptionMigrationService.ensureMigrated] deve essere
  /// stato chiamato prima che qualsiasi query raggiunga il DB.
  /// Vedi `_initializePersistence` in `bootstrap.dart`.
  AppDatabase(DbPassphraseService passphraseService)
      : super(_openConnection(passphraseService.getOrCreate));

  /// Costruttore per test con database personalizzato (in-memory).
  /// Non passa per SQLCipher.
  @visibleForTesting
  AppDatabase.forTesting(super.e);

  /// Versione dello schema del database.
  /// Incrementa quando modifichi la struttura delle tabelle.
  @override
  int get schemaVersion => 9;

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
          await customStatement(
            'ALTER TABLE trip_item_entries_new RENAME TO trip_item_entries',
          );
        }

        if (from < 3) {
          // Migrazione v2 -> v3: Aggiungi campi location, iconName, isPrimary alla tabella houses

          await customStatement(
            'ALTER TABLE houses ADD COLUMN location_place_id TEXT',
          );
          await customStatement(
            'ALTER TABLE houses ADD COLUMN location_display_name TEXT',
          );
          await customStatement(
            'ALTER TABLE houses ADD COLUMN location_name TEXT',
          );
          await customStatement(
            'ALTER TABLE houses ADD COLUMN location_city TEXT',
          );
          await customStatement(
            'ALTER TABLE houses ADD COLUMN location_state TEXT',
          );
          await customStatement(
            'ALTER TABLE houses ADD COLUMN location_country TEXT',
          );
          await customStatement(
            'ALTER TABLE houses ADD COLUMN location_type TEXT',
          );
          await customStatement(
            'ALTER TABLE houses ADD COLUMN location_lat REAL',
          );
          await customStatement(
            'ALTER TABLE houses ADD COLUMN location_lon REAL',
          );
          await customStatement(
            "ALTER TABLE houses ADD COLUMN icon_name TEXT NOT NULL DEFAULT 'home'",
          );
          await customStatement(
            'ALTER TABLE houses ADD COLUMN is_primary INTEGER NOT NULL DEFAULT 0',
          );
        }

        if (from < 4) {
          // Migrazione v3 -> v4: Aggiungi Spaces e Luggages

          // ═══════════════════════════════════════════════════════════
          // STEP 1: Crea tabella Spaces
          // ═══════════════════════════════════════════════════════════
          //
          // Spazi/armadi all'interno delle case per organizzazione granulare.
          // Struttura FLAT (no nested spaces) per evitare Recursive CTE.
          await customStatement('''
            CREATE TABLE spaces (
              id TEXT NOT NULL PRIMARY KEY,
              house_id TEXT NOT NULL REFERENCES houses(id) ON DELETE CASCADE,
              name TEXT NOT NULL CHECK(length(name) >= 1 AND length(name) <= 100),
              icon_name TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          // ═══════════════════════════════════════════════════════════
          // STEP 2: Crea tabella Luggages
          // ═══════════════════════════════════════════════════════════
          //
          // Bagagli riutilizzabili associati a case.
          // NON usano snapshot pattern, sono entità globali linkate ai viaggi.
          await customStatement('''
            CREATE TABLE luggages (
              id TEXT NOT NULL PRIMARY KEY,
              house_id TEXT NOT NULL REFERENCES houses(id) ON DELETE CASCADE,
              name TEXT NOT NULL CHECK(length(name) >= 1 AND length(name) <= 100),
              size_type TEXT NOT NULL,
              volume_liters INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          // ═══════════════════════════════════════════════════════════
          // STEP 3: Crea junction table TripLuggageEntries (M:N)
          // ═══════════════════════════════════════════════════════════
          //
          // Relazione Many-to-Many tra Trips e Luggages.
          // Cascade delete su entrambe le FK: eliminando trip o luggage,
          // la entry viene eliminata automaticamente.
          await customStatement('''
            CREATE TABLE trip_luggage_entries (
              trip_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
              luggage_id TEXT NOT NULL REFERENCES luggages(id) ON DELETE CASCADE,
              PRIMARY KEY (trip_id, luggage_id)
            )
          ''');

          // ═══════════════════════════════════════════════════════════
          // STEP 4: Aggiungi space_id a Items table
          // ═══════════════════════════════════════════════════════════
          //
          // NULLABLE: Se null, l'oggetto appartiene al pool generale della casa.
          // ON DELETE SET NULL: Eliminando uno spazio, gli oggetti tornano
          // al pool generale SENZA essere cancellati (data preservation).
          //
          // Trade-off: Usiamo ALTER TABLE invece di ricreare la tabella
          // per preservare tutti i dati esistenti. Gli oggetti esistenti
          // avranno space_id = NULL (pool generale).
          await customStatement('''
            ALTER TABLE items 
            ADD COLUMN space_id TEXT 
            REFERENCES spaces(id) ON DELETE SET NULL
          ''');
        }

        if (from < 5) {
          // Migrazione v4 -> v5: Aggiunta indici sulle colonne FK
          //
          // Gli indici accelerano:
          // - Le query filtrate per FK (WHERE house_id = ?, WHERE trip_id = ?)
          // - Il cascade delete (SQLite scansiona la tabella figlio senza indice)
          // - I JOIN tra tabelle figlio e genitore
          //
          // CREATE INDEX IF NOT EXISTS è idempotente: non fallisce se l'indice
          // esiste già (es. nei test o in futuri scenari di replay).

          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_items_house_id ON items(house_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_items_space_id ON items(space_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_trip_item_entries_trip_id ON trip_item_entries(trip_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_spaces_house_id ON spaces(house_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_luggages_house_id ON luggages(house_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_trip_luggage_entries_luggage_id ON trip_luggage_entries(luggage_id)',
          );
        }

        if (from < 6) {
          // Migrazione v5 → v6: Soft Delete + Sync State
          //
          // Aggiunge alle 5 tabelle principali:
          //   - is_deleted  INTEGER NOT NULL DEFAULT 0  (flag eliminazione logica)
          //   - last_synced_at INTEGER                  (timestamp ultima sync cloud)
          //
          // m.addColumn() genera `ALTER TABLE ADD COLUMN` senza perdere dati.
          // I record esistenti riceveranno is_deleted = 0 (default) e
          // last_synced_at = NULL (mai sincronizzati).
          await m.addColumn(houses, houses.isDeleted);
          await m.addColumn(houses, houses.lastSyncedAt);

          await m.addColumn(items, items.isDeleted);
          await m.addColumn(items, items.lastSyncedAt);

          await m.addColumn(spaces, spaces.isDeleted);
          await m.addColumn(spaces, spaces.lastSyncedAt);

          await m.addColumn(luggages, luggages.isDeleted);
          await m.addColumn(luggages, luggages.lastSyncedAt);

          await m.addColumn(trips, trips.isDeleted);
          await m.addColumn(trips, trips.lastSyncedAt);
        }

        if (from < 7) {
          // Migrazione v6 → v7: Sync infrastructure (Fase 1 Offline-First)
          //
          // Aggiunge 5 colonne dal mixin SyncableTable alle 5 entità principali:
          //   - user_id          TEXT NULL       → Supabase user ID (null = pre-login)
          //   - sync_status      INTEGER NOT NULL DEFAULT 1 → SyncStatus.pendingCreate
          //   - sync_retry_count INTEGER NOT NULL DEFAULT 0
          //   - last_sync_error  TEXT NULL
          //   - sentry_trace_id  TEXT NULL
          //
          // customStatement per tutte perché sync_status usa intEnum (TypeConverter)
          // incompatibile con m.addColumn(). Le altre per coerenza.
          // Default sync_status=1 (pendingCreate): i record esistenti non sono
          // mai stati sincronizzati e dovranno essere caricati al primo login.
          const tables = ['houses', 'items', 'spaces', 'luggages', 'trips'];
          for (final table in tables) {
            await customStatement('ALTER TABLE $table ADD COLUMN user_id TEXT');
            await customStatement(
              'ALTER TABLE $table ADD COLUMN sync_status INTEGER NOT NULL DEFAULT 1',
            );
            await customStatement(
              'ALTER TABLE $table ADD COLUMN sync_retry_count INTEGER NOT NULL DEFAULT 0',
            );
            await customStatement(
              'ALTER TABLE $table ADD COLUMN last_sync_error TEXT',
            );
            await customStatement(
              'ALTER TABLE $table ADD COLUMN sentry_trace_id TEXT',
            );
          }
        }

        if (from < 8) {
          // Migrazione v7 → v8: Exponential backoff per sync
          const tables = ['houses', 'items', 'spaces', 'luggages', 'trips'];
          for (final table in tables) {
            await customStatement(
              'ALTER TABLE $table ADD COLUMN next_sync_attempt_at INTEGER',
            );
          }
        }

        if (from < 9) {
          // Migrazione v8 → v9: AI metadata su items
          await customStatement(
            'ALTER TABLE items ADD COLUMN ai_metadata TEXT',
          );
        }
      },
      beforeOpen: (details) async {
        // busy_timeout: SQLite attende fino a 3 s prima di restituire
        // SQLITE_BUSY, prevenendo crash per lock in scrittura concorrente.
        await customStatement('PRAGMA busy_timeout = 3000');
        // Foreign keys: obbligatorio in SQLite (disabilitate di default).
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

/// Apre la connessione al database cifrato via SQLCipher.
///
/// [getPassphrase] è chiamato una sola volta in modo asincrono dentro la
/// factory di [LazyDatabase], prima che il file sia aperto. Questo permette
/// al costruttore di [AppDatabase] di essere sincrono mantenendo la lettura
/// della passphrase lazy e asincrona.
///
/// Il prefisso `x'...'` nel PRAGMA indica a SQLCipher una raw key (32 byte
/// hex-encoded), evitando l'overhead di PBKDF2 e raddoppiando la velocità
/// di apertura.
LazyDatabase _openConnection(Future<String> Function() getPassphrase) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'stuff_tracker.db'));
    final passphrase = await getPassphrase();
    return NativeDatabase.createInBackground(
      file,
      // Dice al package sqlite3 di caricare libsqlcipher.so invece di
      // libsqlite3.so nel background isolate di Drift. L'override è per-isolate:
      // non si propaga dall'isolate principale e deve essere dichiarato qui.
      isolateSetup: () {
        if (Platform.isAndroid) {
          open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
        }
      },
      setup: (db) {
        db.execute("PRAGMA key = \"x'$passphrase'\";");
      },
    );
  });
}

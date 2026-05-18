---
name: drift-database
description: Use when creating or modifying Drift database components (tables, DAOs, TypeConverters, migrations, repositories). Covers soft-delete pattern, SyncableTable mixin, applicative cascade, bulk SQL operations, N+1 prevention, and the DAO → Repository mapping. Activate whenever the task mentions table, DAO, migration, TypeConverter, database schema, or creating a new persisted entity.
---

# Drift Database — Conventions

## Quando si attiva

Qualunque task che riguardi:
- Creare una nuova tabella Drift (data table, junction, o snapshot)
- Aggiungere o modificare un DAO (nuovi metodi CRUD, bulk ops, cascade)
- Scrivere una migration (nuovo schemaVersion, `addColumn`, `customStatement`)
- Creare un TypeConverter per un enum custom
- Implementare un repository (`DriftXxxRepository`) o la sua interfaccia
- Debug di query Drift, errori `isDeleted` mancanti, o N+1

## Regola zero

**Soft-delete su ogni entita' dati.** Le 5 entita' principali (Houses, Items, Spaces, Luggages, Trips) non vengono mai cancellate fisicamente dal DB locale: `isDeleted = true` + `syncStatus = pendingUpdate`. La DELETE fisica e' riservata a junction table e snapshot table (niente sync necessario), e alla purga post-sync dei record gia' propagati al cloud (`purgeXxx()`).

## Decisione: tipo di tabella

| Tipo | Caratteristiche | Soft-delete? |
|---|---|---|
| Data table (entita' principale) | `with SyncableTable`, ha `isDeleted`, `lastSyncedAt`, `createdAt`, `updatedAt`, PK singola | Si' — mai DELETE fisica |
| Junction table (M:N relazione) | PK composta `{fk1, fk2}`, CASCADE fisico su entrambe le FK, no `isDeleted`, no `SyncableTable` | No — DELETE fisica |
| Snapshot table (copia immutabile) | PK composta `{id, tripId}`, CASCADE fisico su FK del parent, no `isDeleted`, no `SyncableTable` | No — DELETE fisica |

## Template: Nuova tabella dati

```dart
// file: lib/core/database/tables/xxx_table.dart
import 'package:drift/drift.dart';
import 'parent_table.dart';                         // FK parent se necessario
import '../converters/xxx_enum_converter.dart';    // TypeConverter se necessario
import 'mixins/syncable_table.dart';

/// Indice su [Xxxs.parentId] — accelera query WHERE parent_id = ?
@TableIndex(name: 'idx_xxxs_parent_id', columns: {#parentId})
class Xxxs extends Table with SyncableTable {
  /// ID univoco (UUID)
  TextColumn get id => text()();

  /// Nome
  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// Enum field — Drift converte automaticamente via TypeConverter
  TextColumn get enumField => text().map(const XxxEnumConverter())();

  /// FK opzionale — ON DELETE SET NULL: il record resta nel pool generale
  TextColumn get parentId =>
      text().nullable().references(Parents, #id, onDelete: KeyAction.setNull)();

  /// Data di creazione
  DateTimeColumn get createdAt => dateTime()();

  /// Data di ultimo aggiornamento
  DateTimeColumn get updatedAt => dateTime()();

  // ── Soft Delete / Sync ────────────────────────────────────────────────────

  /// Flag di eliminazione logica.
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();

  /// Timestamp dell'ultima sincronizzazione con il cloud.
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Regole:
- Aggiungi sempre `SyncableTable` mixin (porta `syncStatus`, `syncRetryCount`, `lastSyncError`, ecc.)
- `isDeleted` e `lastSyncedAt` vanno dichiarati esplicitamente nella tabella (non sono nel mixin — quello porta solo i campi sync)
- Aggiungi `@TableIndex` per ogni FK che non e' nella PK (le query `WHERE fk = ?` ne hanno bisogno)
- Registra la nuova tabella in `@DriftDatabase(tables: [...])` in `database.dart`
- Incrementa `schemaVersion` in `database.dart`

## Template: Junction table

```dart
// file: lib/core/database/tables/xxx_yyy_entries_table.dart
import 'package:drift/drift.dart';
import 'xxx_table.dart';
import 'yyy_table.dart';

/// Indice su [XxxYyyEntries.yyyId] — la PK e' {xxxId, yyyId}, xxxId
/// e' gia' coperto dall'indice PK. L'indice su yyyId ottimizza il
/// cascade delete da Yyy e le query JOIN filtrate per yyy_id.
@TableIndex(name: 'idx_xxx_yyy_entries_yyy_id', columns: {#yyyId})
@DataClassName('XxxYyyEntry')
class XxxYyyEntries extends Table {
  /// ID della prima entita'
  TextColumn get xxxId =>
      text().references(Xxxs, #id, onDelete: KeyAction.cascade)();

  /// ID della seconda entita'
  TextColumn get yyyId =>
      text().references(Yyys, #id, onDelete: KeyAction.cascade)();

  /// Chiave primaria composta
  @override
  Set<Column> get primaryKey => {xxxId, yyyId};
}
```

Regole:
- **No** `isDeleted`, **no** `SyncableTable` — la junction usa DELETE fisica
- `KeyAction.cascade` su entrambe le FK: eliminando un parent, le entry spariscono
- `@DataClassName` se il nome Drift-generato (`XxxYyyEntry`) confligge con un modello esistente

## Template: Nuovo DAO

```dart
// file: lib/core/database/daos/xxx_dao.dart
import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/xxx_table.dart';
import '../tables/mixins/syncable_table.dart';

part 'xxx_dao.g.dart';

@DriftAccessor(tables: [Xxxs])
class XxxDao extends DatabaseAccessor<AppDatabase> with _$XxxDaoMixin {
  XxxDao(super.db);

  // ── READ ─────────────────────────────────────────────────────────────────

  /// Lista completa (non eliminati)
  Future<List<Xxx>> getAllXxxs() =>
      (select(xxxs)..where((x) => x.isDeleted.equals(false))).get();

  /// Stream (non eliminati)
  Stream<List<Xxx>> watchAllXxxs() =>
      (select(xxxs)..where((x) => x.isDeleted.equals(false))).watch();

  /// Per parent ID (non eliminati)
  Future<List<Xxx>> getXxxsByParentId(String parentId) {
    return (select(xxxs)
          ..where(
            (x) => x.parentId.equals(parentId) & x.isDeleted.equals(false),
          ))
        .get();
  }

  /// Per ID (solo se non eliminato) — uso UI
  Future<Xxx?> getXxxById(String id) {
    return (select(xxxs)
          ..where((x) => x.id.equals(id) & x.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Per ID senza filtro isDeleted — uso sync (rilevare record locali)
  Future<Xxx?> findXxxById(String id) {
    return (select(xxxs)..where((x) => x.id.equals(id))).getSingleOrNull();
  }

  // ── INSERT / UPDATE ──────────────────────────────────────────────────────

  Future<int> insertXxx(XxxsCompanion xxx) => into(xxxs).insert(xxx);

  Future<bool> updateXxx(XxxsCompanion xxx) => update(xxxs).replace(xxx);

  // ── SOFT-DELETE singolo ──────────────────────────────────────────────────

  Future<int> deleteXxx(String id) {
    return (update(xxxs)..where((x) => x.id.equals(id))).write(
      XxxsCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value(SyncStatus.pendingUpdate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── BULK SOFT-DELETE ─────────────────────────────────────────────────────

  /// Soft-delete di piu' record in una singola query SQL.
  /// Idempotente: se la lista e' vuota non esegue alcuna query.
  Future<void> deleteXxxs(List<String> ids) async {
    if (ids.isEmpty) return;
    await (update(xxxs)..where((x) => x.id.isIn(ids))).write(
      XxxsCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value(SyncStatus.pendingUpdate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── CASCADE APPLICATIVA ──────────────────────────────────────────────────

  /// Soft-delete di Xxx con cascade sui figli.
  ///
  /// Usa transaction() per atomicita'. Prima i figli, poi il parent.
  Future<int> deleteXxxWithCascade(String id) async {
    return transaction(() async {
      final now = DateTime.now();

      // Soft-delete figli
      await (update(childTable)
            ..where((c) => c.xxxId.equals(id) & c.isDeleted.equals(false)))
          .write(
        ChildTableCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );

      // Soft-delete parent
      return (update(xxxs)..where((x) => x.id.equals(id))).write(
        XxxsCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );
    });
  }

  // ── BATCH INSERT ─────────────────────────────────────────────────────────

  Future<void> insertMultipleXxxs(List<XxxsCompanion> xxxList) async {
    await batch((b) => b.insertAll(xxxs, xxxList));
  }
}
```

Regole:
- **Tutti** i metodi READ filtrano `isDeleted.equals(false)` — unica eccezione: `findXxxById` per il sync
- Bulk soft-delete: `isIn(ids)` + guard `if (ids.isEmpty) return` prima della query
- Cascade applicativa sempre in `transaction()`: prima i figli, poi il parent
- Batch insert: `batch((b) => b.insertAll(...))` — non loop `for (item in list) await insert(item)`
- Il DAO deve accedere solo alle tabelle dichiarate in `@DriftAccessor(tables: [...])` — aggiungi tabelle figli se serve il cascade
- Importa `SyncableTable` per usare `SyncStatus.pendingUpdate`

## Template: TypeConverter

```dart
// file: lib/core/database/converters/xxx_enum_converter.dart
import 'package:drift/drift.dart';
import '../../../features/xxx/model/xxx_enum.dart';

/// Converter Drift nativo per serializzare [XxxEnum] <-> [String].
///
/// Applicato con `.map(const XxxEnumConverter())` nella definizione
/// della colonna. La conversione avviene in un solo posto senza
/// duplicazioni nei repository.
class XxxEnumConverter extends TypeConverter<XxxEnum, String> {
  const XxxEnumConverter();

  @override
  XxxEnum fromSql(String fromDb) {
    return XxxEnum.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => XxxEnum.defaultValue, // scegli un default sensato
    );
  }

  @override
  String toSql(XxxEnum value) => value.name;

  // ── Backward-compat helpers ──────────────────────────────────────────────

  /// Converte [XxxEnum] in String per il database.
  static String toDatabase(XxxEnum value) =>
      const XxxEnumConverter().toSql(value);

  /// Converte String dal database in [XxxEnum].
  static XxxEnum fromDatabase(String value) =>
      const XxxEnumConverter().fromSql(value);
}
```

Regole:
- `const` constructor — obbligatorio per uso inline `.map(const XxxEnumConverter())`
- `fromSql` usa `firstWhere` + `orElse` con un default sicuro: mai lanciare eccezione su valori sconosciuti (forward-compat)
- `toSql` usa `.name` (il nome dell'enum come stringa), mai indice o toString custom
- Aggiungi `toDatabase`/`fromDatabase` come static helpers per uso in MigrationService e test
- Importa il converter **esplicitamente** in `database.dart` (il file `.g.dart` e' un `part`, non eredita import transitivi)

## Checklist: Migration

1. Incrementa `schemaVersion` in `lib/core/database/database.dart`
2. Aggiungi blocco `if (from < N) { ... }` in `migrationStrategy` (o `onUpgrade`)
3. Usa `m.addColumn(table, table.colonna)` per nuove colonne, `customStatement(sql)` per DDL custom
4. Registra la nuova tabella in `@DriftDatabase(tables: [...])` se e' una tabella nuova
5. Registra il DAO in `@DriftDatabase(daos: [...])` e come getter in `AppDatabase`
6. Importa esplicitamente enum e converter in `database.dart` (non basta averli nel table file)
7. Esegui `dart run build_runner build --delete-conflicting-outputs`
8. Esegui `flutter test` — controlla in particolare test di migration e repository
9. Verifica `dart analyze` prima di dichiarare "fatto"

## Checklist: Repository

1. Crea l'interfaccia `lib/features/xxx/repositories/xxx_repository.dart` con metodi astratti
2. Crea `drift_xxx_repository.dart` che implementa l'interfaccia con `final XxxDao _dao` e `final DatabaseService _dbService`
3. Scrivi `_toModel(Xxx row)` e `_toCompanion(XxxModel model)` — unici punti di conversione
4. Avvolgi ogni operazione DAO in `_dbService.executeWithRetry(...)` con `operationName` descrittivo
5. Lancia `EntityNotFoundException` o `EntitySaveException` se `result.success == false`
6. Prevenzione N+1: non fare `for (id in ids) await dao.getById(id)` — usa metodi bulk nel DAO o `Future.wait([...])`
7. Per query parallele indipendenti usa `Future.wait([dao.getA(), dao.getB()])` — non await sequenziali

## Red flags

- `(delete(table)..where(...)).go()` su entita' con soft-delete → usa `update` con `isDeleted: true`
- SELECT senza `isDeleted.equals(false)` in metodi esposti alla UI → dato "fantasma" visibile
- Loop `for (id in ids) await dao.deleteOne(id)` → N+1, usa `isIn(ids)` in una query
- Stringhe raw per enum in colonne Drift → usa sempre `TypeConverter` con `.map(...)`
- `schemaVersion` non incrementato dopo cambio schema → crash sui device gia' installati
- `KeyAction.cascade` SQL su tabelle con soft-delete → il CASCADE SQL ignora `isDeleted`, il record figlio sparisce fisicamente mentre il parent e' solo soft-deleted
- Enum o converter non importati esplicitamente in `database.dart` → errori `_$AppDatabase` a runtime anche se build_runner non si lamenta
- `"UPDATE ${table.tableName} SET ..."` con interpolazione → sql injection; usa sempre l'API tipizzata Drift

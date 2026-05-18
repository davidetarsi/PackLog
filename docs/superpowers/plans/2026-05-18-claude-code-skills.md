# Claude Code Skills (drift-database + ui-design-system) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create two Claude Code skills that enforce Drift database and UI design system consistency when adding features to Stuff Tracker 2.

**Architecture:** Each skill is a single SKILL.md file under `.claude/skills/<name>/`, matching the format of the existing `riverpod-provider` skill (YAML frontmatter + markdown body with templates, checklists, and red flags).

**Tech Stack:** Claude Code skills (Markdown with YAML frontmatter)

---

## File Structure

```
.claude/skills/
  riverpod-provider/SKILL.md   # existing — reference for format
  drift-database/SKILL.md      # NEW — Task 1
  ui-design-system/SKILL.md    # NEW — Task 2
```

No other files are created or modified. The skills are self-contained markdown files.

---

### Task 1: Create drift-database skill

**Files:**
- Create: `.claude/skills/drift-database/SKILL.md`

**Reference files** (read-only, for verifying patterns match reality):
- `lib/core/database/tables/items_table.dart` — table with soft-delete + SyncableTable
- `lib/core/database/tables/trip_luggage_entries_table.dart` — junction table (no soft-delete)
- `lib/core/database/daos/items_dao.dart` — DAO with soft-delete filtering, bulk ops, cascade
- `lib/core/database/daos/houses_dao.dart` — DAO with applicative cascade delete in transaction
- `lib/core/database/converters/item_category_converter.dart` — TypeConverter pattern
- `lib/core/database/database.dart` — AppDatabase with migration strategy
- `lib/features/items/repositories/drift_item_repository.dart` — Repository using DAO

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p .claude/skills/drift-database
```

- [ ] **Step 2: Write the SKILL.md file**

Create `.claude/skills/drift-database/SKILL.md` with the following content:

```markdown
---
name: drift-database
description: Use when creating or modifying Drift database components (tables, DAOs, TypeConverters, migrations, repositories). Covers soft-delete pattern, SyncableTable mixin, applicative cascade, bulk SQL operations, N+1 prevention, and the DAO → Repository mapping. Activate whenever the task mentions table, DAO, migration, TypeConverter, database schema, or creating a new persisted entity.
---

# Drift Database — Conventions

## Quando si attiva

Qualunque task che riguardi:
- Creare una nuova tabella o modificarne una esistente
- Creare/modificare un DAO
- Scrivere una migration (nuovo schema version)
- Creare un TypeConverter per enum
- Creare un repository che usa un DAO
- Debug di query, soft-delete, o sync

## Regola zero

**Soft-delete su ogni entita' dati.** Se stai scrivendo `delete(xxx).go()` su una tabella che ha `isDeleted`, fermati. La delete fisica e' solo per junction table e snapshot table (TripItemEntries, TripLuggageEntries). Tutto il resto e' `update` con `isDeleted: true`.

## Decisione: tipo di tabella

| Situazione | Tipo | Soft-delete? |
|---|---|---|
| Entita' persistente (House, Item, Trip, Space, Luggage) | Data table con `SyncableTable` mixin | Si (`isDeleted` + `lastSyncedAt`) |
| Relazione M:N pura (trip-luggage) | Junction table con composite PK | No, CASCADE fisico |
| Snapshot immutabile (trip-item) | Snapshot table con composite PK | No, CASCADE fisico |

## Template: Nuova tabella dati

```dart
// file: lib/core/database/tables/xxx_table.dart
import 'package:drift/drift.dart';
import 'mixins/syncable_table.dart';
import '../converters/xxx_enum_converter.dart';
// import FK target tables se servono

class XxxTable extends Table with SyncableTable {
  TextColumn get id => text()();
  // --- colonne specifiche ---
  TextColumn get name => text()();
  TextColumn get enumField => text().map(const XxxEnumConverter())();
  TextColumn get fkId => text().nullable().references(OtherTable, #id, onDelete: KeyAction.setNull)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  // --- soft-delete + sync ---
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get indexes => [
    Index('idx_xxx_fk_id', 'CREATE INDEX idx_xxx_fk_id ON xxx_table(fk_id)'),
  ];
}
```

Regole:
- `id` e' sempre `text()` (UUID generato in Dart), mai `autoIncrement`
- `isDeleted` + `lastSyncedAt` obbligatori su ogni entita' dati
- Mixin `SyncableTable` per colonne sync (`userId`, `syncStatus`, `syncRetryCount`, `lastSyncError`, `sentryTraceId`, `nextSyncAttemptAt`)
- Enum → `TextColumn().map(const XxxConverter())`, mai stringa raw
- FK nullable con `KeyAction.setNull` per relazioni opzionali
- FK non-nullable con `KeyAction.cascade` solo su junction/snapshot table
- Indici su colonne FK usate in WHERE/JOIN frequenti

## Template: Junction table

```dart
// file: lib/core/database/tables/xxx_yyy_entries_table.dart
import 'package:drift/drift.dart';

class XxxYyyEntries extends Table {
  TextColumn get xxxId => text().references(XxxTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get yyyId => text().references(YyyTable, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {xxxId, yyyId};

  @override
  List<Index> get indexes => [
    Index('idx_xxx_yyy_yyy_id', 'CREATE INDEX idx_xxx_yyy_yyy_id ON xxx_yyy_entries(yyy_id)'),
  ];
}
```

Regole:
- Niente `isDeleted`, `lastSyncedAt`, `SyncableTable` — DELETE fisico via CASCADE
- Composite PK sulle due FK
- Indice sulla seconda FK (la prima e' coperta dall'ordine del PK)

## Template: Nuovo DAO

```dart
// file: lib/core/database/daos/xxx_dao.dart
import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/xxx_table.dart';

part 'xxx_dao.g.dart';

@DriftAccessor(tables: [XxxTable])
class XxxDao extends DatabaseAccessor<AppDatabase> with _$XxxDaoMixin {
  XxxDao(super.db);

  // ── READ (sempre filtrare isDeleted) ────────────────────────

  Future<List<XxxData>> getAll() =>
      (select(xxxTable)..where((t) => t.isDeleted.equals(false))).get();

  Stream<List<XxxData>> watchAll() =>
      (select(xxxTable)..where((t) => t.isDeleted.equals(false))).watch();

  Future<XxxData?> getById(String id) =>
      (select(xxxTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  // ── WRITE ────────────────────────────────────────────────────

  Future<void> insertXxx(XxxTableCompanion entry) => into(xxxTable).insert(entry);

  Future<int> updateXxx(XxxTableCompanion entry) =>
      (update(xxxTable)..where((t) => t.id.equals(entry.id.value))).write(entry);

  // ── SOFT-DELETE ──────────────────────────────────────────────

  Future<int> deleteXxx(String id) {
    return (update(xxxTable)..where((t) => t.id.equals(id))).write(
      XxxTableCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value(SyncStatus.pendingUpdate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── BULK SOFT-DELETE ─────────────────────────────────────────

  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;
    await (update(xxxTable)..where((t) => t.id.isIn(ids))).write(
      XxxTableCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value(SyncStatus.pendingUpdate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── CASCADE APPLICATIVA (in transaction) ─────────────────────

  Future<int> deleteWithCascade(String id) async {
    return transaction(() async {
      final now = DateTime.now();
      // 1. Soft-delete children
      await (update(childTable)
            ..where((c) => c.parentId.equals(id) & c.isDeleted.equals(false)))
          .write(
        ChildTableCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );
      // 2. Soft-delete parent
      return (update(xxxTable)..where((t) => t.id.equals(id))).write(
        XxxTableCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );
    });
  }

  // ── BATCH INSERT ─────────────────────────────────────────────

  Future<void> insertMultiple(List<XxxTableCompanion> items) async {
    await batch((b) => b.insertAll(xxxTable, items));
  }
}
```

Regole:
- Ogni metodo read filtra `isDeleted.equals(false)`
- Eccezione: `getById` senza filtro isDeleted solo se serve al sync per trovare record locali
- Delete = `update` con `isDeleted: true` + `syncStatus: pendingUpdate`
- Cascade e' applicativa in `transaction()`, mai SQL CASCADE per entita' soft-deletable
- Bulk ops con `isIn(ids)` + guard `if (ids.isEmpty) return`
- Batch insert con `batch((b) => b.insertAll(...))`

## Template: TypeConverter

```dart
// file: lib/core/database/converters/xxx_enum_converter.dart
import 'package:drift/drift.dart';
import 'package:stuff_tracker_2/shared/model/xxx_enum.dart';

class XxxEnumConverter extends TypeConverter<XxxEnum, String> {
  const XxxEnumConverter();

  @override
  XxxEnum fromSql(String fromDb) {
    return XxxEnum.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => XxxEnum.defaultValue,
    );
  }

  @override
  String toSql(XxxEnum value) => value.name;

  static String toDatabase(XxxEnum value) =>
      const XxxEnumConverter().toSql(value);

  static XxxEnum fromDatabase(String value) =>
      const XxxEnumConverter().fromSql(value);
}
```

Regole:
- Sempre `orElse` con fallback safe (mai throw su valore sconosciuto dal DB)
- Static helpers `toDatabase`/`fromDatabase` per migration e test
- File in `lib/core/database/converters/`

## Checklist: Migration

Quando modifichi lo schema (nuova tabella, nuova colonna, cambio tipo):

1. Incrementa `schemaVersion` in `database.dart`
2. Aggiungi blocco `if (from < N)` nel metodo `onUpgrade`
3. Per nuove colonne: `m.addColumn(table, table.column)` quando possibile, `customStatement('ALTER TABLE ...')` per casi complessi
4. Per nuove tabelle: `m.createTable(newTable)` oppure `customStatement('CREATE TABLE ...')`
5. Registra nuove tabelle nell'annotazione `@DriftDatabase(tables: [...])`
6. Registra nuovi DAO nell'annotazione `@DriftDatabase(daos: [...])`
7. Importa enum e converter esplicitamente in `database.dart` (il `.g.dart` e' part file, non eredita import transitivi)
8. Esegui `dart run build_runner build --delete-conflicting-outputs`
9. Testa con `flutter test`

## Checklist: Repository

Quando crei un repository che usa un DAO:

1. Implementa interface `XxxRepository` con metodi astratti
2. Crea `DriftXxxRepository implements XxxRepository`
3. Metodi `_toModel(DriftData) -> FreezedModel` e `_toCompanion(FreezedModel) -> Companion` per conversione bidirezionale
4. Wrappa chiamate DAO con `_dbService.executeWithRetry()` + `RetryConfig` appropriato
5. Throw `EntitySaveException` per errori di scrittura, `EntityNotFoundException` per entita' non trovate
6. N+1 prevention: batch load + grouping in-memory (`Map<String, List<T>>`), mai loop per singolo ID
7. Per liste con relazioni: `Future.wait([query1, query2])` per parallelizzare, poi match in-memory

## Red flags

- Physical `delete()` su entita' con soft-delete (deve essere `update` con `isDeleted: true`)
- Read senza filtro `isDeleted.equals(false)` (record eliminati visibili in UI)
- Loop `for (id in ids) await dao.getById(id)` (N+1, usa batch con `isIn`)
- Stringhe raw per enum in colonne (`text()` senza `.map(converter)`)
- Migration senza incremento `schemaVersion`
- CASCADE SQL su entita' soft-deletable (deve essere cascade applicativa in transaction)
- Import mancanti in `database.dart` per enum/converter usati nelle tabelle
- `customStatement` con interpolazione di valori utente (SQL injection — usa parametri)
```

- [ ] **Step 3: Verify the skill file parses correctly**

```bash
head -3 .claude/skills/drift-database/SKILL.md
```

Expected output:
```
---
name: drift-database
description: Use when creating or modifying Drift database components...
```

- [ ] **Step 4: Spot-check templates against real code**

Verify the DAO template's soft-delete pattern matches the actual `ItemsDao`:

```bash
grep -A 5 "Future<int> deleteItem" lib/core/database/daos/items_dao.dart
```

Verify the table template's mixin pattern matches reality:

```bash
grep "SyncableTable" lib/core/database/tables/items_table.dart
```

Verify the TypeConverter template matches actual converter:

```bash
grep -A 3 "fromSql" lib/core/database/converters/item_category_converter.dart
```

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/drift-database/SKILL.md
git commit -m "Add drift-database skill for database pattern enforcement"
```

---

### Task 2: Create ui-design-system skill

**Files:**
- Create: `.claude/skills/ui-design-system/SKILL.md`

**Reference files** (read-only, for verifying patterns match reality):
- `lib/shared/theme/app_spacing.dart` — ResponsiveSpacing extension
- `lib/shared/theme/app_theme.dart` — AppColorsExtension
- `lib/shared/constants/app_constants.dart` — border radius, layout tokens
- `lib/shared/widgets/` — shared widget catalog
- `lib/features/houses/view/houses_screen.dart` — list screen pattern
- `lib/features/trips/view/add_trip_screen.dart` — form screen pattern
- `DESIGN_SYSTEM.md` — documented design rules

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p .claude/skills/ui-design-system
```

- [ ] **Step 2: Write the SKILL.md file**

Create `.claude/skills/ui-design-system/SKILL.md` with the following content:

```markdown
---
name: ui-design-system
description: Use when creating or modifying UI screens, widgets, forms, or bottom sheets. Covers Material 3 theme usage, responsive spacing extensions, shared widget catalog, screen templates (list, detail, form), and design system compliance rules. Activate whenever the task mentions screen, widget, form, bottom sheet, layout, UI, colors, spacing, or creating/modifying a view.
---

# UI Design System — Conventions

## Quando si attiva

Qualunque task che riguardi:
- Creare una nuova schermata (list, detail, form)
- Creare/modificare un widget
- Aggiungere un bottom sheet o form
- Cambiare layout, spacing, colori
- Debug di problemi visual/UI

## Regola zero

**Mai colori o spacing hardcoded.** Se stai scrivendo `Colors.orange`, `EdgeInsets.all(16)`, o `fontSize: 14`, fermati. Usa le extension (`context.spacingMd`, `colorScheme.primary`, `context.fontSizeSm`) e le costanti (`AppConstants.cardBorderRadius`).

## Template: List Screen

```dart
// file: lib/features/<feature>/view/<feature>_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:stuff_tracker_2/shared/theme/app_spacing.dart';
import 'package:stuff_tracker_2/shared/widgets/widgets.dart';
import '../providers/<feature>_provider.dart';

class <Feature>Screen extends ConsumerStatefulWidget {
  const <Feature>Screen({super.key});

  @override
  ConsumerState<<Feature>Screen> createState() => _<Feature>ScreenState();
}

class _<Feature>ScreenState extends ConsumerState<<Feature>Screen> {
  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(<feature>NotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: asyncData.when(
          data: (items) {
            if (items.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(<feature>NotifierProvider.future),
                child: LayoutBuilder(
                  builder: (_, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: EmptyState(
                        icon: Icons.xxx_outlined,
                        title: '<feature>.no_items'.tr(),
                      ),
                    ),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(<feature>NotifierProvider.future),
              color: colorScheme.primary,
              child: ListView.builder(
                padding: EdgeInsets.only(
                  top: context.spacingMd,
                  bottom: context.navBarReservedHeight,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _<Feature>Tile(item: items[index]),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => ErrorState(
            error: error,
            onRetry: () =>
                ref.read(<feature>NotifierProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}
```

Regole:
- `ConsumerStatefulWidget` (o `ConsumerWidget` se non serve stato locale)
- `ref.watch()` per dati, `ref.read()` per azioni
- `AsyncValue.when()` con tutti e tre i branch — mai `.value!`
- `EmptyState` wrappato in `LayoutBuilder` + `SingleChildScrollView` per pull-to-refresh su lista vuota
- `ErrorState` con callback retry
- Padding bottom con `context.navBarReservedHeight` per floating tab bar

## Template: Detail Screen con selezione multipla

```dart
// file: lib/features/<feature>/view/<feature>_detail_screen.dart
class <Feature>DetailScreen extends ConsumerStatefulWidget {
  final String <feature>Id;
  const <Feature>DetailScreen({super.key, required this.<feature>Id});

  @override
  ConsumerState<<Feature>DetailScreen> createState() =>
      _<Feature>DetailScreenState();
}

class _<Feature>DetailScreenState
    extends ConsumerState<<Feature>DetailScreen> {
  final Set<String> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StickyCtaScaffold(
      appBar: DsContextualAppBar(
        normalAppBar: AppBar(title: Text('Titolo')),
        selectionAppBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _selectedIds.clear()),
          ),
          title: Text('${_selectedIds.length} selezionati'),
        ),
        isInSelectionMode: _isSelectionMode,
        switchDuration: const Duration(milliseconds: 220),
      ),
      body: /* lista contenuto */,
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _isSelectionMode
            ? UniversalActionBar(
                key: const ValueKey('selection'),
                primaryLabel: 'Azione bulk',
                onPrimaryPressed: _handleBulkAction,
                leftAction: CircularActionButton(
                  icon: Icons.delete,
                  onPressed: _handleBulkDelete,
                  color: colorScheme.error,
                ),
              )
            : UniversalActionBar(
                key: const ValueKey('normal'),
                primaryLabel: 'Aggiungi',
                onPrimaryPressed: _handleAdd,
              ),
      ),
    );
  }
}
```

Regole:
- `StickyCtaScaffold` per layout con action bar persistente in basso
- `DsContextualAppBar` per switch normal/selection (220ms)
- `AnimatedSwitcher` per bottom bar con `ValueKey` distinte per animazione corretta
- `UniversalActionBar` con slot laterali `CircularActionButton`
- Colore errore da `colorScheme.error`, mai hardcoded

## Template: Form Bottom Sheet

```dart
// file: lib/features/<feature>/view/add_edit_<feature>_sheet.dart

// --- Entry point ---
Future<void> showAddEdit<Feature>Sheet(
  BuildContext context, {
  String? <feature>Id,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddEdit<Feature>Sheet(<feature>Id: <feature>Id),
  );
}

// --- Sheet widget ---
class AddEdit<Feature>Sheet extends ConsumerStatefulWidget {
  final String? <feature>Id;
  const AddEdit<Feature>Sheet({super.key, this.<feature>Id});

  @override
  ConsumerState<AddEdit<Feature>Sheet> createState() =>
      _AddEdit<Feature>SheetState();
}

class _AddEdit<Feature>SheetState
    extends ConsumerState<AddEdit<Feature>Sheet> {
  final GlobalKey<<Feature>FormContentState> _formKey = GlobalKey();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return StandardBottomSheetLayout(
      title: widget.<feature>Id != null
          ? '<feature>.edit'.tr()
          : '<feature>.new'.tr(),
      showDeleteButton: widget.<feature>Id != null,
      onSave: () => _formKey.currentState?.save(),
      onDelete: _handleDelete,
      isLoading: _isLoading,
      child: <Feature>FormContent(
        key: _formKey,
        <feature>Id: widget.<feature>Id,
        onLoadingChanged: (loading) =>
            setState(() => _isLoading = loading),
      ),
    );
  }
}

// --- Form content (widget separato) ---
class <Feature>FormContent extends ConsumerStatefulWidget {
  final String? <feature>Id;
  final ValueChanged<bool> onLoadingChanged;
  const <Feature>FormContent({
    super.key,
    this.<feature>Id,
    required this.onLoadingChanged,
  });

  @override
  ConsumerState<<Feature>FormContent> createState() =>
      <Feature>FormContentState();
}

class <Feature>FormContentState
    extends ConsumerState<<Feature>FormContent> {
  // TextEditingController, form state...

  void save() {
    // validazione + salvataggio via provider
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(/* ... */),
        AppSpacing.gapMd,
        // Picker
        InkWell(
          onTap: () => DsPickerSheet.show<Category>(/* ... */),
          child: /* display valore selezionato */,
        ),
        AppSpacing.gapMd,
        // Toggle
        AppPillTab<bool>(
          items: const [true, false],
          selectedItem: _option,
          getLabel: (b) => b ? 'label_a'.tr() : 'label_b'.tr(),
          onSelected: (b) => setState(() => _option = b),
        ),
        AppSpacing.gapLg,
      ],
    );
  }
}
```

Regole:
- Entry point come funzione top-level `showAddEdit<Feature>Sheet()`
- `StandardBottomSheetLayout` wrappa il form — mai bottom sheet custom con handle manuale
- Form content come widget separato con `GlobalKey` per delegare `save()`
- Gap tra sezioni: `AppSpacing.gapMd` (intra-sezione) / `AppSpacing.gapLg` (inter-sezione)
- Picker: `DsPickerSheet.show<T>()`, mai `showModalBottomSheet` raw
- Tab: `AppPillTab<T>`, mai `SegmentedButton`

## Checklist: Design System Compliance

Ogni widget/screen DEVE rispettare tutte queste regole.

**Spacing:**
- `context.spacingXs` (4), `context.spacingSm` (8), `context.spacingMd` (16), `context.spacingLg` (24)
- Mai `EdgeInsets.all(16)` o `SizedBox(height: 8)` con numeri magic
- Gap tra widget: `AppSpacing.gapSm`, `AppSpacing.gapMd`, `AppSpacing.gapLg`
- Padding orizzontale screen: `context.spacingMd` (= gutter standard 16px)
- Ritmo verticale: `spacingSm` (8) interno al modulo, `spacingMd` (16) tra sezioni, `spacingLg` (24) tra gruppi

**Colori:**
- `colorScheme.primary`, `.secondary`, `.surface`, `.error`, `.onSurface`, `.onSurfaceVariant`
- `context.appColors.xxx` per colori semantici custom (success, itemTemporary)
- Mai `Colors.orange`, `Colors.blue`, `Colors.grey` o qualsiasi `Colors.xxx`
- Opacita' testo: 1.0 (primario), 0.70 (secondario/onSurfaceVariant), 0.50 (terziario), 0.38 (disabled)

**Font size:**
- `context.fontSizeXxs` (12), `context.fontSizeSm` (16), `context.fontSizeMd` (18), ecc.
- Mai `fontSize: 16` hardcoded

**Card e bordi:**
- Padding card: `context.cardPaddingHero` (16) o `context.cardPaddingDense` (8)
- Border radius: `AppConstants.cardBorderRadius` (16), `.pillBorderRadius` (30), `.inputBorderRadius` (12), `.badgeBorderRadius` (8), `.modalBorderRadius` (20)

## Catalogo widget condivisi

Usa il widget condiviso giusto per lo scenario. Mai reimplementare da zero.

| Scenario | Widget | NON usare |
|---|---|---|
| Lista con CTA fisso in basso | `StickyCtaScaffold` | Scaffold custom con Stack |
| AppBar con mode switch | `DsContextualAppBar` | AnimatedSwitcher manuale su AppBar |
| Barra azioni primaria | `UniversalActionBar` | Row custom di bottoni |
| Bottone circolare laterale | `CircularActionButton` | IconButton custom |
| Tab/filtri a pill | `AppPillTab<T>` | `SegmentedButton`, `ChoiceChip` |
| Form in bottom sheet | `StandardBottomSheetLayout` | Bottom sheet custom con handle |
| Picker selezione | `DsPickerSheet<T>` | `showModalBottomSheet` + ListView raw |
| Tile lista universale | `UniversalItemTile` | ListTile o Row custom |
| Stato vuoto | `EmptyState` | Column inline con Icon + Text |
| Stato errore | `ErrorState` | Text('Errore') inline |
| Badge quantita' | `DsQuantityBadge` | Text('x$qty') custom |
| Badge stato | `DsStatusBadge` | Container + Text custom |
| Badge info | `DsInfoBadge` | Row(Icon, Text) custom |
| Stepper quantita' | `QuantityStepper` | Row(IconButton, Text, IconButton) |
| Handle bottom sheet | `BottomSheetHandle` | Container custom |
| Grid selezione icone | `DsIconPicker` | GridView custom |

## Red flags

- `Colors.orange`, `Colors.blue`, qualsiasi `Colors.xxx` fuori da definizioni tema
- `EdgeInsets.all(N)` / `SizedBox(height: N)` con numeri magic (usa spacing extensions)
- `fontSize: N` hardcoded (usa `context.fontSizeXxx`)
- `SegmentedButton` invece di `AppPillTab`
- `showModalBottomSheet` + handle custom invece di `StandardBottomSheetLayout`
- Empty state inline `Column(children: [Icon(size: 80), Text()])` invece di `EmptyState`
- `QuantityStepper` reimplementato inline con bottoni +/-
- `.value!` su AsyncValue senza `.when()`
- `Navigator.push()` / `Navigator.pop()` invece di `context.push()` / `context.pop()`
```

- [ ] **Step 3: Verify the skill file parses correctly**

```bash
head -3 .claude/skills/ui-design-system/SKILL.md
```

Expected output:
```
---
name: ui-design-system
description: Use when creating or modifying UI screens...
```

- [ ] **Step 4: Spot-check templates against real code**

Verify spacing extension exists:

```bash
grep "spacingMd" lib/shared/theme/app_spacing.dart
```

Verify EmptyState widget exists:

```bash
grep -l "class EmptyState" lib/shared/widgets/
```

Verify AppConstants border radius values:

```bash
grep "cardBorderRadius\|pillBorderRadius\|modalBorderRadius" lib/shared/constants/app_constants.dart
```

Verify StandardBottomSheetLayout exists:

```bash
grep -rl "class StandardBottomSheetLayout" lib/shared/widgets/
```

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/ui-design-system/SKILL.md
git commit -m "Add ui-design-system skill for UI pattern enforcement"
```

---

### Task 3: Final verification

**Files:** None (read-only verification)

- [ ] **Step 1: Verify all three skills are discoverable**

```bash
ls -la .claude/skills/*/SKILL.md
```

Expected: three files listed (riverpod-provider, drift-database, ui-design-system).

- [ ] **Step 2: Verify YAML frontmatter is valid for both new skills**

```bash
head -4 .claude/skills/drift-database/SKILL.md
echo "---"
head -4 .claude/skills/ui-design-system/SKILL.md
```

Both should show `---` / `name:` / `description:` / `---`.

- [ ] **Step 3: Commit any final adjustments**

If any fixes were needed, commit them:

```bash
git add .claude/skills/
git commit -m "Fix skill formatting issues"
```

If no fixes needed, skip this step.

# Claude Code Skills: drift-database + ui-design-system

> Due skill per Claude Code che forzano coerenza architetturale quando si aggiungono feature al progetto Stuff Tracker 2.

## Contesto

Il progetto ha pattern Drift e UI ben definiti (CLAUDE.md, ARCHITECTURE.md, DESIGN_SYSTEM.md) ma Claude non li segue in modo consistente. Le due aree con maggiore attrito:

- **Drift/Database**: soft-delete dimenticato, migrazioni incomplete, DAO inconsistenti, TypeConverter saltati
- **UI/Design System**: colori hardcoded, spacing raw, widget shared ignorati a favore di implementazioni inline

La skill `riverpod-provider` esistente risolve il problema per i provider. Servono due skill analoghe per database e UI.

## Decisioni di design

- **Due skill separate** (non una mega-skill): ognuna si attiva nel contesto giusto senza sprecare token
- **Mix template + checklist**: template rigidi per strutture ricorrenti (tabella, DAO, screen), checklist per regole trasversali (spacing, colori)
- **Formato coerente con `riverpod-provider`**: stessa struttura (trigger, template, red flags) per familiarità

---

## Skill 1: `drift-database`

**Posizione**: `.claude/skills/drift-database/SKILL.md`

**Trigger**: task che menziona tabella, DAO, migration, TypeConverter, database schema, o creazione nuova entità con persistenza.

### Sezione 1 — Template: Nuova Tabella Dati

Tabella per entità persistente con soft-delete e sync:

```dart
class XxxTable extends Table with SyncableTable {
  TextColumn get id => text()();
  // ... colonne specifiche dell'entità
  TextColumn get enumField => text().map(const XxxEnumConverter())();
  TextColumn get fkField => text().nullable().references(OtherTable, #id, onDelete: KeyAction.setNull)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => null;

  @override
  List<Index> get indexes => [
    Index('idx_xxx_fk_field', 'CREATE INDEX idx_xxx_fk_field ON xxx(fk_field)'),
  ];
}
```

Regole:
- `id` text PK, mai autoIncrement
- `isDeleted` + `lastSyncedAt` obbligatori su ogni entità dati
- Mixin `SyncableTable` per colonne sync
- Enum sempre mappati via `TextColumn().map(const XxxConverter())`
- FK con `KeyAction.setNull` per relazioni opzionali, `KeyAction.cascade` solo su junction table
- Indici su colonne FK usate in WHERE/JOIN frequenti

### Sezione 1b — Template: Junction Table

```dart
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
- Indice sulla seconda FK (la prima e' coperta dal PK order)

### Sezione 2 — Template: Nuovo DAO

```dart
@DriftAccessor(tables: [XxxTable])
class XxxDao extends DatabaseAccessor<AppDatabase> with _$XxxDaoMixin {
  XxxDao(super.db);

  // READ — sempre filtrare isDeleted
  Future<List<XxxData>> getAll() =>
      (select(xxxTable)..where((t) => t.isDeleted.equals(false))).get();

  Stream<List<XxxData>> watchAll() =>
      (select(xxxTable)..where((t) => t.isDeleted.equals(false))).watch();

  Future<XxxData?> getById(String id) =>
      (select(xxxTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  // SOFT-DELETE
  Future<int> deleteXxx(String id) {
    return (update(xxxTable)..where((t) => t.id.equals(id))).write(
      XxxCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value(SyncStatus.pendingUpdate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // BULK SOFT-DELETE
  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;
    await (update(xxxTable)..where((t) => t.id.isIn(ids))).write(
      XxxCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value(SyncStatus.pendingUpdate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // CASCADE APPLICATIVA (in transaction)
  Future<int> deleteWithCascade(String id) async {
    return transaction(() async {
      final now = DateTime.now();
      // 1. Soft-delete children
      await (update(childTable)
            ..where((c) => c.parentId.equals(id) & c.isDeleted.equals(false)))
          .write(
        ChildCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );
      // 2. Soft-delete parent
      return (update(xxxTable)..where((t) => t.id.equals(id))).write(
        XxxCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value(SyncStatus.pendingUpdate),
          updatedAt: Value(now),
        ),
      );
    });
  }

  // BATCH INSERT
  Future<void> insertMultiple(List<XxxCompanion> items) async {
    await batch((b) => b.insertAll(xxxTable, items));
  }

  // INSERT singolo
  Future<void> insertXxx(XxxCompanion entry) => into(xxxTable).insert(entry);

  // UPDATE
  Future<int> updateXxx(XxxCompanion entry) =>
      (update(xxxTable)..where((t) => t.id.equals(entry.id.value))).write(entry);
}
```

Regole:
- Ogni metodo read filtra `isDeleted.equals(false)`
- Eccezione: `getById` senza filtro solo se serve al sync per trovare record locali
- Delete = update con `isDeleted: true` + `syncStatus: pendingUpdate`
- Cascade e' applicativa in transaction, mai SQL CASCADE per entita' soft-deletable
- Bulk ops con `isIn(ids)` + guard `if (ids.isEmpty) return`
- Batch insert con `batch((b) => b.insertAll(...))`

### Sezione 3 — Template: TypeConverter

```dart
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
- Sempre `orElse` con fallback safe (mai throw su valore sconosciuto)
- Static helpers `toDatabase`/`fromDatabase` per migration e test
- File in `lib/core/database/converters/`

### Sezione 4 — Checklist: Migration

Quando modifichi lo schema (nuova tabella, nuova colonna, cambio tipo):

1. Incrementa `schemaVersion` in `database.dart`
2. Aggiungi blocco `if (from < N)` nel metodo `onUpgrade`
3. Per nuove colonne: usa `m.addColumn(table, table.column)` quando possibile, `customStatement('ALTER TABLE ...')` per casi complessi
4. Per nuove tabelle: usa `m.createTable(newTable)` oppure `customStatement('CREATE TABLE ...')`
5. Registra nuove tabelle nell'annotazione `@DriftDatabase(tables: [...])`
6. Registra nuovi DAO nell'annotazione `@DriftDatabase(daos: [...])`
7. Importa enum e converter esplicitamente in `database.dart` (il `.g.dart` e' part file, non eredita import transitivi)
8. Esegui `dart run build_runner build --delete-conflicting-outputs`
9. Testa con `flutter test` (verifica che le migration non rompano nulla)

### Sezione 5 — Checklist: Repository

Quando crei un repository che usa un DAO:

1. Implementa interface `XxxRepository` con metodi astratti
2. Crea `DriftXxxRepository implements XxxRepository`
3. Metodi `_toModel(DriftData) -> FreezedModel` e `_toCompanion(FreezedModel) -> Companion` per conversione bidirezionale
4. Wrappa chiamate DAO con `_dbService.executeWithRetry()` + `RetryConfig` appropriato
5. Throw `EntitySaveException` per errori di scrittura, `EntityNotFoundException` per entita' non trovate
6. N+1 prevention: batch load + grouping in-memory (`Map<String, List<T>>`), mai loop per singolo ID
7. Per liste con relazioni: `Future.wait([query1, query2])` per parallelizzare, poi match in-memory

### Red Flags

- Physical `delete()` su entita' con soft-delete (deve essere `update` con `isDeleted: true`)
- Read senza filtro `isDeleted.equals(false)` (record eliminati visibili in UI)
- Loop `for (id in ids) await dao.getById(id)` (N+1, usa batch)
- Stringhe raw per enum in colonne (`text()` senza `.map(converter)`)
- Migration senza incremento `schemaVersion`
- CASCADE SQL su entita' soft-deletable (deve essere cascade applicativa in transaction)
- Import mancanti in `database.dart` per enum/converter usati nelle tabelle
- `customStatement` con interpolazione di valori utente (SQL injection — usa parametri)

---

## Skill 2: `ui-design-system`

**Posizione**: `.claude/skills/ui-design-system/SKILL.md`

**Trigger**: task che menziona screen, widget, form, bottom sheet, layout, UI, colori, spacing, o creazione/modifica di una vista.

### Sezione 1 — Template: List Screen

```dart
class XxxScreen extends ConsumerStatefulWidget {
  const XxxScreen({super.key});

  @override
  ConsumerState<XxxScreen> createState() => _XxxScreenState();
}

class _XxxScreenState extends ConsumerState<XxxScreen> {
  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(xxxNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: asyncData.when(
          data: (items) {
            if (items.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async => ref.refresh(xxxNotifierProvider.future),
                child: LayoutBuilder(
                  builder: (_, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: EmptyState(
                        icon: Icons.xxx_outlined,
                        title: 'xxx.no_items'.tr(),
                      ),
                    ),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(xxxNotifierProvider.future),
              color: colorScheme.primary,
              child: ListView.builder(
                padding: EdgeInsets.only(
                  top: context.spacingMd,
                  bottom: context.navBarReservedHeight,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => _XxxTile(item: items[index]),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => ErrorState(
            error: error,
            onRetry: () => ref.read(xxxNotifierProvider.notifier).refresh(),
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
- `EmptyState` wrappato in `LayoutBuilder` + `SingleChildScrollView` per pull-to-refresh
- `ErrorState` con callback retry
- Padding bottom con `context.navBarReservedHeight` per floating tab bar

### Sezione 2 — Template: Detail Screen con Selezione Multipla

```dart
class XxxDetailScreen extends ConsumerStatefulWidget {
  final String xxxId;
  const XxxDetailScreen({super.key, required this.xxxId});

  @override
  ConsumerState<XxxDetailScreen> createState() => _XxxDetailScreenState();
}

class _XxxDetailScreenState extends ConsumerState<XxxDetailScreen> {
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
- `StickyCtaScaffold` per layout con action bar persistente
- `DsContextualAppBar` per switch normal/selection (220ms)
- `AnimatedSwitcher` per bottom bar con `ValueKey` per animazione corretta
- `UniversalActionBar` con slot laterali `CircularActionButton`
- Colore errore da `colorScheme.error`, mai hardcoded

### Sezione 3 — Template: Form Bottom Sheet

```dart
// Entry point
Future<void> showAddEditXxxSheet(
  BuildContext context, {
  String? xxxId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddEditXxxSheet(xxxId: xxxId),
  );
}

// Sheet widget
class AddEditXxxSheet extends ConsumerStatefulWidget {
  final String? xxxId;
  const AddEditXxxSheet({super.key, this.xxxId});

  @override
  ConsumerState<AddEditXxxSheet> createState() => _AddEditXxxSheetState();
}

class _AddEditXxxSheetState extends ConsumerState<AddEditXxxSheet> {
  final GlobalKey<XxxFormContentState> _formKey = GlobalKey();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return StandardBottomSheetLayout(
      title: widget.xxxId != null ? 'xxx.edit'.tr() : 'xxx.new'.tr(),
      showDeleteButton: widget.xxxId != null,
      onSave: () => _formKey.currentState?.save(),
      onDelete: _handleDelete,
      isLoading: _isLoading,
      child: XxxFormContent(
        key: _formKey,
        xxxId: widget.xxxId,
        onLoadingChanged: (loading) => setState(() => _isLoading = loading),
      ),
    );
  }
}

// Form content (widget separato)
class XxxFormContent extends ConsumerStatefulWidget { /* ... */ }

class XxxFormContentState extends ConsumerState<XxxFormContent> {
  // Controllers, form state...

  void save() { /* validazione + salvataggio via provider */ }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(/* ... */),
        AppSpacing.gapMd,
        // Picker esempio
        InkWell(
          onTap: () => DsPickerSheet.show<Category>(/* ... */),
          child: /* display selezionato */,
        ),
        AppSpacing.gapMd,
        // Toggle esempio
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
- Entry point come funzione top-level `showAddEditXxxSheet()`
- `StandardBottomSheetLayout` wrappa il form — mai bottom sheet custom
- Form content come widget separato con `GlobalKey` per delegare `save()`
- Gap tra sezioni: `AppSpacing.gapMd` (intra-sezione) / `AppSpacing.gapLg` (inter-sezione)
- Picker: `DsPickerSheet.show<T>()`, mai `showModalBottomSheet` raw
- Tab: `AppPillTab<T>`, mai `SegmentedButton`

### Sezione 4 — Checklist: Design System Compliance

Ogni widget/screen DEVE rispettare:

**Spacing**:
- `context.spacingXs` (4), `context.spacingSm` (8), `context.spacingMd` (16), `context.spacingLg` (24)
- Mai `EdgeInsets.all(16)` o `SizedBox(height: 8)` con numeri magic
- Gap tra widget: `AppSpacing.gapSm`, `AppSpacing.gapMd`, `AppSpacing.gapLg`
- Padding orizzontale screen: `context.spacingMd` (= 16, gutter standard)

**Colori**:
- `colorScheme.primary`, `.secondary`, `.surface`, `.error`, `.onSurface`, `.onSurfaceVariant`
- `context.appColors.xxx` per colori semantici custom (success, itemTemporary)
- Mai `Colors.orange`, `Colors.blue`, `Colors.grey` o qualsiasi `Colors.xxx`
- Opacita' testo: 1.0 (primario), 0.70 (secondario/onSurfaceVariant), 0.50 (terziario), 0.38 (disabled)

**Font size**:
- `context.fontSizeXxs` (12), `context.fontSizeSm` (16), `context.fontSizeMd` (18), ecc.
- Mai `fontSize: 16` hardcoded

**Card e bordi**:
- Padding: `context.cardPaddingHero` (16) o `context.cardPaddingDense` (8)
- Border radius: `AppConstants.cardBorderRadius` (16), `.pillBorderRadius` (30), `.inputBorderRadius` (12), `.badgeBorderRadius` (8), `.modalBorderRadius` (20)

**Regola verticale**:
- `spacingSm` (8) = spacing interno al modulo
- `spacingMd` (16) = spacing tra sezioni
- `spacingLg` (24) = spacing tra gruppi

### Sezione 5 — Catalogo Widget Condivisi

| Scenario | Widget | NON usare |
|---|---|---|
| Lista con CTA fisso in basso | `StickyCtaScaffold` | Scaffold custom con Stack |
| AppBar con mode switch | `DsContextualAppBar` | AnimatedSwitcher manuale su AppBar |
| Barra azioni primaria | `UniversalActionBar` | Row custom di bottoni |
| Bottone circolare laterale | `CircularActionButton` | IconButton custom |
| Tab/filtri a pill | `AppPillTab<T>` | `SegmentedButton`, `ChoiceChip` custom |
| Form in bottom sheet | `StandardBottomSheetLayout` | Bottom sheet custom con handle |
| Picker selezione | `DsPickerSheet<T>` | `showModalBottomSheet` + ListView raw |
| Tile lista universale | `UniversalItemTile` | ListTile diretto o Row custom |
| Stato vuoto | `EmptyState` | Column inline con Icon + Text |
| Stato errore | `ErrorState` | Text('Errore') inline |
| Badge quantita' | `DsQuantityBadge` | Text('x$qty') custom |
| Badge stato | `DsStatusBadge` | Container + Text custom |
| Badge info | `DsInfoBadge` | Row(Icon, Text) custom |
| Stepper quantita' | `QuantityStepper` | Row con IconButton(-) + Text + IconButton(+) |
| Handle bottom sheet | `BottomSheetHandle` | Container custom |
| Grid selezione icone | `DsIconPicker` | GridView custom |

### Red Flags

- `Colors.orange`, `Colors.blue`, qualsiasi `Colors.xxx` fuori da definizioni tema
- `EdgeInsets.all(N)` / `SizedBox(height: N)` con numeri magic (usa spacing extensions)
- `fontSize: N` hardcoded (usa `context.fontSizeXxx`)
- `SegmentedButton` invece di `AppPillTab`
- `showModalBottomSheet` + handle custom invece di `StandardBottomSheetLayout`
- Empty state inline `Column(children: [Icon(size: 80), Text()])` invece di `EmptyState`
- `QuantityStepper` reimplementato inline
- `.value!` su AsyncValue senza `.when()`
- `Theme.of(context).textTheme.xxx` con override fontSize (usa le extensions)
- `Navigator.push()` / `Navigator.pop()` invece di `context.push()` / `context.pop()`

---

## Struttura file

```
.claude/
  skills/
    riverpod-provider/    # esistente
      SKILL.md
    drift-database/       # nuova
      SKILL.md
    ui-design-system/     # nuova
      SKILL.md
```

## Trigger summary

| Skill | Si attiva quando |
|---|---|
| `riverpod-provider` | provider, notifier, AsyncValue, ref.watch/read, state management |
| `drift-database` | tabella, DAO, migration, TypeConverter, schema, nuova entita' persistente |
| `ui-design-system` | screen, widget, form, bottom sheet, layout, UI, colori, spacing, vista |

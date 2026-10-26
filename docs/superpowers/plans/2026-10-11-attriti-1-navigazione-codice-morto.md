# Attriti UI 1 · Navigazione e codice morto — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chiudere gli attriti #1, #2, #3 e #5 di `docs/ui-flows.md`: eliminare la creazione guidata da template e la modifica viaggio a pagina singola (con tutto il codice morto a cascata), far tornare indietro davvero la freccia del dettaglio casa, e dare al bottone "Gestisci casa" un'icona che non prometta "modifica".

**Architecture:** Sono rimozioni e ritocchi locali, senza cambi di schema né di contratti di repository/DAO. L'unico codice nuovo è un'estensione `popOrGo` su `BuildContext` in `lib/shared/helpers/`, testabile da sola con un `GoRouter` minimo. Il primo task porta nel branch l'harness degli screenshot (`test/screenshots/`), che serve a tutti e quattro i piani per confrontare prima e dopo.

**Tech Stack:** Flutter 3.38.5, GoRouter 14, Riverpod 2.5 (`riverpod_annotation`), easy_localization.

**Decisioni prese (conversazione del 2026-10-11):**
- #1: la creazione da template si **elimina** del tutto (cartella, test, rotte, traduzioni, documentazione, sezioni di `CLAUDE.md`).
- #2: la rotta `/trips/:id/edit` si elimina, **e con lei tutto il codice che diventa morto** (modalità modifica di `AddTripScreen`, ramo `shrinkWrap` di `TripItemsSelector`, chiavi di traduzione rimaste orfane).
- #3: la freccia torna indietro con `pop`; se non c'è nulla sotto nello stack va alla home.
- #5: il comportamento resta (apre il menu "Gestisci casa"), cambia solo l'icona: `Icons.more_horiz`.

## Global Constraints

- Branch di lavoro: `fix/ui-frictions` (creato da `origin/main`, **senza upstream**: non fare `git push` senza indicare il remoto e il branch).
- Flutter **3.38.5** (quella della CI). Con versioni più recenti `build_runner` fallisce.
- Niente `git worktree add` (vincolo di `CLAUDE.md`).
- Navigazione: `push` per aprire, `pop` per tornare, `go(tab)` solo per cambio tab dopo una creazione, `go('/')` solo per il recupero dopo un'azione distruttiva o un errore.
- Testi UI **solo** via `.tr()`, con la chiave sia in `assets/translations/it-IT.json` sia in `en-US.json`. Le due traduzioni si modificano con lo script Python indicato (il round-trip `json.dumps(indent=2, ensure_ascii=False)` + newline finale è identico byte per byte ai file attuali: non riformatta nulla).
- I test dei widget non asseriscono su testo tradotto: senza `EasyLocalization` inizializzato `.tr()` restituisce la chiave. Si cerca per `Key`, tipo o icona.
- Prima di ogni commit: `dart format lib/ test/`, `dart analyze` pulito, test della feature toccata verdi.
- Commit appena analyze e test sono verdi (preferenza dell'utente), messaggi in stile conventional commit in italiano, chiusi da `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `ARCHITECTURE.md` si aggiorna solo dove cambia un pattern, una rotta o un contratto (qui: rotte, feature list, policy di navigazione). Nessun nuovo file `.md` di documentazione.

## File Structure

**Creati**

| File | Responsabilità |
|---|---|
| `lib/shared/helpers/navigation_helpers.dart` | Estensione `PopOrGo` su `BuildContext`: `pop` se possibile, altrimenti `go(fallback)` |
| `test/shared/helpers/navigation_helpers_test.dart` | I due rami di `popOrGo` con un `GoRouter` minimo |

**Portati dal branch `ui-screenshots`** (cherry-pick di `ac53245`)

| File | Responsabilità |
|---|---|
| `test/screenshots/**` | Harness che fotografa tutte le schermate in `build/ui-screenshots/` |
| `docs/ui-flows.md` | Mappa dei flussi e degli attriti (riferimento per tutti i piani) |

**Eliminati**

| File | Motivo |
|---|---|
| `lib/features/bulk_creation/` (intera cartella) | #1 |
| `test/features/bulk_creation/` (intera cartella) | #1 |

**Modificati**

| File | Cosa cambia |
|---|---|
| `lib/core/routing/app_router.dart` | Via le tre rotte `/bulk-creation/*`, la rotta `/trips/:id/edit` e i tre import di `bulk_creation` |
| `lib/features/trips/view/add_trip_screen.dart` | Solo creazione: via `tripId`, `_loadTrip`, ramo di modifica, `_isWizard`, `_buildItemsAndLuggages` |
| `lib/features/trips/view/trip_items_selector.dart` | Via `shrinkWrap`, `_buildItemsListShrinkWrap`, `_buildEmptyHouseStateShrinkWrap` |
| `lib/features/trips/view/edit_trip_items_screen.dart` | Via l'argomento `shrinkWrap: false` |
| `lib/features/houses/view/house_detail_screen.dart` | Freccia → `popOrGo('/')`; icona `Icons.edit` → `Icons.more_horiz` |
| `lib/shared/theme/app_spacing.dart`, `lib/shared/widgets/universal_item_tile.dart` | Commenti che citano `BulkItemRow` |
| `assets/translations/it-IT.json`, `en-US.json` | Via `bulk_creation.*`, `trips.edit`, `errors.invalid_list_id` |
| `ARCHITECTURE.md`, `CLAUDE.md`, `.claude/agents/code-reviewer.md`, `.claude/commands/arch-review.md` | Via i riferimenti alla creazione da template e alla rotta `/trips/:id/edit` |

---

### Task 1: Harness degli screenshot nel branch e foto "prima"

**Files:**
- Aggiunti da cherry-pick: `test/screenshots/**`, `docs/ui-flows.md`

**Interfaces:**
- Produces: il comando `flutter test test/screenshots --dart-define=UI_SCREENSHOTS=true`, che scrive `build/ui-screenshots/<flusso>/*.png` e `build/ui-screenshots/manifest.json`. Lo usano tutti i piani per il confronto prima/dopo.

- [ ] **Step 1: Cherry-pick del commit dell'harness**

```bash
git fetch origin ui-screenshots
git cherry-pick ac53245
```

Expected: un commit con 6 file (`docs/ui-flows.md` + 5 sotto `test/screenshots/`), nessun conflitto: il commit ha come genitore `d502974`, cioè `origin/main`.

- [ ] **Step 2: Controllare la versione di Flutter e rigenerare**

```bash
flutter --version | head -1
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Expected: `Flutter 3.38.5 • channel stable`; build_runner termina con `Built with build_runner`.

- [ ] **Step 3: Foto "prima" di tutto il percorso**

```bash
flutter test test/screenshots --dart-define=UI_SCREENSHOTS=true
rm -rf build/ui-screenshots-before && cp -R build/ui-screenshots build/ui-screenshots-before
```

Expected: `All tests passed!` e 132 PNG in `build/ui-screenshots-before/`. Questa cartella resta come riferimento "prima" per tutti i piani (è sotto `build/`, quindi fuori da git).

- [ ] **Step 4: Verificare che i test normali restino veloci**

Run: `flutter test test/screenshots`
Expected: i test risultano *skipped* (senza `UI_SCREENSHOTS=true` l'harness è spento).

Il cherry-pick è già un commit: niente da committare in questo task.

---

### Task 2: Eliminare la creazione guidata da template (#1)

**Files:**
- Delete: `lib/features/bulk_creation/`, `test/features/bulk_creation/`
- Modify: `lib/core/routing/app_router.dart:28-30` (import), `:294-323` (rotte)
- Modify: `assets/translations/it-IT.json`, `assets/translations/en-US.json` (namespace `bulk_creation`)
- Modify: `lib/shared/theme/app_spacing.dart:55`, `lib/shared/widgets/universal_item_tile.dart:10,75-76,212`
- Modify: `ARCHITECTURE.md`, `CLAUDE.md`, `.claude/agents/code-reviewer.md`, `.claude/commands/arch-review.md`
- Modify: `test/screenshots/ui_screenshots_test.dart` (flusso `11-creazione-guidata`)

**Interfaces:**
- Consumes: niente.
- Produces: nessuna rotta `/bulk-creation/*`; `ItemRepository.insertMultipleItems` **resta** (la usano `MigrationService` e `AiImportNotifier`).

- [ ] **Step 1: Verificare che la feature sia isolata**

Run:
```bash
grep -rln "bulk_creation\|UserGender\|kTravelTemplates\|BulkItemRow" lib test | grep -v "^lib/features/bulk_creation/\|^test/features/bulk_creation/"
```
Expected: solo `lib/core/routing/app_router.dart`, `lib/shared/theme/app_spacing.dart` e `lib/shared/widgets/universal_item_tile.dart`. (`test/screenshots/` cita le rotte `/bulk-creation/*` come stringhe, senza importare la feature: si sistema allo Step 5.) Se compare altro, fermarsi e capire chi lo usa prima di cancellare.

- [ ] **Step 2: Cancellare cartelle e test**

```bash
git rm -r lib/features/bulk_creation test/features/bulk_creation
```

- [ ] **Step 3: Togliere import e rotte dal router**

In `lib/core/routing/app_router.dart` eliminare queste tre righe di import:

```dart
import '../../features/bulk_creation/view/house_selection_screen.dart';
import '../../features/bulk_creation/view/template_selection_screen.dart';
import '../../features/bulk_creation/view/bulk_item_list_screen.dart';
```

e questi tre `GoRoute` (subito prima di `'/dev/ds-showcase'`):

```dart
      GoRoute(
        path: '/bulk-creation/select-house',
        name: 'bulk-house-selection',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HouseSelectionScreen(),
      ),
      GoRoute(
        path: '/bulk-creation/templates/:houseId',
        name: 'bulk-template-selection',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final houseId = state.pathParameters['houseId'];
          if (houseId == null || houseId.isEmpty) {
            return _ErrorScreen(message: 'errors.invalid_house_id'.tr());
          }
          return TemplateSelectionScreen(houseId: houseId);
        },
      ),
      GoRoute(
        path: '/bulk-creation/items/:houseId',
        name: 'bulk-item-list',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final houseId = state.pathParameters['houseId'];
          if (houseId == null || houseId.isEmpty) {
            return _ErrorScreen(message: 'errors.invalid_house_id'.tr());
          }
          return BulkItemListScreen(houseId: houseId);
        },
      ),
```

`errors.invalid_house_id` resta: la usano anche `/houses/:id` e le rotte AI.

- [ ] **Step 4: Togliere il namespace `bulk_creation` dalle traduzioni**

```bash
python3 - <<'EOF'
import json
for f in ("it-IT", "en-US"):
    p = f"assets/translations/{f}.json"
    d = json.load(open(p, encoding="utf-8"))
    d.pop("bulk_creation")
    open(p, "w", encoding="utf-8").write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
EOF
git diff --stat assets/translations
```

Expected: due file, solo righe rimosse.

- [ ] **Step 5: Togliere il flusso 11 dall'harness degli screenshot**

In `test/screenshots/ui_screenshots_test.dart` eliminare l'intero `Flow('11-creazione-guidata', …)` (circa righe 936-966: i due `Scenario` `scelta-casa` e `template`, dalla riga `Flow(` alla `),` che lo chiude). Il flusso `12-errori` mantiene il suo numero, così i nomi delle cartelle restano allineati al file Figma. Poi:

Run: `grep -n "bulk-creation\|bulk_creation\|11-creazione" test/screenshots -r`
Expected: nessun risultato.

- [ ] **Step 6: Aggiornare i commenti di codice**

`lib/shared/theme/app_spacing.dart:55`:
```dart
  /// Padding semantico per item ad alta frequenza in lista (UniversalItemTile, ListTile).
```

`lib/shared/widgets/universal_item_tile.dart`: eliminare la riga 10
```dart
/// - `BulkItemRow` (bulk creation): TextField inline + stepper + delete
```
alle righe 74-76 sostituire
```dart
  /// il bordo è semantico (selezione in `TripItemsSelector`, riquadro in
  /// `BulkItemRow`) e la tile resta un contenitore riquadrato.
```
con
```dart
  /// il bordo è semantico (selezione in `TripItemsSelector`) e la tile resta
  /// un contenitore riquadrato.
```
e alla riga 212
```dart
  /// Layout personalizzato usando Row (TripItemSelector)
```

- [ ] **Step 7: Aggiornare `ARCHITECTURE.md`**

- Riga 37: eliminare `6. **Bulk Item Creation**: …` e rinumerare i punti 7-9 in 6-8.
- Riga 61: eliminare `│   └── bulk_creation/` e cambiare la riga precedente `│   ├── luggages/` in `│   └── luggages/`.
- Riga 456: `(migration & bulk creation)` → `(migration & AI import)`.
- Righe 530-532: eliminare le tre righe `/bulk-creation/...`.
- Riga 544, colonna Examples: `House detail, Trip detail, Edit screens, Bulk creation steps` → `House detail, Trip detail, Edit screens`.
- Riga 545, colonna Examples: `EditTripInfoScreen, EditTripItemsScreen, TemplateSelectionScreen, BulkItemListScreen` → `EditTripInfoScreen, EditTripItemsScreen`.
- Tabella "Regole Architetturali dei Widget Condivisi" (riga ~2040, `UniversalItemTile`): `(ItemCard, InTransitItemCard, BulkItemRow, TripItemCard, trip item selector)` → `(ItemCard, InTransitItemCard, TripItemCard, trip item selector)`.
- Eliminare tutta la sezione `### Bulk Creation Feature (lib/features/bulk_creation/)` fino al `---` che precede `## Sync Engine` compreso:

```bash
python3 - <<'EOF'
p = "ARCHITECTURE.md"
s = open(p, encoding="utf-8").read()
start = s.index("### Bulk Creation Feature (`lib/features/bulk_creation/`)")
end = s.index("## Sync Engine (`lib/core/sync/`)")
open(p, "w", encoding="utf-8").write(s[:start] + s[end:])
EOF
grep -n -i "bulk.creation\|BulkItem\|UserGender\|TemplateSelection" ARCHITECTURE.md
```

Expected: nessun risultato.

- [ ] **Step 8: Aggiornare `CLAUDE.md` e gli strumenti di review**

`CLAUDE.md`:
- Riga 7: `Feature hero: **bulk item creation** da template (con gender filter e merge/sum logic) e **AI clothing import** (GPT vision).` → `Feature hero: **AI clothing import** (GPT vision).`
- Riga 30: `│   ├── houses/ items/ trips/ spaces/ luggages/ bulk_creation/ profile/` → `│   ├── houses/ items/ trips/ spaces/ luggages/ profile/`
- Eliminare l'intera sezione `### Bulk creation (feature top-of-mind)` (6 punti elenco, righe 127-133).
- Riga 213: `sempre ItemCategory, LuggageSize, LocationType, UserGender` → `sempre ItemCategory, LuggageSize, LocationType`.
- Eliminare la riga 217 `- ❌ Ordinamento alfabetico degli item nel bulk creation → sempre insertionIndex`.
- Riga 233: `Se tocchi bulk_creation, db schema, o pattern snapshot` → `Se tocchi db schema o pattern snapshot`.

`.claude/agents/code-reviewer.md`: eliminare la sezione `### F. Se bulk_creation` (4 punti) e rinominare `### G. Concurrency / side-effects` in `### F. Concurrency / side-effects` (e le lettere successive, se ce ne sono).

`.claude/commands/arch-review.md`: eliminare la sezione `### 8. Se tocca bulk_creation` (3 punti).

Run: `grep -n -i "bulk_creation\|bulk creation\|insertionIndex\|BulkItemRow\|UserGender" CLAUDE.md .claude/agents/code-reviewer.md .claude/commands/arch-review.md`
Expected: nessun risultato.

- [ ] **Step 9: Rigenerare, analizzare, testare**

```bash
dart run build_runner build --delete-conflicting-outputs
dart format lib/ test/
dart analyze
flutter test
```

Expected: analyze `No issues found!`; tutti i test passano (il numero totale scende dei test di `bulk_creation_notifier_test.dart`).

- [ ] **Step 10: Commit**

```bash
git add -A lib test assets ARCHITECTURE.md CLAUDE.md .claude/agents/code-reviewer.md .claude/commands/arch-review.md
git commit -m "refactor: elimina la creazione guidata da template

Le rotte /bulk-creation/* erano registrate ma nessun punto della UI ci
portava. Via feature, test, rotte, traduzioni e documentazione.
insertMultipleItems resta: la usano migrazione e import AI.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Eliminare `/trips/:id/edit` e il codice morto a cascata (#2)

**Files:**
- Modify: `lib/core/routing/app_router.dart:258-269`
- Modify: `lib/features/trips/view/add_trip_screen.dart`
- Modify: `lib/features/trips/view/trip_items_selector.dart:28-36,127-138,266-341,345-351`
- Modify: `lib/features/trips/view/edit_trip_items_screen.dart:148`
- Modify: `assets/translations/it-IT.json`, `en-US.json` (`trips.edit`, `errors.invalid_list_id`)
- Modify: `ARCHITECTURE.md:527`
- Test: `test/features/trips/view/add_trip_screen_validation_test.dart` (esistente, deve restare verde)

**Interfaces:**
- Consumes: niente.
- Produces: `const AddTripScreen({super.key})` senza parametri; `TripItemsSelector({required selectedItems, required onSelectionChanged})` senza `shrinkWrap`.

- [ ] **Step 1: Confermare che nessuno usa la rotta né la modalità modifica**

Run:
```bash
grep -rn "trip-edit'\|/edit'\|AddTripScreen(tripId\|shrinkWrap:" lib test | grep "\.dart:" | grep -v "ai_results_screen\|item_form_content\|location_autocomplete_field"
```
Expected: solo `app_router.dart` (la rotta e `AddTripScreen(tripId: id)`) e `edit_trip_items_screen.dart` (`shrinkWrap: false`). Le rotte `edit-info` ed `edit-items` non c'entrano.

- [ ] **Step 2: Togliere la rotta**

In `lib/core/routing/app_router.dart` eliminare:

```dart
      GoRoute(
        path: '/trips/:id/edit',
        name: 'trip-edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return _ErrorScreen(message: 'errors.invalid_list_id'.tr());
          }
          return AddTripScreen(tripId: id);
        },
      ),
```

- [ ] **Step 3: `AddTripScreen` solo creazione**

In `lib/features/trips/view/add_trip_screen.dart`:

Il widget diventa:
```dart
class AddTripScreen extends ConsumerStatefulWidget {
  const AddTripScreen({super.key});

  @override
  ConsumerState<AddTripScreen> createState() => _AddTripScreenState();
}
```

Sostituire il blocco da `/// Passo del wizard. Vale solo in creazione…` fino a `bool get _isWizard => widget.tripId == null;` con:
```dart
  /// Passo del wizard: 0 = dati del viaggio, 1 = oggetti e bagagli.
  int _step = 0;
```

Eliminare `initState()` e `_loadTrip()` per intero (righe 66-93).

In `_saveTrip()` sostituire tutto da `final now = DateTime.now();` fino alla fine dell'`executeWithRetry` con:
```dart
    final now = DateTime.now();
    final trip = TripModel(
      id: const Uuid().v4(),
      name: _effectiveName,
      description: _description,
      items: _selectedItems,
      luggages: _selectedLuggages,
      legs: _legs,
      departureDateTime: _departureDateTime,
      returnDateTime: _returnDateTime,
      destinationHouseId: _destinationHouseId,
      destinationLocation: _destinationHouseId == null
          ? _destinationLocation
          : (_destinationName?.isNotEmpty == true
                ? LocationSuggestionModel(
                    placeId: '',
                    displayName: _destinationName!,
                  )
                : null),
      createdAt: now,
      updatedAt: now,
    );

    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => ref.read(tripNotifierProvider.notifier).addTrip(trip),
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: 'errors.create_trip_failed'.tr(),
    );
```

`_ctaLabel()` diventa:
```dart
  String _ctaLabel() {
    if (_step == 0) return 'common.next'.tr();
    return _selectedItems.isEmpty
        ? 'trips.create_trip'.tr()
        : 'trips.create_trip_with_count'.tr(
            args: [_selectedItems.length.toString()],
          );
  }
```

In `_onPrimaryPressed()`: `if (_isWizard && _step == 0) {` → `if (_step == 0) {`.

In `build()`:
- `canPop: !(_isWizard && _step == 1),` → `canPop: _step == 0,`
- il titolo diventa `title: Text('trips.add_new'.tr()),`
- `bottom: _isWizard ? PreferredSize(…) : null,` → solo `bottom: PreferredSize(…),` (stesso contenuto, senza ternario)
- `builder: (context) => _isWizard && _step == 1` → `builder: (context) => _step == 1`
- `primaryIcon: _isWizard && _step == 0` → `primaryIcon: _step == 0`

In `_buildInfoStep()`: il commento diventa `/// Passo 1: dati del viaggio e tappe.` ed eliminare il blocco
```dart
            if (!_isWizard) ...[
              SizedBox(height: context.spacingLg),
              _buildItemsAndLuggages(context),
            ],
```

Eliminare il metodo `_buildItemsAndLuggages()` per intero (righe 360-405).

Run: `grep -n "tripId\|_isWizard\|isEditing\|updateTrip\|_buildItemsAndLuggages\|shrinkWrap" lib/features/trips/view/add_trip_screen.dart`
Expected: nessun risultato.

In `test/features/trips/view/trip_info_form_name_test.dart` il commento di `pushName` cita `add_trip_screen._loadTrip in modifica`, che non esiste più: sostituire con `come fa edit_trip_info_screen quando carica il viaggio`.

- [ ] **Step 4: `TripItemsSelector` senza `shrinkWrap`**

In `lib/features/trips/view/trip_items_selector.dart`:
- eliminare il campo e il parametro:
```dart
  /// Se true, il widget si adatta al contenuto (per uso in scroll parent)
  final bool shrinkWrap;
```
```dart
    this.shrinkWrap = false,
```
- in `build()` eliminare il ramo
```dart
    if (widget.shrinkWrap) {
      // Modalità shrinkWrap per embedding in scroll parent
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilters(context, colorScheme, housesAsync),
          SizedBox(height: context.spacingSm),
          _buildItemsListShrinkWrap(context, colorScheme),
        ],
      );
    }
```
- eliminare per intero `_buildItemsListShrinkWrap(...)` e `_buildEmptyHouseStateShrinkWrap(...)` (righe 266-341).
- `_buildNoItemsState` resta (lo usa `_buildNoItemsStateScrollable`): nel suo commento sostituire il paragrafo
```dart
  /// Nessuno scroll qui: usato dal ramo shrinkWrap, il cui genitore è già uno
  /// `SingleChildScrollView` senza altezza vincolata. Annidarne un altro
  /// romperebbe con "unbounded height".
```
con
```dart
  /// Nessuno scroll qui: lo aggiunge [_buildNoItemsStateScrollable].
```
e nel commento di `_buildNoItemsStateScrollable` sostituire `/// Usato dal ramo non-shrinkWrap, che al passo 2 del wizard vive dentro un` con `/// Al passo 2 del wizard il selettore vive dentro un`.

In `lib/features/trips/view/edit_trip_items_screen.dart` eliminare la riga `          shrinkWrap: false,`.

- [ ] **Step 5: Chiavi di traduzione orfane**

Run:
```bash
grep -rn "'trips.edit'\|'errors.invalid_list_id'" lib | grep "\.dart:"
```
Expected: nessun risultato (`trips.edit` era solo nel titolo di `AddTripScreen`, `errors.invalid_list_id` solo nella rotta eliminata).

```bash
python3 - <<'EOF'
import json
for f in ("it-IT", "en-US"):
    p = f"assets/translations/{f}.json"
    d = json.load(open(p, encoding="utf-8"))
    d["trips"].pop("edit")
    d["errors"].pop("invalid_list_id")
    open(p, "w", encoding="utf-8").write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
EOF
```

- [ ] **Step 6: `ARCHITECTURE.md`**

Eliminare la riga 527: `    - /trips/:id/edit → AddTripScreen (edit mode)`. Alla riga 526 `(new trip)` resta.

Run: `grep -n "trips/:id/edit\b\|edit mode\|shrinkWrap" ARCHITECTURE.md`
Expected: solo le righe di `edit-info` ed `edit-items`, se il pattern le prende; nessuna riga su `edit mode`.

- [ ] **Step 7: Analizzare e testare**

```bash
dart format lib/ test/
dart analyze
flutter test test/features/trips/
```

Expected: analyze pulito; `add_trip_screen_validation_test.dart`, `trip_info_form_name_test.dart` e `trip_items_selector_empty_test.dart` verdi.

- [ ] **Step 8: Commit**

```bash
git add -A lib test assets ARCHITECTURE.md
git commit -m "refactor: elimina la modifica viaggio a pagina singola

/trips/:id/edit non era raggiungibile: dal dettaglio si modifica da
edit-info ed edit-items. Via la rotta, la modalità modifica di
AddTripScreen, il ramo shrinkWrap di TripItemsSelector e le chiavi
di traduzione rimaste orfane.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: La freccia del dettaglio casa torna indietro (#3)

**Files:**
- Create: `lib/shared/helpers/navigation_helpers.dart`
- Test: `test/shared/helpers/navigation_helpers_test.dart`
- Modify: `lib/features/houses/view/house_detail_screen.dart:521`

**Interfaces:**
- Produces: `extension PopOrGo on BuildContext { void popOrGo(String fallback) }`.

**Perché non basta `context.pop()`:** il dettaglio casa si apre con `push` dalla lista case, ma anche con `go('/houses/<id>')` dopo il salvataggio dell'import AI (`ai_results_screen.dart:256`, `:374`). In quel caso sotto non c'è nulla e `pop()` lancerebbe un'eccezione. La riga `:356` (bottone "Torna alle case" della schermata "casa non trovata") resta `go('/')`: è recupero da errore, il caso previsto dalla policy di navigazione.

- [ ] **Step 1: Scrivere il test che fallisce**

`test/shared/helpers/navigation_helpers_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pack_log/shared/helpers/navigation_helpers.dart';

GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const Text('home')),
    GoRoute(path: '/other', builder: (_, _) => const Text('other')),
    GoRoute(
      path: '/detail',
      builder: (_, _) => Builder(
        builder: (context) => TextButton(
          key: const Key('back'),
          onPressed: () => context.popOrGo('/'),
          child: const Text('detail'),
        ),
      ),
    ),
  ],
);

void main() {
  testWidgets('con uno stack sotto torna alla pagina precedente', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/other');
    await tester.pumpAndSettle();
    router.push('/detail');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();

    expect(find.text('other'), findsOneWidget);
    expect(find.text('home'), findsNothing);
  });

  testWidgets('senza stack sotto va al fallback invece di fallire', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/detail');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Eseguirlo e vederlo fallire**

Run: `flutter test test/shared/helpers/navigation_helpers_test.dart`
Expected: FAIL in compilazione, `navigation_helpers.dart` non esiste / `popOrGo` non definito.

- [ ] **Step 3: Implementare l'helper**

`lib/shared/helpers/navigation_helpers.dart`:
```dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension PopOrGo on BuildContext {
  /// Torna alla pagina precedente. Se sotto non c'è nulla (la pagina è stata
  /// aperta con `go`, ad esempio dopo un salvataggio o da un deep link) va a
  /// [fallback] invece di lanciare un'eccezione.
  void popOrGo(String fallback) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}
```

- [ ] **Step 4: Eseguire il test e vederlo passare**

Run: `flutter test test/shared/helpers/navigation_helpers_test.dart`
Expected: `All tests passed!` (2 test).

- [ ] **Step 5: Usarlo nel dettaglio casa**

In `lib/features/houses/view/house_detail_screen.dart`, in `_HouseNormalAppBar.build`:
```dart
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.popOrGo('/'),
      ),
```
e aggiungere l'import:
```dart
import '../../../shared/helpers/navigation_helpers.dart';
```

Run: `grep -n "context.go('/')" lib/features/houses/view/house_detail_screen.dart`
Expected: restano solo `:164` (dopo l'eliminazione della casa) e `:356` (casa non trovata), entrambi recuperi previsti dalla policy.

- [ ] **Step 6: Analizzare, testare, committare**

```bash
dart format lib/ test/
dart analyze
flutter test test/shared/ test/features/houses/
git add lib/shared/helpers/navigation_helpers.dart test/shared/helpers/navigation_helpers_test.dart lib/features/houses/view/house_detail_screen.dart
git commit -m "fix: la freccia del dettaglio casa torna alla pagina precedente

Faceva go('/') e perdeva lo stack. Ora fa pop, e va alla home solo se
sotto non c'è nulla (dettaglio aperto con go dopo l'import AI).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Icona "Gestisci casa" (#5) e verifica finale con gli screenshot

**Files:**
- Modify: `lib/features/houses/view/house_detail_screen.dart:640`

- [ ] **Step 1: Cambiare l'icona**

In `_HouseNormalActionBar.build` (slot `left` della `TriSlotBar`):
```dart
              : CircularActionButton(
                  icon: Icons.more_horiz,
                  onPressed: onManage,
                  showBorder: true,
                ),
```

Il comportamento non cambia: `onManage` apre ancora `showHouseManageSheet`.

- [ ] **Step 2: Analizzare e testare**

```bash
dart format lib/ test/
dart analyze
flutter test
```

Expected: analyze pulito, tutti i test verdi.

- [ ] **Step 3: Screenshot "dopo" e confronto**

```bash
flutter test test/screenshots --dart-define=UI_SCREENSHOTS=true
```

Expected: `All tests passed!`, nessuna cartella `11-creazione-guidata` in `build/ui-screenshots/`. Aprire e confrontare con `build/ui-screenshots-before/`:
- `04-dettaglio-casa/01-dettaglio-casa-pieno-light.png` e `-dark.png`: in basso a sinistra i tre puntini al posto della matita.
- `04-dettaglio-casa/08-gestisci-casa-menu-light.png`: menu invariato.
- `08-nuovo-viaggio/*`: invariati (il wizard di creazione non deve cambiare).

- [ ] **Step 4: Commit**

```bash
git add lib/features/houses/view/house_detail_screen.dart
git commit -m "fix: icona a tre puntini per il menu Gestisci casa

La matita prometteva \"modifica\" ma apre un menu di azioni (che
contiene anche Elimina).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Fuori da questo piano (annotato, non fatto)

- Dopo l'import AI il dettaglio casa si apre con `go('/houses/<id>')` (`ai_results_screen.dart:256`, `:374`): lo stack si azzera e il back di **sistema** da lì esce dall'app. Con `popOrGo` la freccia a schermo ora funziona; sistemare anche il back di sistema vuol dire cambiare come si chiude il flusso di import (`pop` fino al dettaglio). Da valutare a parte.

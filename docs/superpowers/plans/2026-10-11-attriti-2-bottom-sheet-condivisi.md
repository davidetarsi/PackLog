# Attriti UI 2 · Bottom sheet condivisi — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chiudere gli attriti #7 e #12 di `docs/ui-flows.md`: i sheet scritti a mano diventano componenti del design system (un solo sheet fotocamera/galleria, picker con `DsPickerSheet`, "Gestisci casa" con handle e titolo), e l'import AI mostra il nome delle case come il resto dell'app (`displayName`).

**Architecture:** La testata "handle + titolo + divisore" oggi vive dentro `DsPickerSheet`; si estrae in `DsSheetHeader` così la riusano anche i sheet di azioni ("Gestisci casa"). Il sheet fotocamera/galleria diventa una funzione `showImageSourceSheet` costruita su `DsPickerSheet<ImageSource>`, e i tre punti che lo copiavano la chiamano. I picker del form oggetto e la scelta casa dell'import AI passano a `DsPickerSheet.show<T>()`. Nessun cambio di provider, repository o schema.

**Tech Stack:** Flutter 3.38.5, Riverpod 2.5, easy_localization, image_picker.

**Prerequisito:** Task 1 del piano 1 (`2026-10-11-attriti-1-navigazione-codice-morto.md`) eseguito: serve l'harness `test/screenshots/` e la cartella `build/ui-screenshots-before/`. I piani sono indipendenti per il resto e si possono eseguire in qualsiasi ordine.

## Global Constraints

- Branch di lavoro: `fix/ui-frictions`, **senza upstream**: non fare `git push` senza indicare remoto e branch.
- Flutter **3.38.5**. Niente `git worktree add`.
- Regole del design system (`.claude/skills/ui-design-system/SKILL.md`): picker sempre con `DsPickerSheet.show<T>()`, mai `showModalBottomSheet` + `ListView` raw; form in sheet con `StandardBottomSheetLayout`; colori da `Theme.of(context).colorScheme`, spacing da `AppSpacing`/`context.spacing*`.
- Testi UI **solo** via `.tr()`, con la chiave in `it-IT.json` **e** `en-US.json`. Le traduzioni si modificano con lo script Python indicato (round-trip identico byte per byte ai file attuali).
- I test dei widget non asseriscono su testo tradotto: senza `EasyLocalization` `.tr()` restituisce la chiave. Si cerca per `Key`, tipo o icona; il testo si usa solo per stringhe non tradotte passate dal test stesso.
- Prima di ogni commit: `dart format lib/ test/`, `dart analyze` pulito, test toccati verdi. Commit appena è verde, messaggi conventional in italiano chiusi da `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `ARCHITECTURE.md` e la skill `ui-design-system` si aggiornano solo per il nuovo componente condiviso (`DsSheetHeader`) e la regola sui sheet di azioni.

## File Structure

**Creati**

| File | Responsabilità |
|---|---|
| `lib/shared/widgets/ds_sheet_header.dart` | Testata dei sheet senza form: handle centrato, titolo, divisore |
| `lib/features/ai_input/view/widgets/image_source_sheet.dart` | `showImageSourceSheet()`: fotocamera o galleria, unico per tutta l'app |
| `test/shared/widgets/ds_picker_sheet_test.dart` | `DsPickerSheet` usa `DsSheetHeader`, segna la selezione, restituisce il valore |
| `test/features/ai_input/view/widgets/image_source_sheet_test.dart` | Sorgente restituita, sottotitoli facoltativi |
| `test/features/houses/view/house_manage_sheet_test.dart` | "Gestisci casa" ha la testata e le sue azioni |

**Modificati**

| File | Cosa cambia |
|---|---|
| `lib/shared/widgets/ds_picker_sheet.dart` | Usa `DsSheetHeader` invece della testata inline |
| `lib/shared/widgets/widgets.dart` | Esporta `ds_sheet_header.dart` |
| `lib/features/tour/view/ai_onboarding_intro_screen.dart:43-69` | `_showSourceSheet` → `showImageSourceSheet` |
| `lib/features/ai_input/view/ai_clothing_sandbox_screen.dart:46-75` | `_showPickerSheet` → `showImageSourceSheet` |
| `lib/features/ai_input/view/ai_results_screen.dart:103-139, 341, 381-440` | Sheet sorgente condiviso; scelta casa con `DsPickerSheet`; `displayName` |
| `lib/features/items/view/item_form_content.dart:117-153, 427-469, 521-590` | Quantità, casa e spazio con `DsPickerSheet` |
| `lib/features/houses/view/house_manage_sheet.dart` | `DsSheetHeader` in testa |
| `assets/translations/it-IT.json`, `en-US.json` | Nuova `ai_import.source_sheet_title`; `houses.manage_sheet_title` → "Gestisci casa" |
| `ARCHITECTURE.md` (tabella widget condivisi), `.claude/skills/ui-design-system/SKILL.md` | `DsPickerSheet` e `DsSheetHeader` |

---

### Task 1: `DsSheetHeader`, estratto da `DsPickerSheet`

**Files:**
- Create: `lib/shared/widgets/ds_sheet_header.dart`
- Modify: `lib/shared/widgets/ds_picker_sheet.dart:85-100`, `lib/shared/widgets/widgets.dart`
- Test: `test/shared/widgets/ds_picker_sheet_test.dart`

**Interfaces:**
- Produces: `class DsSheetHeader extends StatelessWidget { const DsSheetHeader({Key? key, required String title}); }`. `DsPickerSheet.show<T>()` invariato nella firma.

- [ ] **Step 1: Scrivere il test che fallisce**

`test/shared/widgets/ds_picker_sheet_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/widgets/ds_picker_sheet.dart';
import 'package:pack_log/shared/widgets/ds_sheet_header.dart';

Future<String?> _open(WidgetTester tester, {String? selected}) async {
  String? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await DsPickerSheet.show<String>(
                context: context,
                title: 'Titolo',
                items: const ['uno', 'due'],
                getLabel: (s) => s,
                selected: selected,
              );
            },
            child: const Text('apri'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('uno'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('ha la testata condivisa', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DsPickerSheet<String>(
            title: 'Titolo',
            items: const ['uno', 'due'],
            getLabel: (s) => s,
            selected: 'due',
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(DsSheetHeader), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('restituisce l\'elemento toccato', (tester) async {
    expect(await _open(tester, selected: 'due'), 'uno');
  });
}
```

- [ ] **Step 2: Eseguirlo e vederlo fallire**

Run: `flutter test test/shared/widgets/ds_picker_sheet_test.dart`
Expected: FAIL in compilazione, `ds_sheet_header.dart` non esiste.

- [ ] **Step 3: Creare `DsSheetHeader`**

`lib/shared/widgets/ds_sheet_header.dart`:
```dart
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'ds_bottom_sheet_handle.dart';

/// Testata dei bottom sheet senza form: handle, titolo, divisore.
///
/// I sheet con form hanno la loro testata in [StandardBottomSheetLayout], con
/// il bottone chiudi. Questa serve ai sheet di scelta ([DsPickerSheet]) e di
/// azioni, che si chiudono toccando un'opzione.
class DsSheetHeader extends StatelessWidget {
  final String title;

  const DsSheetHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: DsBottomSheetHandle()),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
```

- [ ] **Step 4: Usarlo in `DsPickerSheet`**

In `lib/shared/widgets/ds_picker_sheet.dart`, nella `Column` di `build`, sostituire
```dart
            const DsBottomSheetHandle(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
```
con
```dart
            DsSheetHeader(title: title),
```
e l'import `import 'ds_bottom_sheet_handle.dart';` con `import 'ds_sheet_header.dart';`. Nel commento della classe, `Struttura: BottomSheetHandle → titolo → Divider → ListView` diventa `Struttura: [DsSheetHeader] → ListView`.

Effetto visibile voluto: l'handle del picker passa da allineato a sinistra a centrato, come in `StandardBottomSheetLayout`.

In `lib/shared/widgets/widgets.dart` aggiungere, dopo `export 'ds_picker_sheet.dart';`:
```dart
export 'ds_sheet_header.dart';
```

- [ ] **Step 5: Eseguire il test e vederlo passare**

Run: `flutter test test/shared/widgets/ds_picker_sheet_test.dart`
Expected: `All tests passed!` (2 test).

- [ ] **Step 6: Commit**

```bash
dart format lib/ test/ && dart analyze
git add lib/shared/widgets/ds_sheet_header.dart lib/shared/widgets/ds_picker_sheet.dart lib/shared/widgets/widgets.dart test/shared/widgets/ds_picker_sheet_test.dart
git commit -m "refactor: estrae DsSheetHeader dalla testata di DsPickerSheet

Handle, titolo e divisore diventano un componente, riusabile dai sheet
di azioni. L'handle del picker ora è centrato.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Un solo sheet fotocamera/galleria

**Files:**
- Create: `lib/features/ai_input/view/widgets/image_source_sheet.dart`
- Test: `test/features/ai_input/view/widgets/image_source_sheet_test.dart`
- Modify: `lib/features/tour/view/ai_onboarding_intro_screen.dart:43-69`
- Modify: `lib/features/ai_input/view/ai_clothing_sandbox_screen.dart:46-75`
- Modify: `lib/features/ai_input/view/ai_results_screen.dart:103-139`
- Modify: `assets/translations/it-IT.json`, `en-US.json`

**Interfaces:**
- Consumes: `DsPickerSheet.show<T>()` (Task 1).
- Produces: `Future<ImageSource?> showImageSourceSheet(BuildContext context, {String? gallerySubtitle, String? cameraSubtitle})`. `null` = sheet chiuso senza scegliere.

- [ ] **Step 1: Chiave del titolo**

```bash
python3 - <<'EOF'
import json
vals = {"it-IT": "Aggiungi foto", "en-US": "Add photos"}
for f, v in vals.items():
    p = f"assets/translations/{f}.json"
    d = json.load(open(p, encoding="utf-8"))
    d["ai_import"]["source_sheet_title"] = v
    d["ai_import"] = dict(sorted(d["ai_import"].items()))
    open(p, "w", encoding="utf-8").write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
EOF
git diff assets/translations
```

Expected: una riga aggiunta per file, nella posizione alfabetica (il namespace `ai_import` è già ordinato alfabeticamente; se il diff mostra altre righe spostate, ripristinare con `git checkout assets/translations` e inserire la chiave a mano dopo `"source_gallery"`).

- [ ] **Step 2: Scrivere il test che fallisce**

`test/features/ai_input/view/widgets/image_source_sheet_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pack_log/features/ai_input/view/widgets/image_source_sheet.dart';
import 'package:pack_log/shared/widgets/ds_sheet_header.dart';

/// Apre il sheet e restituisce un getter del risultato (letto dopo il tap).
Future<ImageSource? Function()> _openSheet(
  WidgetTester tester, {
  String? gallerySubtitle,
  String? cameraSubtitle,
}) async {
  ImageSource? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showImageSourceSheet(
                context,
                gallerySubtitle: gallerySubtitle,
                cameraSubtitle: cameraSubtitle,
              );
            },
            child: const Text('apri'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  testWidgets('restituisce la fotocamera quando la si tocca', (tester) async {
    final result = await _openSheet(tester);

    expect(find.byType(DsSheetHeader), findsOneWidget);
    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
    await tester.pumpAndSettle();

    expect(result(), ImageSource.camera);
  });

  testWidgets('restituisce la galleria e mostra i sottotitoli passati', (
    tester,
  ) async {
    final result = await _openSheet(
      tester,
      gallerySubtitle: 'fino a 3',
      cameraSubtitle: 'una foto',
    );

    expect(find.text('fino a 3'), findsOneWidget);
    expect(find.text('una foto'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();

    expect(result(), ImageSource.gallery);
  });

  testWidgets('senza sottotitoli non ne mostra', (tester) async {
    await _openSheet(tester);

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
    expect(tiles, hasLength(2));
    expect(tiles.every((t) => t.subtitle == null), isTrue);
  });
}
```

- [ ] **Step 3: Eseguirlo e vederlo fallire**

Run: `flutter test test/features/ai_input/view/widgets/image_source_sheet_test.dart`
Expected: FAIL in compilazione, `image_source_sheet.dart` non esiste.

- [ ] **Step 4: Implementare `showImageSourceSheet`**

`lib/features/ai_input/view/widgets/image_source_sheet.dart`:
```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/widgets/ds_picker_sheet.dart';

/// Sheet "galleria o fotocamera", unico per tour, import AI e risultati.
///
/// Restituisce la sorgente scelta, o null se l'utente chiude il sheet.
/// I sottotitoli sono facoltativi: il tour sceglie una foto sola e non deve
/// promettere il limite della galleria che vale nell'import.
Future<ImageSource?> showImageSourceSheet(
  BuildContext context, {
  String? gallerySubtitle,
  String? cameraSubtitle,
}) {
  return DsPickerSheet.show<ImageSource>(
    context: context,
    title: 'ai_import.source_sheet_title'.tr(),
    items: const [ImageSource.gallery, ImageSource.camera],
    getLabel: (s) => s == ImageSource.gallery
        ? 'ai_import.source_gallery'.tr()
        : 'ai_import.source_camera'.tr(),
    getSubtitle: (s) =>
        s == ImageSource.gallery ? gallerySubtitle : cameraSubtitle,
    getIcon: (s) => s == ImageSource.gallery
        ? Icons.photo_library_outlined
        : Icons.camera_alt_outlined,
  );
}
```

- [ ] **Step 5: Eseguire il test e vederlo passare**

Run: `flutter test test/features/ai_input/view/widgets/image_source_sheet_test.dart`
Expected: `All tests passed!` (3 test).

- [ ] **Step 6: Sostituire le tre copie**

`lib/features/tour/view/ai_onboarding_intro_screen.dart`, sostituire tutto `_showSourceSheet()` con:
```dart
  Future<void> _showSourceSheet() async {
    final source = await showImageSourceSheet(context);
    switch (source) {
      case ImageSource.gallery:
        await _pickFromGallery();
      case ImageSource.camera:
        await _pickFromCamera();
      case null:
        return;
    }
  }
```
e aggiungere `import '../../ai_input/view/widgets/image_source_sheet.dart';`.

`lib/features/ai_input/view/ai_clothing_sandbox_screen.dart`, sostituire tutto `_showPickerSheet()` con:
```dart
  Future<void> _showPickerSheet() async {
    final source = await showImageSourceSheet(
      context,
      gallerySubtitle: 'ai_import.gallery_subtitle'.tr(args: ['5']),
      cameraSubtitle: 'ai_import.camera_subtitle'.tr(),
    );
    switch (source) {
      case ImageSource.gallery:
        await _pickFromGallery();
      case ImageSource.camera:
        await _pickFromCamera();
      case null:
        return;
    }
  }
```
e aggiungere `import 'widgets/image_source_sheet.dart';`.

`lib/features/ai_input/view/ai_results_screen.dart`, sostituire tutto `_showPickerSheet()` con:
```dart
  Future<void> _showPickerSheet() async {
    final notifier = ref.read(aiImportNotifierProvider.notifier);
    if (notifier.remainingSlots <= 0) return;

    final source = await showImageSourceSheet(
      context,
      gallerySubtitle: 'ai_import.gallery_subtitle'.tr(
        args: [notifier.remainingSlots.toString()],
      ),
      cameraSubtitle: 'ai_import.camera_subtitle'.tr(),
    );
    switch (source) {
      case ImageSource.gallery:
        await _pickFromGallery();
      case ImageSource.camera:
        await _pickFromCamera();
      case null:
        return;
    }
  }
```
e aggiungere `import 'widgets/image_source_sheet.dart';`.

In tutti e tre i file `_pickFromGallery` e `_pickFromCamera` restano come sono (il tour sceglie una foto, l'import fino a 5): cambia solo il sheet. Sono tutti `Future<void>`, quindi l'`await` nello `switch` è corretto.

Run: `grep -rn "source_gallery" lib | grep "\.dart:"`
Expected: solo `image_source_sheet.dart`.

- [ ] **Step 7: Analizzare, testare, committare**

```bash
dart format lib/ test/
dart analyze
flutter test test/features/ai_input/ test/features/tour/ test/shared/
git add -A lib/features/ai_input lib/features/tour test/features/ai_input assets/translations
git commit -m "refactor: un solo sheet fotocamera/galleria

Era copiato in tour, import AI e risultati. Ora è showImageSourceSheet,
costruito su DsPickerSheet, con titolo e sottotitoli facoltativi.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Picker del form oggetto con `DsPickerSheet`

**Files:**
- Modify: `lib/features/items/view/item_form_content.dart:117-153` (quantità), `:427-469` (casa), `:521-590` (spazio)

**Interfaces:**
- Consumes: `DsPickerSheet.show<T>()` (Task 1).
- Produces: nessuna interfaccia pubblica nuova; `_showSpacePicker` passa da `List` a `List<SpaceModel>`.

Non esiste un test di widget per `ItemFormContent` (richiede provider di case, spazi e oggetti). La verifica è `dart analyze` più gli screenshot del Task 6 e una prova manuale dei tre picker.

- [ ] **Step 1: Quantità**

Sostituire tutto `_showQuantityPicker()` con:
```dart
  Future<void> _showQuantityPicker() async {
    final selected = await DsPickerSheet.show<int>(
      context: context,
      title: 'common.select_quantity'.tr(),
      items: _quantityOptions,
      getLabel: (q) => q.toString(),
      selected: _selectedQuantity,
    );
    if (selected != null) {
      setState(() => _selectedQuantity = selected);
    }
  }
```

- [ ] **Step 2: Casa**

Sostituire tutto `_showHousePicker(List<HouseModel> houses)` con:
```dart
  Future<void> _showHousePicker(List<HouseModel> houses) async {
    final selected = await DsPickerSheet.show<HouseModel>(
      context: context,
      title: 'common.select_house'.tr(),
      items: houses,
      getLabel: (h) => h.displayName,
      getSubtitle: (h) => h.description,
      getIcon: (_) => Icons.home_outlined,
      selected: houses.where((h) => h.id == _selectedHouseId).firstOrNull,
    );
    if (selected != null) {
      setState(() {
        _selectedHouseId = selected.id;
        _selectedSpaceId = null;
      });
    }
  }
```

- [ ] **Step 3: Spazio**

Aggiungere sopra la classe dello state (a livello di file):
```dart
/// Opzione del picker spazio. `id == null` è lo spazio predefinito: non si
/// può usare `null` come valore dell'opzione, perché per [DsPickerSheet]
/// `null` vuol dire "chiuso senza scegliere".
typedef _SpaceOption = ({String? id, String name, IconData icon});
```

Sostituire tutto `_showSpacePicker(List spaces)` con:
```dart
  Future<void> _showSpacePicker(List<SpaceModel> spaces) async {
    final options = <_SpaceOption>[
      (id: null, name: 'spaces.default'.tr(), icon: Icons.inventory_2),
      for (final space in spaces)
        (
          id: space.id,
          name: space.name,
          icon: space.iconName != null
              ? SpaceIcons.getIcon(space.iconName!)
              : Icons.meeting_room,
        ),
    ];

    final selected = await DsPickerSheet.show<_SpaceOption>(
      context: context,
      title: 'items.select_space'.tr(),
      items: options,
      getLabel: (o) => o.name,
      getIcon: (o) => o.icon,
      selected: options.firstWhere(
        (o) => o.id == _selectedSpaceId,
        orElse: () => options.first,
      ),
    );
    if (selected != null) {
      setState(() => _selectedSpaceId = selected.id);
    }
  }
```

Import da aggiungere:
```dart
import '../../spaces/model/space_model.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
```

- [ ] **Step 4: Controllare che non resti codice raw**

Run: `grep -n "showModalBottomSheet\|defaultSpaceSentinel" lib/features/items/view/item_form_content.dart`
Expected: nessun risultato.

- [ ] **Step 5: Analizzare, testare, committare**

```bash
dart format lib/ test/
dart analyze
flutter test test/features/items/
git add lib/features/items/view/item_form_content.dart
git commit -m "refactor: picker del form oggetto con DsPickerSheet

Quantità, casa e spazio usavano sheet scritti a mano con ListTile e
spunta verde. Ora hanno testata, handle e spunta del design system.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Import AI, scelta casa con `DsPickerSheet` e `displayName` (#12)

**Files:**
- Modify: `lib/features/ai_input/view/ai_results_screen.dart:341` (CTA), `:381-440` (`_showHousePicker`)

**Interfaces:**
- Consumes: `DsPickerSheet.show<T>()` (Task 1), `HouseModel.displayName`.

- [ ] **Step 1: CTA con `displayName`**

Riga 341:
```dart
          args: [selectedHouse.displayName, totalItems.toString()],
```

- [ ] **Step 2: Scelta casa**

Sostituire tutto `_showHousePicker(...)` con:
```dart
  Future<void> _showHousePicker(
    AiImportState state,
    AiImportNotifier notifier,
  ) async {
    final houses = ref.read(houseNotifierProvider).valueOrNull;
    if (houses == null || houses.isEmpty) return;

    final selected = await DsPickerSheet.show<HouseModel>(
      context: context,
      title: 'ai_import.choose_house_title'.tr(),
      items: houses,
      getLabel: (h) => h.displayName,
      getIcon: (_) => Icons.home_outlined,
      selected: houses.where((h) => h.id == state.selectedHouseId).firstOrNull,
    );
    if (selected != null) notifier.setSelectedHouseId(selected.id);
  }
```

e aggiungere `import '../../../shared/widgets/ds_picker_sheet.dart';`.

- [ ] **Step 3: Controlli**

Run:
```bash
grep -n "showModalBottomSheet\|house\.name\|House\.name" lib/features/ai_input/view/ai_results_screen.dart
```
Expected: nessun risultato.

- [ ] **Step 4: Analizzare, testare, committare**

```bash
dart format lib/ test/
dart analyze
flutter test test/features/ai_input/
git add lib/features/ai_input/view/ai_results_screen.dart
git commit -m "fix: l'import AI mostra il nome delle case come il resto dell'app

Scelta casa e CTA usavano house.name invece di displayName; la scelta
casa passa a DsPickerSheet.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: "Gestisci casa" con handle e titolo

**Files:**
- Modify: `lib/features/houses/view/house_manage_sheet.dart`
- Modify: `assets/translations/it-IT.json:59`, `en-US.json:62`
- Test: `test/features/houses/view/house_manage_sheet_test.dart`

**Interfaces:**
- Consumes: `DsSheetHeader` (Task 1). `showHouseManageSheet(...)` invariata nella firma.

- [ ] **Step 1: Scrivere il test che fallisce**

`test/features/houses/view/house_manage_sheet_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/houses/view/house_manage_sheet.dart';
import 'package:pack_log/shared/widgets/ds_sheet_header.dart';

Future<void> _open(WidgetTester tester, {required VoidCallback onDelete}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showHouseManageSheet(
              context,
              houseId: 'h1',
              isPrimary: false,
              houseName: 'Casa',
              onSetPrimary: () {},
              onDelete: onDelete,
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ha la testata del design system', (tester) async {
    await _open(tester, onDelete: () {});

    expect(find.byType(DsSheetHeader), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('Elimina chiude il sheet e chiama onDelete', (tester) async {
    var deleted = false;
    await _open(tester, onDelete: () => deleted = true);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(find.byType(DsSheetHeader), findsNothing);
  });
}
```

- [ ] **Step 2: Eseguirlo e vederlo fallire**

Run: `flutter test test/features/houses/view/house_manage_sheet_test.dart`
Expected: il primo test FAIL (`DsSheetHeader` non trovato), il secondo passa già.

- [ ] **Step 3: Aggiungere la testata**

In `lib/features/houses/view/house_manage_sheet.dart`, come primo figlio della `Column`:
```dart
          DsSheetHeader(title: 'houses.manage_sheet_title'.tr()),
```
e l'import `import '../../../shared/widgets/ds_sheet_header.dart';`.

- [ ] **Step 4: Titolo "Gestisci casa"**

La chiave `houses.manage_sheet_title` esiste già ma non è usata da nessuno (valori "Modifica Casa" / "Edit House"). Diventa coerente con l'icona a tre puntini del piano 1:

```bash
python3 - <<'EOF'
import json
vals = {"it-IT": "Gestisci casa", "en-US": "Manage house"}
for f, v in vals.items():
    p = f"assets/translations/{f}.json"
    d = json.load(open(p, encoding="utf-8"))
    d["houses"]["manage_sheet_title"] = v
    open(p, "w", encoding="utf-8").write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
EOF
```

- [ ] **Step 5: Eseguire il test e vederlo passare**

Run: `flutter test test/features/houses/view/house_manage_sheet_test.dart`
Expected: `All tests passed!` (2 test).

- [ ] **Step 6: Commit**

```bash
dart format lib/ test/ && dart analyze
git add lib/features/houses/view/house_manage_sheet.dart test/features/houses/view/house_manage_sheet_test.dart assets/translations
git commit -m "fix: il menu Gestisci casa ha handle e titolo

Era l'unico sheet senza testata. Usa DsSheetHeader con il titolo
\"Gestisci casa\".

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Documentazione e verifica con gli screenshot

**Files:**
- Modify: `ARCHITECTURE.md` (tabella "Regole Architetturali dei Widget Condivisi", riga ~2044)
- Modify: `.claude/skills/ui-design-system/SKILL.md` (regole, riga ~279, e tabella, riga ~319)

- [ ] **Step 1: `ARCHITECTURE.md`**

Nella tabella "Regole Architetturali dei Widget Condivisi", subito dopo la riga di `StandardBottomSheetLayout`, aggiungere:
```markdown
| `DsPickerSheet` / `DsSheetHeader` | Le scelte da una lista usano `DsPickerSheet.show<T>()` (tocco = conferma, `null` = chiuso). I sheet di azioni senza form (es. "Gestisci casa") iniziano con `DsSheetHeader` (handle → titolo → divisore). Il sheet fotocamera/galleria è uno solo: `showImageSourceSheet()`. |
```

- [ ] **Step 2: Skill `ui-design-system`**

In `.claude/skills/ui-design-system/SKILL.md`, dopo la regola `- Picker: DsPickerSheet.show<T>(), mai showModalBottomSheet raw` aggiungere:
```markdown
- Sheet di azioni (menu senza form): `DsSheetHeader` come primo figlio, mai handle e titolo scritti a mano
- Fotocamera/galleria: `showImageSourceSheet()` (`features/ai_input/view/widgets/image_source_sheet.dart`)
```
e nella tabella, dopo `| Picker selezione | DsPickerSheet<T> | showModalBottomSheet + ListView raw |`:
```markdown
| Sheet di azioni | `DsSheetHeader` + `ListTile` | Sheet senza handle né titolo |
```

- [ ] **Step 3: Test completi**

```bash
dart format lib/ test/
dart analyze
flutter test
```
Expected: analyze pulito, tutti i test verdi.

- [ ] **Step 4: Screenshot "dopo" e confronto**

```bash
flutter test test/screenshots --dart-define=UI_SCREENSHOTS=true
```

Confrontare con `build/ui-screenshots-before/` (stessi nomi file):
- `02-tour-ai/02-ai-intro-scelta-sorgente-*`, `06-import-ai/02-import-ai-scelta-sorgente-*`: handle centrato, titolo "Aggiungi foto", divisore; nel tour **senza** sottotitoli, nell'import con "Max 5 foto selezionabili" e "Scatta una foto".
- `06-import-ai/05-ai-risultati-scelta-casa-*`: testata del design system, spunta al posto del `check_circle`, il nome lungo "Baita dei nonni a Courmayeur, Valle d'Aosta" com'è nel resto dell'app.
- `06-import-ai/04-ai-risultati-capi-riconosciuti-*`: CTA "Salva in Casa Milano (n)" invariata nei dati di esempio (lì `name` e `displayName` coincidono).
- `04-dettaglio-casa/08-gestisci-casa-menu-*`: handle e titolo "Gestisci casa" sopra le voci.
- `08-nuovo-viaggio/04-nuovo-viaggio-scelta-casa-*`: unica differenza l'handle centrato.

I picker di quantità, casa e spazio del form oggetto non sono negli screenshot: aprire l'app (`flutter run`), dal dettaglio di una casa toccare un oggetto e aprire i tre picker. Atteso: testata con handle, spunta arancione (non più verde) sull'opzione attuale, l'opzione dello spazio predefinito (`spaces.default`, oggi "Default", tradotta dal piano 4) in cima alla lista spazi.

- [ ] **Step 5: Commit**

```bash
git add ARCHITECTURE.md .claude/skills/ui-design-system/SKILL.md
git commit -m "docs: DsSheetHeader e showImageSourceSheet tra i componenti condivisi

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Fuori da questo piano (annotato, non fatto)

- Restano altre chiamate dirette a `showModalBottomSheet` in `lib/features` (19 in tutto prima di questo piano). Quelle che aprono un form con `StandardBottomSheetLayout` o `EntityManagementSheet` sono corrette così: il componente è il contenuto, non il modo di aprirlo. Questo piano chiude solo i sheet citati nell'attrito #7.

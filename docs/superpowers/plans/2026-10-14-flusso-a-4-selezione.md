# Flusso A · Blocco 4: selezione multipla con la barra flottante condivisa

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Selezione multipla più leggera: barra in basso con tre azioni alla pari e neutre (Sposta · In viaggio · Elimina) nella stessa forma della barra di navigazione, "Seleziona tutti" a testo, "1 selezionato" al singolare, velo neutro sulle righe scelte, foglio "Sposta" che sposta al tocco, voce "Seleziona oggetti" nel "⋯" della casa. Chiude anche il punto aperto del blocco 1 sulla tastiera che si riapre.

**Architecture:** Da `MainShell` si estraggono `DsFloatingBar` (contenitore: vetro, bordo, ombra, forma a pillola) e `DsBarItem` (l'ex `_NavItem`, ora pubblico, con lo stato spento). Navigazione e selezione usano gli stessi due componenti. Il resto sono modifiche puntuali a schermata della casa, `ItemCard`, `BulkMoveSheet`, `house_manage_sheet.dart`.

**Tech Stack:** Flutter 3.38, Riverpod 2.5, easy_localization; test di widget con l'harness degli screenshot.

**Spec:** `docs/superpowers/specs/2026-10-14-flusso-a-dettaglio-casa-design.md`, sezione 6, "Regole per il kit" punto 4, "Punti aperti dal blocco 1".

**Parte da:** `develop` con i blocchi 1-3 dentro (i riferimenti di riga possono essersi spostati: cerca per nome).

## Global Constraints

- Branch `feat/casa-selezione` da `origin/develop`; PR verso `develop` (squash).
- Niente colori, spaziature o font scritti a mano.
- `DsFloatingBar` e `DsBarItem` riproducono esattamente l'aspetto attuale della barra di navigazione (altezza `context.responsive(56.0)`, raggio `AppConstants.pillBorderRadius`, vetro con `ImageFilter.blur(sigmaX: 16, sigmaY: 16)` e `surfaceContainer` al 78%, bordo `outlineVariant` al 40%, ombra `shadow` al 12% `blurRadius: 12` `offset (0, 3)`, icona `context.responsive(22)`, scritta `labelSmall` con scala del testo limitata a 1.3, lineetta `spacingLg × spacingXs` sull'attiva). I test di `main_shell_test.dart` devono restare verdi senza modifiche.
- `DsBarItem` spento (`onTap == null`): icona e scritta `onSurface` al 38%.
- Barra della selezione: chiavi `selection_move`, `selection_trip`, `selection_delete`; icone `Icons.drive_file_move_outline`, `Icons.luggage_outlined`, `Icons.delete_outline`; scritte `common.move`, `items.to_trip` (nuova: "In viaggio" / "To a trip"), `common.delete`. Tutte neutre; spente finché non c'è almeno un oggetto scelto.
- Riga scelta: velo `onSurface` al 6% (oggi `primary` all'8%). La casella resta arancio.
- Titolo: plurale con easy_localization, `items.selected_count` diventa `{"one": "{} selezionato", "other": "{} selezionati"}` (en `{"one": "{} selected", "other": "{} selected"}`), letto con `.plural(n)`.
- Foglio "Sposta": tocco sulla casa → se la casa non ha spazi chiude subito con la destinazione; se ne ha, mostra gli spazi (con "Senza spazio") e il tocco sullo spazio chiude. Niente bottone "Sposta" in fondo.
- Voce "Seleziona oggetti" (`items.select_items`, icona `Icons.checklist`) in cima al foglio "Gestisci casa".
- Il campo di ricerca della casa prende il focus solo quando si apre la ricerca, non quando l'intestazione si ricostruisce.
- Dopo ogni task: `dart analyze` pulito e test verdi; commit (italiano, riga `Co-Authored-By:` del modello che scrive il commit).

---

### Task 1: `DsFloatingBar` e `DsBarItem` estratti da `MainShell`

**Files:**
- Create: `lib/shared/widgets/ds_floating_bar.dart`
- Modify: `lib/shared/widgets/main_shell.dart` (usa i due componenti; via `_NavItem`, `_kGlassNavBar` e la costruzione della barra)
- Modify: `lib/shared/widgets/widgets.dart` (export)
- Test: `test/shared/widgets/ds_floating_bar_test.dart`; `test/shared/widgets/main_shell_test.dart` invariato e verde

**Interfaces:**
- Produces: `DsFloatingBar({Key? key, required List<Widget> children})` (ogni figlio in un `Expanded`); `DsBarItem({Key? key, Key? anchorKey, required IconData icon, IconData? selectedIcon, required String label, VoidCallback? onTap, bool isSelected = false, bool accent = false})`.

- [x] **Step 1: test che falliscono**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_floating_bar.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<Widget> items) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: DsFloatingBar(children: items),
            ),
          ),
        ),
      );

  testWidgets('voci larghe uguali', (tester) async {
    await pump(tester, [
      DsBarItem(key: const Key('a'), icon: Icons.home, label: 'A', onTap: () {}),
      DsBarItem(key: const Key('b'), icon: Icons.add, label: 'Bbbbbbbb', onTap: () {}),
      DsBarItem(key: const Key('c'), icon: Icons.luggage, label: 'C', onTap: () {}),
    ]);
    final a = tester.getSize(find.byKey(const Key('a'))).width;
    expect(tester.getSize(find.byKey(const Key('b'))).width, a);
    expect(tester.getSize(find.byKey(const Key('c'))).width, a);
  });

  testWidgets('senza onTap la voce è spenta al 38%', (tester) async {
    await pump(tester, [
      const DsBarItem(key: Key('off'), icon: Icons.delete_outline, label: 'X'),
    ]);
    final icon = tester.widget<Icon>(find.byIcon(Icons.delete_outline));
    expect(
      icon.color,
      AppTheme.light.colorScheme.onSurface.withValues(alpha: 0.38),
    );
  });

  testWidgets('accesa e non accent: colore onSurface', (tester) async {
    await pump(tester, [
      DsBarItem(icon: Icons.delete_outline, label: 'X', onTap: () {}),
    ]);
    final icon = tester.widget<Icon>(find.byIcon(Icons.delete_outline));
    expect(icon.color, AppTheme.light.colorScheme.onSurface);
  });

  testWidgets('la selezionata mostra la lineetta', (tester) async {
    await pump(tester, [
      DsBarItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Case',
        isSelected: true,
        onTap: () {},
      ),
    ]);
    expect(find.byKey(const Key('nav_indicator')), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
  });
}
```

- [x] **Step 2:** `flutter test test/shared/widgets/ds_floating_bar_test.dart` → FAIL.

- [x] **Step 3: `ds_floating_bar.dart`** — sposta qui, senza cambiarne l'aspetto, la barra di `MainShell` e `_NavItem`:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// Effetto vetro della barra (sfocatura dello sfondo). Se sul telefono la
/// sfocatura fa scattare lo scorrimento, metti `false`: la barra torna a una
/// superficie tonale piena.
const bool _kGlassBar = true;

/// Barra flottante a voci uguali: la barra di navigazione e quella della
/// selezione multipla. Ogni figlio prende la stessa larghezza.
class DsFloatingBar extends StatelessWidget {
  final List<Widget> children;

  const DsFloatingBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = context.responsiveBorderRadius(
      AppConstants.pillBorderRadius,
    );

    Widget bar = Container(
      height: context.responsive(56.0),
      decoration: BoxDecoration(
        color: _kGlassBar
            ? colorScheme.surfaceContainer.withValues(alpha: 0.78)
            : colorScheme.surfaceContainer,
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final child in children) Expanded(child: child)],
      ),
    );
    if (_kGlassBar) {
      bar = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: bar,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: bar,
    );
  }
}

/// Voce di una [DsFloatingBar].
///
/// Neutra anche da selezionata: la voce attiva si riconosce dall'icona
/// piena e dalla lineetta arancio sul bordo superiore. [accent] la colora di
/// arancio (Crea nella navigazione). Senza [onTap] è spenta.
class DsBarItem extends StatelessWidget {
  /// Key dell'area toccabile, per il tour guidato.
  final Key? anchorKey;
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool accent;

  const DsBarItem({
    super.key,
    this.anchorKey,
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.onTap,
    this.isSelected = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = onTap == null
        ? colorScheme.onSurface.withValues(alpha: 0.38)
        : accent
        ? colorScheme.primary
        : colorScheme.onSurface;

    return Semantics(
      selected: isSelected,
      button: true,
      enabled: onTap != null,
      child: InkWell(
        key: anchorKey,
        onTap: onTap,
        borderRadius: context.responsiveBorderRadius(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? (selectedIcon ?? icon) : icon,
                  size: context.responsive(22),
                  color: color,
                ),
                SizedBox(height: context.spacingXs / 4),
                // L'altezza della barra è fissa: con caratteri molto grandi
                // la scritta non deve spingere l'icona fuori.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 0,
                child: Container(
                  key: const Key('nav_indicator'),
                  width: context.spacingLg,
                  height: context.spacingXs,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(context.spacingXs),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

Prima di scrivere, confronta riga per riga con `_NavItem` e con la barra in `main_shell.dart`: se un valore attuale è diverso da quello qui sopra, vince quello attuale (l'aspetto non deve cambiare).

- [x] **Step 4: `main_shell.dart`** — al posto di `Widget bar = Container(...)`, del blocco `_kGlassNavBar`, del `DecoratedBox` con l'ombra e della classe `_NavItem`:

```dart
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.spacingMd,
            0,
            context.spacingMd,
            context.spacingMd,
          ),
          child: DsFloatingBar(
            children: [
              DsBarItem(
                key: const Key('nav_houses'),
                anchorKey: tourKeys.housesTab,
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'navigation.houses'.tr(),
                isSelected: onHouses,
                onTap: () => _goBranch(_housesBranch),
              ),
              DsBarItem(
                key: const Key('nav_create'),
                anchorKey: tourKeys.primaryAction,
                icon: Icons.add_circle_outline,
                label: 'common.create'.tr(),
                accent: true,
                onTap: () => _onCreate(context, ref, fromTrips: !onHouses),
              ),
              DsBarItem(
                key: const Key('nav_trips'),
                anchorKey: tourKeys.tripsTab,
                icon: Icons.luggage_outlined,
                selectedIcon: Icons.luggage,
                label: 'navigation.trips'.tr(),
                isSelected: !onHouses,
                onTap: () => _goBranch(_tripsBranch),
              ),
            ],
          ),
        ),
      ),
```

Togli gli import diventati inutili (`dart:ui`, `app_constants.dart` se non servono più) e aggiungi `ds_floating_bar.dart`. Export in `widgets.dart`: `export 'ds_floating_bar.dart';`.

- [x] **Step 5: verifica**

Run: `flutter test test/shared/widgets/ds_floating_bar_test.dart test/shared/widgets/main_shell_test.dart && dart analyze`
Expected: verdi (main_shell_test senza modifiche), analisi pulita.

- [x] **Step 6: commit**

```bash
git add lib/shared/widgets test/shared/widgets/ds_floating_bar_test.dart
git commit -m "refactor(ds): DsFloatingBar e DsBarItem estratti dalla barra di navigazione"
```

---

### Task 2: selezione multipla nella casa

**Files:**
- Modify: `lib/features/houses/view/house_detail_screen.dart`
- Modify: `lib/features/items/view/item_card.dart` (velo neutro)
- Modify: `assets/translations/it-IT.json`, `assets/translations/en-US.json` (`items.selected_count` plurale, `items.to_trip`)
- Test: `test/features/houses/view/house_detail_screen_test.dart`

**Interfaces:**
- Consumes: `DsFloatingBar`, `DsBarItem` (task 1).

- [x] **Step 1: stringhe** — `items.selected_count` diventa un oggetto plurale (vedi Global Constraints); aggiungi `items.to_trip`. Cerca altri usi di `items.selected_count` (`grep -rn "selected_count" lib`): se ce ne sono fuori dalla casa, passali anche loro a `.plural(n)`.

- [x] **Step 2: test** — in `house_detail_screen_test.dart`:
  1. Aggiorna il test esistente `'seleziona tutti prende solo gli oggetti visibili'`: `await app.tap(find.byIcon(Icons.check_box_outlined));` diventa `await app.tap(find.text('Seleziona tutti'));` (il resto invariato).
  2. Aggiungi:

```dart
  testWidgets('un oggetto scelto: 1 selezionato, azioni neutre e accese', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.longPress(find.text('Calzini'));
    expect(find.text('1 selezionato'), findsOneWidget);
    final move = tester.widget<DsBarItem>(
      find.byKey(const Key('selection_move')),
    );
    expect(move.onTap, isNotNull);
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('selection_delete')),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.color, AppTheme.light.colorScheme.onSurface);
    await app.finish();
  });

  testWidgets('dopo la selezione la ricerca non riprende la tastiera', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(find.byKey(const Key('house_search')));
    await app.enterText(find.byKey(const Key('house_search_field')), 'calz');
    FocusManager.instance.primaryFocus?.unfocus();
    await app.settle();
    await app.longPress(find.text('Calzini'));
    await app.tap(find.byIcon(Icons.close));
    final field = tester.widget<TextField>(
      find.byKey(const Key('house_search_field')),
    );
    expect(field.focusNode?.hasFocus, isFalse);
    await app.finish();
  });
```

  (import `package:pack_log/shared/widgets/ds_floating_bar.dart`).

- [x] **Step 3:** `flutter test test/features/houses/view/house_detail_screen_test.dart` → i nuovi FAIL.

- [x] **Step 4: implementazione**

1. `bottomContent`, ramo `isSelectionMode`: al posto del `UniversalActionBar(...)`:

```dart
                      // Tre azioni alla pari e neutre: quale serve dipende da
                      // cosa si sta facendo. Il rosso compare solo nella
                      // conferma di eliminazione.
                      child: DsFloatingBar(
                        key: const ValueKey('selection-bar'),
                        children: [
                          DsBarItem(
                            key: const Key('selection_move'),
                            icon: Icons.drive_file_move_outline,
                            label: 'common.move'.tr(),
                            onTap: hasSelection ? _handleBulkMove : null,
                          ),
                          DsBarItem(
                            key: const Key('selection_trip'),
                            icon: Icons.luggage_outlined,
                            label: 'items.to_trip'.tr(),
                            onTap: hasSelection ? _handleAddToTrip : null,
                          ),
                          DsBarItem(
                            key: const Key('selection_delete'),
                            icon: Icons.delete_outline,
                            label: 'common.delete'.tr(),
                            onTap: hasSelection ? _handleBulkDelete : null,
                          ),
                        ],
                      ),
```

   Togli l'import di `universal_action_bar.dart` se non serve più e la variabile `colorScheme` se resta inutilizzata.

2. `_HouseSelectionAppBar`: il titolo usa `'items.selected_count'.plural(selectedCount)` (resta `'items.select_items'.tr()` con zero scelti); `actions` diventa

```dart
      actions: [
        TextButton(
          onPressed: () {
            final notifier = ref.read(itemSelectionNotifierProvider.notifier);
            allSelected ? notifier.deselectAll() : notifier.selectAll(allItemIds);
          },
          child: Text(
            allSelected ? 'items.deselect_all'.tr() : 'items.select_all'.tr(),
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ),
      ],
```

3. Focus della ricerca (punto aperto del blocco 1): nello `State` `final _searchFocus = FocusNode();` (dispose); `_HouseNormalAppBar` riceve `searchFocusNode` e il `TextField` della ricerca usa `focusNode: searchFocusNode` e **non** ha più `autofocus: true`. In `_openSearch`, dopo il `setState`:

```dart
    // Il focus si dà qui, una volta: con autofocus il campo lo riprendeva a
    // ogni ricostruzione dell'intestazione (es. uscendo dalla selezione).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
```

4. `item_card.dart`: `colorScheme.primary.withValues(alpha: 0.08)` → `colorScheme.onSurface.withValues(alpha: 0.06)`, con il commento "Velo neutro: l'arancio della selezione sta solo nella casella."

- [x] **Step 5: verifica** — `flutter test test/features/houses test/features/items && dart analyze` → verdi.

- [x] **Step 6: commit**

```bash
git add lib/features/houses lib/features/items/view/item_card.dart assets/translations test/features/houses
git commit -m "feat(casa): selezione con tre azioni neutre alla pari, singolare corretto, ricerca senza autofocus"
```

---

### Task 3: foglio "Sposta" al tocco e "Seleziona oggetti" nel "⋯"

**Files:**
- Modify: `lib/features/items/view/bulk_move_sheet.dart`
- Modify: `lib/features/houses/view/house_manage_sheet.dart`
- Modify: `lib/features/houses/view/house_detail_screen.dart` (`_showManageSheet` passa `onSelectItems`)
- Test: `test/features/houses/view/house_manage_sheet_test.dart`, `test/features/houses/view/house_detail_screen_test.dart`

- [x] **Step 1: test**
  1. `house_manage_sheet_test.dart`: aggiorna `_open` per accettare `VoidCallback? onSelectItems` e passarlo; aggiungi

```dart
  testWidgets('Seleziona oggetti chiude il sheet e chiama onSelectItems', (
    tester,
  ) async {
    var called = false;
    await _open(tester, onDelete: () {}, onSelectItems: () => called = true);
    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pumpAndSettle();
    expect(called, isTrue);
    expect(find.byType(DsSheetHeader), findsNothing);
  });
```

  2. `house_detail_screen_test.dart`:

```dart
  testWidgets('Sposta verso una casa senza spazi: basta un tocco', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.longPress(find.text('Calzini'));
    await app.tap(find.byKey(const Key('selection_move')));
    await app.tap(find.text('Casa al mare'));
    expect(find.byType(BulkMoveSheet), findsNothing);
    expect(find.text('Calzini'), findsNothing);
    await app.finish();
  });

  testWidgets('Sposta verso una casa con spazi: casa, poi spazio', (
    tester,
  ) async {
    final app = await openHouse(tester, kSeaHouseId);
    await app.longPress(find.text('Infradito'));
    await app.tap(find.byKey(const Key('selection_move')));
    await app.tap(find.text('Casa Milano'));
    expect(find.text('Armadio camera'), findsOneWidget);
    await app.tap(find.text('Armadio camera'));
    expect(find.byType(BulkMoveSheet), findsNothing);
    expect(find.text('Infradito'), findsNothing);
    await app.finish();
  });

  testWidgets('dal ⋯: Seleziona oggetti apre la selezione vuota', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(find.byIcon(Icons.more_horiz));
    await app.tap(find.text('Seleziona oggetti'));
    final move = tester.widget<DsBarItem>(
      find.byKey(const Key('selection_move')),
    );
    expect(move.onTap, isNull);
    await app.finish();
  });
```

  (`openHouse` c'è dal blocco 2; se manca, aggiungilo come in quel piano. Verifica nel seed che "Casa al mare" non abbia spazi, che "Infradito" sia suo e che "Armadio camera" sia di Casa Milano.)

- [x] **Step 2:** i nuovi test FAIL.

- [x] **Step 3: `bulk_move_sheet.dart`**
  - Via `_spaceConfirmed`, `_confirm`, il `SizedBox` e il `UniversalActionBar` in fondo, l'import di `universal_action_bar.dart`.
  - Metodi nuovi:

```dart
  void _finish(HouseModel house, String? spaceId) {
    Navigator.of(context).pop(
      BulkMoveDestination(
        houseId: house.id,
        houseDisplayName: house.displayName,
        spaceId: spaceId,
      ),
    );
  }

  /// Casa senza spazi: si sposta al primo tocco. Con spazi: si mostrano,
  /// e il tocco sullo spazio sposta.
  Future<void> _selectHouse(HouseModel house) async {
    final spaces = await ref.read(spaceNotifierProvider(house.id).future);
    if (!mounted) return;
    if (spaces.isEmpty) {
      _finish(house, null);
      return;
    }
    setState(() => _selectedHouse = house);
  }
```

  - Nella sezione degli spazi gli `onTap` diventano `() => _finish(_selectedHouse!, null)` per "Senza spazio" e `() => _finish(_selectedHouse!, s.id)` per gli spazi; via i `trailing` con la spunta degli spazi (si chiude al tocco, la spunta non si vedrebbe). Il `_selectedSpaceId` non serve più.

- [x] **Step 4: `house_manage_sheet.dart`** — parametro `VoidCallback? onSelectItems` in `showHouseManageSheet`; come prima voce, prima di "Modifica info":

```dart
          if (onSelectItems != null)
            ListTile(
              leading: const Icon(Icons.checklist),
              title: Text('items.select_items'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                onSelectItems();
              },
            ),
```

  In `house_detail_screen.dart`, `_showManageSheet` passa `onSelectItems: () => ref.read(itemSelectionNotifierProvider.notifier).toggleMode(),`.

- [x] **Step 5: verifica** — `flutter test test/features/houses test/features/items && dart analyze && flutter test` → verdi.

- [x] **Step 6: commit**

```bash
git add lib/features/items/view/bulk_move_sheet.dart lib/features/houses test/features/houses
git commit -m "feat(casa): Sposta al tocco della casa o dello spazio, Seleziona oggetti dal menu"
```

---

### Task 4: screenshot e documentazione

**Files:**
- Modify: `test/screenshots/ui_screenshots_test.dart` (flusso `04-dettaglio-casa`, scenari 5-8)
- Modify: `docs/ui-flows.md` (`git add -f`); `ARCHITECTURE.md` solo locale

- [x] **Step 1:** scenario 5: descrizione `'Selezione: caselle arancio, velo neutro, barra Sposta · In viaggio · Elimina.'`. Scenario 6: `await app.tap(_text('common.move'));` diventa `await app.tap(find.byKey(const Key('selection_move')));`, descrizione `'Foglio "Sposta": tocco sulla casa (o sullo spazio) e l\'oggetto è spostato.'`. Scenario 7: `await app.tap(_icon(Icons.luggage_outlined).last);` diventa `await app.tap(find.byKey(const Key('selection_trip')));`. Scenario 8: descrizione con "Seleziona oggetti" in cima. Nuovo scenario 18 `'sposta-oggetti', 'scelta-spazio'`: da Casa al mare, long press su "Infradito", `selection_move`, tocco su "Casa Milano" (si vedono gli spazi).
- [x] **Step 2:** `flutter test test/screenshots/ui_screenshots_test.dart --dart-define=UI_SCREENSHOTS=true` → verdi; guarda 04/05-08 e 18 in chiaro e scuro, e la barra di navigazione di 03-case (deve essere identica a prima).
- [x] **Step 3:** `docs/ui-flows.md`: selezione, foglio Sposta, Seleziona oggetti. `ARCHITECTURE.md`: `DsFloatingBar`/`DsBarItem` condivisi da navigazione e selezione; togli dallo spec la sezione "Punti aperti dal blocco 1" il punto sulla tastiera (risolto) e lascia quello sul cursore.
- [x] **Step 4: commit**

```bash
git add test/screenshots/ui_screenshots_test.dart
git add -f docs/ui-flows.md
git commit -m "test(screenshot): selezione e foglio Sposta nuovi; flussi UI aggiornati"
```

---

### Task 5: PR

- [x] `git push -u origin feat/casa-selezione`; PR verso `develop` "Casa: selezione multipla leggera e Sposta al tocco", con chiusura `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

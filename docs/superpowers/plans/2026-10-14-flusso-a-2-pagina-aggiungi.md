# Flusso A · Blocco 2: pagina "aggiungi", pillole larghe, stato vuoto AI-first

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Quando si tocca "Aggiungi oggetto…" la lista della casa sparisce e resta una pagina pulita che dice cosa c'è già ("Già in casa") e cosa si è appena aggiunto ("Aggiunti ora"); pillole delle categorie larghe quanto il campo con il nome intero; via il "+" del form completo; stato vuoto della casa con la scansione AI in primo piano.

**Architecture:** Il `FocusNode` del rapid fire passa alla schermata della casa, che apre e chiude la "sessione di aggiunta" (`_addBaseline`: gli id presenti all'apertura). La pagina usa `matchesSearch` e `ItemCard` già esistenti; le righe stanno in un `TapRegion` dello stesso gruppo del campo, così toccarle non chiude il campo. Lo stato vuoto diventa un **template**: `DsEmptyState` prende contenuti strutturati (icona, titolo, CTA con etichetta e icona, link) che ogni schermata personalizza; il link è il componente condiviso `DsLinkButton`, lo stesso del foglio Crea. `ItemsEmptyState` sparisce: casa e selettore del viaggio usano il template con i propri contenuti.

**Tech Stack:** Flutter 3.38, Riverpod 2.5, easy_localization, mocktail; test di widget con l'harness degli screenshot.

**Spec:** `docs/superpowers/specs/2026-10-14-flusso-a-dettaglio-casa-design.md`, sezione 4 "Pagina aggiungi" e sezione "Analytics".

**Parte da:** `develop` con il blocco 1 (PR #27) già dentro.

## Global Constraints

- Branch `feat/casa-pagina-aggiungi` da `origin/develop`; PR verso `develop` (squash). Mai push su `develop`/`main`.
- Niente colori, spaziature o font scritti a mano: `colorScheme.*`, `context.spacingXs/Sm/Md`, `context.iconSizeSm`, `AppConstants.*`, `textTheme.*`.
- Riusare: `ItemCard`, `DsGroupHeader`, `matchesSearch`, `DsButton`, `CategoryPill`.
- **Stato vuoto come template** (decisione dell'utente): `DsEmptyState` e `RefreshableEmptyState` hanno parametri strutturati `ctaLabel`, `ctaIcon`, `onCta`, `ctaVariant` (default `DsButtonVariant.primary`), `ctaKey`, `linkLabel`, `onLink`, `linkKey`. La CTA è un `DsButton`, il link un `DsLinkButton` (testo + `Icons.arrow_forward` a destra, `iconSizeSm`), uno sotto l'altra con `spacingSm` in mezzo. `action` resta solo per contenuti che non sono "bottone + link" (la riga tratteggiata delle case) e non si usa insieme ai parametri strutturati (assert). Ogni schermata decide i propri contenuti.
- "Già in casa" compare da **2** caratteri digitati (spazi esclusi), cerca tra gli oggetti presenti all'apertura della pagina (tutta la casa, qualunque spazio), con `matchesSearch`. Gli oggetti salvati in questa sessione stanno solo in "Aggiunti ora".
- Etichette dei gruppi della pagina: `DsGroupHeader(label:, count:)` senza `expanded` (non chiudibili).
- Pillole delle categorie: fila alta quanto il campo (`widget.height`), larga quanto il campo, quattro pillole di uguale larghezza con icona sopra e nome intero sotto (`category.icon`, `category.displayName`, `textTheme.labelSmall`).
- Evento nuovo: `add_existing_match_tapped` con `{position}` (1 = prima riga di "Già in casa").
- Ogni stringa nuova in `it-IT.json` **e** `en-US.json`.
- Dopo ogni task: `dart analyze` pulito e i test indicati verdi; commit appena verde (italiano, riga `Co-Authored-By:` del modello che scrive il commit).

---

### Task 1: rapid fire senza "+", con pillole larghe e focus condivisibile

**Files:**
- Modify: `lib/features/items/widgets/category_pill.dart`
- Modify: `lib/features/items/widgets/rapid_fire_input.dart`
- Modify: `lib/features/houses/view/house_detail_screen.dart` (solo: togli l'argomento `onOpenFullForm:` da `RapidFireInput(...)` in `_HouseNormalActionBar`)
- Test: `test/features/items/widgets/rapid_fire_input_test.dart`

**Interfaces:**
- Produces: `const Object rapidFireTapRegionGroup` (top-level in `rapid_fire_input.dart`); `RapidFireInput({required String houseId, bool autofocus = false, String? currentSpaceId, ValueChanged<bool>? onExpandedChanged, ValueChanged<String>? onTextChanged, FocusNode? focusNode, double height = 50.0})`. **Rimosso** `onOpenFullForm`.

- [ ] **Step 1: test che falliscono** — aggiungi in fondo a `rapid_fire_input_test.dart` (stesso stile dei due test esistenti, senza EasyLocalization: `displayName` restituisce la chiave, es. `categories.vestiti`):

```dart
  Future<void> pumpInput(
    WidgetTester tester, {
    ValueChanged<String>? onTextChanged,
    ValueChanged<bool>? onExpandedChanged,
    FocusNode? focusNode,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RapidFireInput(
                  houseId: 'h1',
                  onTextChanged: onTextChanged,
                  onExpandedChanged: onExpandedChanged,
                  focusNode: focusNode,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('pillole col nome intero, tutte larghe uguali', (tester) async {
    await pumpInput(tester);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('categories.vestiti'), findsOneWidget);
    expect(find.text('categories.varie'), findsOneWidget);
    final pills = find.byType(CategoryPill);
    final first = tester.getSize(pills.at(0)).width;
    for (var i = 1; i < ItemCategory.values.length; i++) {
      expect(tester.getSize(pills.at(i)).width, first);
    }
  });

  testWidgets('niente "+" per il form completo', (tester) async {
    await pumpInput(tester);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('il testo scritto arriva a onTextChanged', (tester) async {
    String? last;
    await pumpInput(tester, onTextChanged: (v) => last = v);
    await tester.enterText(find.byType(TextField), 'calz');
    expect(last, 'calz');
  });

  testWidgets('usa il FocusNode passato da fuori', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    var expanded = false;
    await pumpInput(
      tester,
      focusNode: node,
      onExpandedChanged: (v) => expanded = v,
    );
    node.requestFocus();
    await tester.pumpAndSettle();
    expect(expanded, isTrue);
  });
```

- [ ] **Step 2: verifica che falliscano**

Run: `flutter test test/features/items/widgets/rapid_fire_input_test.dart`
Expected: FAIL (parametri `onTextChanged`/`focusNode` inesistenti).

- [ ] **Step 3: `category_pill.dart`** — sostituisci il `build` e togli `_iconForCategory`/`_labelForCategory` (ora si usano `category.icon` e `category.displayName` dell'estensione in `item_model.dart`):

```dart
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryColor = colorScheme.primary;

    final Color backgroundColor;
    final Color foregroundColor;
    final Color borderColor;

    switch (pillState) {
      case CategoryPillState.inactive:
        backgroundColor = colorScheme.surfaceContainerLow;
        foregroundColor = colorScheme.onSurfaceVariant;
        borderColor = Colors.transparent;
      case CategoryPillState.inferred:
        backgroundColor = categoryColor.withValues(alpha: 0.1);
        foregroundColor = categoryColor;
        borderColor = categoryColor;
      case CategoryPillState.forced:
        backgroundColor = categoryColor;
        foregroundColor = colorScheme.onPrimary;
        borderColor = categoryColor;
    }

    // Icona sopra e nome intero sotto, come le voci della barra di
    // navigazione: con la pagina "aggiungi" lo spazio c'è e le iniziali
    // (V, T, E, ?) non servono più.
    return Semantics(
      button: true,
      selected: pillState == CategoryPillState.forced,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: context.spacingXs),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, size: context.iconSizeSm, color: foregroundColor),
              SizedBox(height: context.spacingXs / 4),
              // scaleDown: con caratteri di sistema grandi o in inglese
              // ("Electronics") il nome si stringe invece di sforare.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  category.displayName,
                  maxLines: 1,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: foregroundColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

(Il grigio delle pillole inattive passa da `onSurfaceVariant` al 50% a `onSurfaceVariant` pieno: con il nome intero il 50% non era leggibile.)

- [ ] **Step 4: `rapid_fire_input.dart`**

1. In cima al file, dopo gli import:

```dart
/// Gruppo dei tocchi "dentro" il rapid fire. Chi mostra contenuti legati al
/// campo (la pagina "aggiungi" della casa) li avvolge in un [TapRegion] con
/// questo gruppo: toccarli non chiude il campo.
const Object rapidFireTapRegionGroup = _RapidFireTapRegionGroup();

class _RapidFireTapRegionGroup {
  const _RapidFireTapRegionGroup();
}
```

2. Campi del widget: togli `onOpenFullForm`; aggiungi

```dart
  /// Ogni modifica del testo (anche lo svuotamento dopo il salvataggio).
  final ValueChanged<String>? onTextChanged;

  /// Focus del campo, se lo gestisce il chiamante (la casa lo usa per aprire
  /// la pagina "aggiungi" dallo stato vuoto). Se nullo il campo ne crea uno.
  final FocusNode? focusNode;
```

con `this.onTextChanged, this.focusNode,` nel costruttore.

3. Nello `State`: sostituisci `final _focusNode = FocusNode();` con

```dart
  FocusNode? _ownFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());
```

   e in `dispose` sostituisci `_focusNode.dispose();` con `_ownFocusNode?.dispose();` (il listener si toglie comunque con `_focusNode.removeListener(_onFocusChanged);` prima).

4. `_handleTextChanged`: prima riga `widget.onTextChanged?.call(value);`. In `_handleSubmit`, subito dopo `_textController.clear();`: `widget.onTextChanged?.call('');`.

5. `TapRegion(` → `TapRegion(groupId: rapidFireTapRegionGroup,`.

6. Fila delle categorie: il `child:` del `Padding(padding: EdgeInsets.only(bottom: context.spacingSm), …)` diventa

```dart
                        // Larga quanto il campo, quattro pillole uguali.
                        child: SizedBox(
                          height: widget.height,
                          child: Row(
                            children: [
                              for (final category in ItemCategory.values) ...[
                                if (category != ItemCategory.values.first)
                                  SizedBox(width: context.spacingXs),
                                Expanded(
                                  child: CategoryPill(
                                    category: category,
                                    pillState: _computePillState(category),
                                    onTap: () => _toggleForcedCategory(category),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
```

   e togli il commento sul `FittedBox` che non c'è più.

7. Cancella il blocco `// Pulsante "+" visibile solo in stato espanso` (l'`if (_isExpanded) ...[ IconButton(...), AppSpacing.hGapSm ]`). Il padding sinistro del contenitore diventa fisso: `left: context.spacingMd,`.

8. In `house_detail_screen.dart`, nel `RapidFireInput(...)` di `_HouseNormalActionBar`, togli l'argomento `onOpenFullForm: (name, category) => showAddEditItemSheet(...)`. Se `add_edit_item_screen.dart` resta importato ma inutilizzato in quel file, togli l'import.

- [ ] **Step 5: verifica**

Run: `flutter test test/features/items/widgets/rapid_fire_input_test.dart && dart analyze`
Expected: tutti verdi (6 test), analisi pulita.

- [ ] **Step 6: commit**

```bash
git add lib/features/items/widgets lib/features/houses/view/house_detail_screen.dart test/features/items/widgets/rapid_fire_input_test.dart
git commit -m "feat(rapid-fire): pillole larghe col nome intero, via il form completo, focus condivisibile"
```

---

### Task 2: stato vuoto come template, con `DsLinkButton`

**Files:**
- Create: `lib/shared/widgets/ds_link_button.dart`
- Modify: `lib/shared/widgets/ds_empty_state.dart`, `lib/shared/widgets/refreshable_empty_state.dart`
- Modify: `lib/shared/widgets/widgets.dart` (export di `ds_link_button.dart`)
- Modify: `lib/shared/widgets/create_sheet.dart` (il `TextButton.icon` con `Key('create_manual_items')` diventa `DsLinkButton`)
- Modify (passano ai parametri strutturati al posto di `action: DsButton(...)`): `lib/features/trips/view/trips_screen.dart`, `lib/features/trips/view/trip_detail_screen.dart`, `lib/features/trips/view/widgets/trip_edit_placeholder.dart`, `lib/features/houses/view/house_detail_screen.dart` (casa non trovata), e ogni altro `DsEmptyState`/`RefreshableEmptyState` con `action: DsButton(...)` trovato da `grep -rn "action: DsButton" lib`
- Modify: `lib/features/items/view/items_screen.dart` e `lib/features/trips/view/trip_items_selector.dart` (usano il template al posto di `ItemsEmptyState`)
- Delete: `lib/features/items/widgets/items_empty_state.dart`, `test/features/items/widgets/items_empty_state_test.dart`
- Test: `test/shared/widgets/ds_empty_state_test.dart` (nuovo); `test/shared/widgets/create_sheet_test.dart` e gli altri test esistenti restano verdi

**Interfaces:**
- Produces: `DsLinkButton({Key? key, required String label, required VoidCallback onPressed})`; `DsEmptyState({..., String? ctaLabel, IconData? ctaIcon, VoidCallback? onCta, DsButtonVariant ctaVariant = DsButtonVariant.primary, Key? ctaKey, String? linkLabel, VoidCallback? onLink, Key? linkKey, Widget? action})` e gli stessi parametri in `RefreshableEmptyState`; `ItemsScreen(..., VoidCallback? onWriteManually)`.

- [ ] **Step 1: test che falliscono** — `test/shared/widgets/ds_empty_state_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:pack_log/shared/widgets/ds_empty_state.dart';
import 'package:pack_log/shared/widgets/ds_link_button.dart';
import 'package:pack_log/shared/widgets/refreshable_empty_state.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
  );

  testWidgets('CTA e link personalizzati, la CTA sopra il link', (
    tester,
  ) async {
    var cta = 0;
    var link = 0;
    await pump(
      tester,
      DsEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nessun oggetto',
        ctaLabel: 'Scansiona con AI',
        ctaIcon: Icons.auto_awesome,
        onCta: () => cta++,
        linkLabel: 'Scrivili a mano',
        onLink: () => link++,
      ),
    );
    expect(find.byType(DsButton), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byType(DsLinkButton), findsOneWidget);
    expect(
      tester.getCenter(find.text('Scansiona con AI')).dy,
      lessThan(tester.getCenter(find.text('Scrivili a mano')).dy),
    );
    await tester.tap(find.text('Scansiona con AI'));
    await tester.tap(find.text('Scrivili a mano'));
    expect((cta, link), (1, 1));
  });

  testWidgets('senza contenuti niente bottoni', (tester) async {
    await pump(
      tester,
      const DsEmptyState(icon: Icons.search_off, title: 'Niente'),
    );
    expect(find.byType(DsButton), findsNothing);
    expect(find.byType(DsLinkButton), findsNothing);
  });

  testWidgets('la versione con pull-to-refresh passa gli stessi contenuti', (
    tester,
  ) async {
    await pump(
      tester,
      RefreshableEmptyState(
        onRefresh: () async {},
        icon: Icons.inventory_2_outlined,
        title: 'Nessun oggetto',
        ctaLabel: 'Scansiona con AI',
        onCta: () {},
        linkLabel: 'Scrivili a mano',
        onLink: () {},
      ),
    );
    expect(find.byType(DsButton), findsOneWidget);
    expect(find.byType(DsLinkButton), findsOneWidget);
  });

  testWidgets('l icona resta neutra', (tester) async {
    await pump(
      tester,
      DsEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nessun oggetto',
        ctaLabel: 'Scansiona con AI',
        onCta: () {},
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.inventory_2_outlined));
    expect(icon.color, isNot(AppTheme.light.colorScheme.primary));
  });
}
```

- [ ] **Step 2:** `flutter test test/shared/widgets/ds_empty_state_test.dart` → FAIL.

- [ ] **Step 3: `ds_link_button.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Link testuale con la freccia a destra: la strada secondaria accanto a
/// una CTA (es. "Non sono vestiti? Scrivili a mano →" sotto "Scansiona con
/// AI"). Lo usano il foglio Crea e il template dello stato vuoto.
class DsLinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const DsLinkButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.arrow_forward, size: context.iconSizeSm),
      iconAlignment: IconAlignment.end,
      label: Text(label),
    );
  }
}
```

- [ ] **Step 4: `ds_empty_state.dart`** — aggiungi i campi e componi CTA e link al posto del solo `action`:

```dart
  /// Template: azione principale (un [DsButton]).
  final String? ctaLabel;
  final IconData? ctaIcon;
  final VoidCallback? onCta;
  final DsButtonVariant ctaVariant;
  final Key? ctaKey;

  /// Template: strada secondaria sotto la CTA (un [DsLinkButton]).
  final String? linkLabel;
  final VoidCallback? onLink;
  final Key? linkKey;

  /// Contenuto libero, solo quando non è "bottone + link" (es. la riga
  /// tratteggiata "Aggiungi la tua prima casa"). Non insieme al template.
  final Widget? action;
```

nel costruttore (`this.ctaVariant = DsButtonVariant.primary` e gli altri opzionali) con

```dart
  }) : assert(
         action == null || (ctaLabel == null && linkLabel == null),
         'action è per contenuti liberi: non insieme a CTA e link',
       );
```

e nel `build`, al posto del blocco `if (action != null) ...[ … ]`:

```dart
          if (action != null) ...[
            SizedBox(height: theme.stateSpacingLg),
            action!,
          ],
          if (ctaLabel != null && onCta != null) ...[
            SizedBox(height: theme.stateSpacingLg),
            DsButton(
              key: ctaKey,
              label: ctaLabel!,
              icon: ctaIcon,
              variant: ctaVariant,
              onPressed: onCta,
            ),
          ],
          if (linkLabel != null && onLink != null) ...[
            SizedBox(height: context.spacingSm),
            DsLinkButton(key: linkKey, label: linkLabel!, onPressed: onLink!),
          ],
```

(import `ds_button.dart`, `ds_link_button.dart`, `../theme/app_spacing.dart`). Aggiorna il commento di classe: è il template degli stati vuoti, ogni schermata ne sceglie i contenuti.

- [ ] **Step 5: `refreshable_empty_state.dart`** — stessi campi (`ctaLabel`, `ctaIcon`, `onCta`, `ctaVariant`, `ctaKey`, `linkLabel`, `onLink`, `linkKey`) passati tali e quali al `DsEmptyState` interno.

- [ ] **Step 6: chiamanti**
  1. `create_sheet.dart`: il `TextButton.icon(key: const Key('create_manual_items'), …)` diventa

```dart
                child: DsLinkButton(
                  key: const Key('create_manual_items'),
                  label: 'create_sheet.manual_link'.tr(),
                  onPressed: () => _choose(CreateAction.manualItems, house.id),
                ),
```

  2. Ogni `action: DsButton(label: X, icon: Y, variant: Z, onPressed: W)` in uno stato vuoto diventa `ctaLabel: X, ctaIcon: Y, ctaVariant: Z, onCta: W` (con `ctaKey:` se il `DsButton` aveva una key). La riga tratteggiata di `houses_screen.dart` resta in `action:`.
  3. `items_screen.dart`: i due `ItemsEmptyState` diventano `RefreshableEmptyState`. Quello della ricerca: `onRefresh`, `icon: Icons.search_off`, `title: 'items.no_search_results'.tr()`. Quello della casa vuota:

```dart
                return RefreshableEmptyState(
                  key: widget.firstGroupKey,
                  onRefresh: _onRefresh,
                  icon: Icons.inventory_2_outlined,
                  title: widget.selectedSpaceId != null
                      ? 'items.no_items_in_space'.tr()
                      : 'items.no_items'.tr(),
                  // Prima la scansione AI, la strada che dà agli oggetti foto
                  // e metadati; poi la scrittura a mano.
                  ctaLabel: 'create_sheet.ai_scan'.tr(),
                  ctaIcon: Icons.auto_awesome,
                  onCta: () => context.push('/houses/${widget.houseId}/ai-import'),
                  linkLabel: 'create_sheet.manual_link'.tr(),
                  linkKey: const Key('items_empty_manual'),
                  onLink:
                      widget.onWriteManually ??
                      () => context.push('/houses/${widget.houseId}?add=manual'),
                );
```

     con il campo nuovo `final VoidCallback? onWriteManually;` (doc: "Stato vuoto, "scrivili a mano": la casa passa il comando che apre la pagina "aggiungi"") nel costruttore, e gli import di `refreshable_empty_state.dart` e `go_router`. Riporta nei due rami i titoli che `ItemsEmptyState` riceveva oggi (leggili prima di cancellarlo).
  4. `trip_items_selector.dart`: il `ItemsEmptyState(...)` diventa `DsEmptyState(...)` con lo stesso titolo; se c'è una casa e nessun filtro di categoria (la condizione di oggi su `houseId`), CTA "Scansiona con AI" verso `/houses/$houseId/ai-import` e link "scrivili a mano" verso `/houses/$houseId?add=manual`, con `ctaKey: const Key('trip_items_empty_add')` per i test esistenti.
  5. Cancella `items_empty_state.dart` e il suo test (`git rm`); i casi che il test copriva sono ora in `ds_empty_state_test.dart`.

- [ ] **Step 7: verifica**

Run: `flutter test test/shared test/features && dart analyze`
Expected: verdi, analisi pulita. Se un test esistente cercava il vecchio bottone dello stato vuoto, aggiornalo al nuovo contenuto e scrivilo nel report.

- [ ] **Step 8: commit**

```bash
git add lib test
git commit -m "feat(ds): stato vuoto come template con CTA e link; DsLinkButton condiviso col foglio Crea"
```

---

### Task 3: evento `add_existing_match_tapped`

**Files:**
- Modify: `lib/core/analytics/core_analytics_service.dart` (dopo la sezione `search_`)
- Test: `test/core/analytics/core_analytics_service_test.dart` (nel `group('search_', …)` o in un nuovo `group('add_', …)` subito dopo)

**Interfaces:**
- Produces: `void trackAddExistingMatchTapped({required int position})`.

- [ ] **Step 1: test che fallisce**

```dart
  group('add_', () {
    test('trackAddExistingMatchTapped logs add_existing_match_tapped', () async {
      service.trackAddExistingMatchTapped(position: 1);
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'add_existing_match_tapped',
          properties: {'position': 1},
        ),
      ).called(1);
    });
  });
```

- [ ] **Step 2:** `flutter test test/core/analytics/core_analytics_service_test.dart` → FAIL.

- [ ] **Step 3: implementazione**

```dart
  // ── add_ ──────────────────────────────────────────────────────────────────

  /// Nella pagina "aggiungi" della casa si è aperto un oggetto di "Già in
  /// casa": la pagina ha evitato un doppione. `position` parte da 1.
  void trackAddExistingMatchTapped({required int position}) {
    _safeLogEvent(
      'add_existing_match_tapped',
      properties: {'position': position},
    );
  }
```

- [ ] **Step 4:** stesso comando → PASS.

- [ ] **Step 5: commit**

```bash
git add lib/core/analytics/core_analytics_service.dart test/core/analytics/core_analytics_service_test.dart
git commit -m "feat(analytics): evento add_existing_match_tapped"
```

---

### Task 4: pagina "aggiungi" nella casa

**Files:**
- Modify: `lib/features/houses/view/house_detail_screen.dart`
- Modify: `assets/translations/it-IT.json`, `assets/translations/en-US.json`
- Test: `test/features/houses/view/house_detail_screen_test.dart` (aggiunte)

**Interfaces:**
- Consumes: `rapidFireTapRegionGroup`, `RapidFireInput(focusNode:, onTextChanged:)` (task 1); `ItemsScreen(onWriteManually:)` (task 2); `trackAddExistingMatchTapped` (task 3); `matchesSearch`, `DsGroupHeader`, `ItemCard(onOpened:)` (blocco 1).
- [ ] **Step 1: stringhe** — oggetto `items`: it `"already_here": "Già in casa"`, `"added_now": "Aggiunti ora"`; en `"already_here": "Already at home"`, `"added_now": "Added now"`.

- [ ] **Step 2: test che falliscono** — in `house_detail_screen_test.dart` (riusa `openHome`, `analytics` e lo stile esistente; ogni test finisce con `await app.finish();`). Aggiungi un helper per aprire una casa qualsiasi:

```dart
  Future<ScreenshotApp> openHouse(WidgetTester tester, String id) async {
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.light,
      setup: AppSetup(
        extraOverrides: [
          coreAnalyticsServiceProvider.overrideWithValue(analytics),
        ],
      ),
    );
    await app.go('/');
    await app.push('/houses/$id');
    return app;
  }

  Finder rapidFire() => find.byType(TextField).last;

  testWidgets('toccando il campo la lista sparisce, e con lei 🔍 e ⋯', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(rapidFire());
    expect(find.text('Vestiti · 7'), findsNothing);
    expect(find.byKey(const Key('house_search')), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    await app.finish();
  });

  testWidgets('scrivendo compare Già in casa', (tester) async {
    final app = await openHome(tester);
    await app.tap(rapidFire());
    await app.enterText(rapidFire(), 'calz');
    expect(find.text('Già in casa · 1'), findsOneWidget);
    expect(find.text('Calzini'), findsOneWidget);
    await app.finish();
  });

  testWidgets('un oggetto salvato va in Aggiunti ora, non in Già in casa', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(rapidFire());
    await app.enterText(rapidFire(), 'Felpa verde');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await app.settle();
    await app.enterText(rapidFire(), 'fel');
    expect(find.text('Aggiunti ora · 1'), findsOneWidget);
    expect(find.text('Felpa verde'), findsOneWidget);
    expect(find.textContaining('Già in casa'), findsNothing);
    await app.finish();
  });

  testWidgets('toccare un Già in casa apre l oggetto e registra l evento', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(rapidFire());
    await app.enterText(rapidFire(), 'calz');
    await app.tap(find.text('Calzini'));
    verify(
      () => analytics.trackAddExistingMatchTapped(position: 1),
    ).called(1);
    await app.finish();
  });

  testWidgets('indietro chiude la pagina e torna la lista', (tester) async {
    final app = await openHome(tester);
    await app.tap(rapidFire());
    await tester.binding.handlePopRoute();
    await app.settle();
    expect(find.text('Vestiti · 7'), findsOneWidget);
    await app.finish();
  });

  testWidgets('casa vuota: scansione AI e scrivili a mano', (tester) async {
    final app = await openHouse(tester, kEmptyHouseId);
    expect(find.text('Scansiona con AI'), findsOneWidget);
    await app.tap(find.byKey(const Key('items_empty_manual')));
    final field = tester.widget<TextField>(rapidFire());
    expect(field.focusNode?.hasFocus, isTrue);
    await app.finish();
  });
```

Verifica in `seed.dart` che `kEmptyHouseId` esista e sia senza oggetti, e che nessun oggetto di Casa Milano contenga "fel".

- [ ] **Step 3:** `flutter test test/features/houses/view/house_detail_screen_test.dart` → i nuovi test FAIL.

- [ ] **Step 4: implementazione in `house_detail_screen.dart`**

1. Stato (accanto a `_isRapidFireExpanded`):

```dart
  /// Focus del rapid fire, condiviso con lo stato vuoto: "scrivili a mano"
  /// apre la pagina "aggiungi" mettendo il focus qui.
  final _rapidFireFocus = FocusNode();

  /// Pagina "aggiungi": `null` = chiusa; altrimenti gli id degli oggetti
  /// presenti quando si è aperta (quelli nuovi sono gli "Aggiunti ora").
  Set<String>? _addBaseline;
  String _addQuery = '';

  bool get _isAdding => _addBaseline != null;
```

   In `dispose`: `_rapidFireFocus.dispose();`.

2. Metodi:

```dart
  void _onRapidFireExpanded(bool expanded) {
    setState(() {
      _isRapidFireExpanded = expanded;
      if (expanded) {
        _addBaseline ??= {
          for (final item
              in ref.read(itemNotifierProvider(widget.houseId)).valueOrNull ??
                  const <ItemModel>[])
            item.id,
        };
      } else if (ModalRoute.of(context)?.isCurrent ?? true) {
        // Il campo ha perso il focus perché si è usciti (indietro, tocco
        // fuori): la pagina si chiude. Se invece sopra c'è un foglio (la
        // scheda di un oggetto aperta da qui) la pagina resta, e al ritorno
        // il focus torna sul campo.
        _addBaseline = null;
        _addQuery = '';
      }
    });
  }

  void _closeAddPage() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _addBaseline = null;
      _addQuery = '';
    });
  }
```

3. `PopScope`: `canPop: !isSelectionMode && _search == null && !_isAdding,`; nel callback, dopo il ramo della ricerca: `} else if (_isAdding) { _closeAddPage(); }`.

4. `_HouseNormalAppBar`: nuovi parametri `required bool isAdding, required VoidCallback onCloseAdding`. Nel ramo normale:

```dart
      leading: isAdding
          // Dentro il gruppo del rapid fire: il tocco non chiude il campo
          // prima di arrivare al bottone, che chiude la pagina da sé.
          ? TapRegion(
              groupId: rapidFireTapRegionGroup,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'common.back'.tr(),
                onPressed: onCloseAdding,
              ),
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.popOrGo('/'),
            ),
```

   e `actions: isAdding ? null : [ …🔍 e ⋯ come oggi… ],`. Dal `build` passa `isAdding: _isAdding, onCloseAdding: _closeAddPage`.

5. `body:` diventa `_isAdding ? _AddPage(...) : Column(...)` (la `Column` di oggi invariata), con

```dart
                ? _AddPage(
                    houseId: widget.houseId,
                    query: _addQuery,
                    baselineIds: _addBaseline!,
                    onExistingOpened: (position) => _analytics
                        .trackAddExistingMatchTapped(position: position),
                  )
```

   e nell'`ItemsScreen(...)` della `Column`: `onWriteManually: _rapidFireFocus.requestFocus,`.

6. `_HouseNormalActionBar`: nuovi campi `final FocusNode focusNode; final ValueChanged<String> onTextChanged;` passati a `RapidFireInput(focusNode: focusNode, onTextChanged: onTextChanged, …)`. Dal `build`: `focusNode: _rapidFireFocus, onTextChanged: (q) => setState(() => _addQuery = q), onExpandedChanged: _onRapidFireExpanded,`.

7. Classe nuova in fondo al file:

```dart
/// Pagina "aggiungi": mentre si scrive nel rapid fire la casa sparisce e
/// restano solo le risposte utili. "Già in casa": oggetti presenti
/// all'apertura che somigliano al testo. "Aggiunti ora": quelli salvati in
/// questa pagina. Vuota se non c'è niente da dire.
class _AddPage extends ConsumerWidget {
  final String houseId;
  final String query;
  final Set<String> baselineIds;
  final void Function(int position) onExistingOpened;

  const _AddPage({
    required this.houseId,
    required this.query,
    required this.baselineIds,
    required this.onExistingOpened,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(itemNotifierProvider(houseId)).valueOrNull ??
        const <ItemModel>[];
    final quantitiesOnTrip = ref.watch(
      itemQuantitiesOnTripFromHouseProvider(houseId),
    );
    final matches = query.trim().length < 2
        ? const <ItemModel>[]
        : items
              .where(
                (i) =>
                    baselineIds.contains(i.id) && matchesSearch(i.name, query),
              )
              .toList();
    final added = items.where((i) => !baselineIds.contains(i.id)).toList();

    Widget card(ItemModel item, {VoidCallback? onOpened}) => ItemCard(
      item: item,
      houseId: houseId,
      quantityOnTrip: quantitiesOnTrip[item.id] ?? 0,
      onOpened: onOpened,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
      // Solo il contenuto è "dentro" il campo: toccare lo spazio vuoto sotto
      // chiude la pagina, toccare una riga apre l'oggetto.
      child: TapRegion(
        groupId: rapidFireTapRegionGroup,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (matches.isNotEmpty) ...[
              DsGroupHeader(
                label: 'items.already_here'.tr(),
                count: matches.length,
              ),
              for (final (i, item) in matches.indexed)
                card(item, onOpened: () => onExistingOpened(i + 1)),
            ],
            if (added.isNotEmpty) ...[
              DsGroupHeader(label: 'items.added_now'.tr(), count: added.length),
              for (final item in added) card(item),
            ],
          ],
        ),
      ),
    );
  }
}
```

   Import necessari: `../../items/view/item_card.dart`, `../../../shared/helpers/search_match.dart`, `../../../shared/widgets/ds_group_header.dart`, e `rapidFireTapRegionGroup` arriva da `rapid_fire_input.dart` (già importato). `itemQuantitiesOnTripFromHouseProvider` sta in `trip_items_status_provider.dart` (già importato).

- [ ] **Step 5: verifica**

Run: `flutter test test/features/houses && dart analyze && flutter test`
Expected: tutto verde, analisi pulita.

- [ ] **Step 6: commit**

```bash
git add lib/features/houses assets/translations test/features/houses
git commit -m "feat(casa): pagina aggiungi con Già in casa e Aggiunti ora"
```

---

### Task 5: screenshot e documentazione

**Files:**
- Modify: `test/screenshots/ui_screenshots_test.dart`
- Modify: `docs/ui-flows.md` (tracciato: `git add -f`); `ARCHITECTURE.md` (solo locale, non va in git)

- [ ] **Step 1: scenari**
  - Flusso `04-dettaglio-casa`, scenario 4 (`rapid-fire`): descrizione `'Pagina "aggiungi": la casa sparisce, sopra il campo le pillole delle categorie col nome intero.'` (passi invariati).
  - Nuovo scenario 17 nello stesso flusso:

```dart
    Scenario(
      17,
      'dettaglio-casa',
      'aggiungi-gia-in-casa',
      route: '/houses/:id',
      source: _houseDetailSrc,
      description: 'Pagina "aggiungi": scrivendo "calz" compare Già in casa.',
      steps: (app) async {
        await _houseDetail(app);
        await app.tap(find.byType(TextField).last);
        await app.enterText(find.byType(TextField).last, 'calz');
      },
    ),
```

  - Flusso `05-oggetti`, scenario 1: il "+" non c'è più. Diventa:

```dart
    Scenario(
      1,
      'oggetto-aggiungi',
      'da-crea',
      source: _houseDetailSrc,
      description:
          'Crea → "scrivili a mano": pagina "aggiungi" della casa con il campo attivo.',
      steps: (app) async {
        await _openCreateSheet(app);
        await app.tap(find.byKey(const Key('create_manual_items')));
      },
    ),
```

  - Scenario 3 del flusso 04 (casa vuota): descrizione `'Casa vuota: "Scansiona con AI" e il link "scrivili a mano".'`.

- [ ] **Step 2:** `flutter test test/screenshots/ui_screenshots_test.dart --dart-define=UI_SCREENSHOTS=true` → tutti verdi, nessun problema nel manifest; guarda 04/03, 04/04, 04/17, 05/01 in chiaro e scuro.

- [ ] **Step 3: documentazione** — `docs/ui-flows.md`: pagina "aggiungi", pillole col nome intero, via il "+", stato vuoto AI-first, righe 3/4/17 del flusso 04 e riga 1 del flusso 05. `ARCHITECTURE.md`: stato vuoto come template (`DsEmptyState` con CTA e link), `DsLinkButton` condiviso; `rapidFireTapRegionGroup`; il form di creazione oggetto non si apre più dalla casa.

- [ ] **Step 4: commit**

```bash
git add test/screenshots/ui_screenshots_test.dart
git add -f docs/ui-flows.md
git commit -m "test(screenshot): pagina aggiungi e stato vuoto AI-first; flussi UI aggiornati"
```

---

### Task 6: PR

- [ ] `git push -u origin feat/casa-pagina-aggiungi`; PR verso `develop` "Casa: pagina aggiungi e stato vuoto con l'AI", descrizione con cosa cambia, evento nuovo, verifica, chiusura `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

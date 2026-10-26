# Flusso A · Blocco 1: testata, lista a gruppi e ricerca nella casa

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alleggerire la schermata della casa: niente filtri per categoria, etichette di gruppo piccole fisse in alto e chiudibili, "⋯" e 🔍 nell'intestazione, barra in basso con campo neutro e bottone AI come unico arancio, ricerca nella casa con i suoi eventi.

**Architecture:** Un componente condiviso `DsGroupHeader` sostituisce `CategorySectionHeader` (unico utilizzatore). Le sezioni della lista diventano gruppi sliver con l'intestazione in un `PinnedHeaderSliver`. La ricerca è uno stato della schermata della casa che filtra `ItemsScreen` attraverso una funzione pura `matchesSearch`, che il blocco 2 riusa e la fase "Ricerca" sostituirà con il motore che tollera i refusi.

**Tech Stack:** Flutter 3.38, Riverpod 2.5, easy_localization, mocktail; test di widget con l'harness degli screenshot (`test/screenshots/support/harness.dart`, app vera con DB in memoria e dati di prova).

**Spec:** `docs/superpowers/specs/2026-10-14-flusso-a-dettaglio-casa-design.md` (sezioni 1, 2, 3, "Ricerca", "Tour guidato", "Regole per il kit" 1-2).

**Blocchi successivi** (piano scritto dopo il merge di questo, sul codice aggiornato): 2) pagina "aggiungi", pillole larghe, via il "+", stato vuoto AI-first; 3) scheda oggetto a righe di impostazioni; 4) selezione multipla con la barra flottante estratta da `MainShell`.

## Global Constraints

- Branch `feat/casa-lista-ricerca` da `origin/develop`; PR verso `develop` (squash). Mai push su `develop`/`main`.
- Niente colori, spaziature o font scritti a mano: `colorScheme.*`, `context.spacingXs/Sm/Md/Lg`, `context.iconSizeSm`, `AppConstants.*`, `textTheme.*`.
- Riusare i componenti esistenti (`AppPillTab` con i suoi parametri colore, `CircularActionButton`, `ItemsEmptyState`, `ItemCard`); l'unico componente nuovo è `DsGroupHeader`, che prende il posto di `CategorySectionHeader`.
- Arancio (`colorScheme.primary`) nella schermata della casa solo sul bottone AI. Icona della casa `onSurfaceVariant`; pillola spazio scelta `onSurface` (riempimento al 14% dato da `AppPill`); bordo del campo `outlineVariant` da 1 dp.
- Etichetta di gruppo: testo `"<nome> · <n>"` (con `" · <dettaglio>"` opzionale), `textTheme.labelLarge`, colore `onSurfaceVariant`, padding top `spacingMd` e bottom `spacingSm`, freccetta `expand_less`/`expand_more` di `iconSizeSm` solo se il gruppo è chiudibile, sfondo `scaffoldBackgroundColor`.
- Eventi ricerca: `search_opened` `{context}`, `search_result_tapped` `{context, position}` (1 = primo risultato), `search_no_results` `{context, query_length}`; mai il testo cercato. In questo blocco `context` è sempre `'house'`.
- Ogni stringa nuova in `assets/translations/it-IT.json` **e** `en-US.json`.
- Dopo ogni task: `dart analyze` pulito sui file toccati e i test indicati verdi; commit appena verde (messaggio in italiano, con la riga `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`).

---

### Task 1: funzione di confronto per la ricerca

**Files:**
- Create: `lib/shared/helpers/search_match.dart`
- Test: `test/shared/helpers/search_match_test.dart`

**Interfaces:**
- Produces: `String normalizeForSearch(String text)`, `bool matchesSearch(String text, String query)`; usate dai task 4 e 5 e dal blocco 2.

- [ ] **Step 1: test che falliscono**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/helpers/search_match.dart';

void main() {
  group('normalizeForSearch', () {
    test('toglie maiuscole e accenti', () {
      expect(normalizeForSearch('Perché ÀÈÌÒÙ àéîöü'), 'perche aeiou aeiou');
    });
  });

  group('matchesSearch', () {
    test('trova una parte del nome senza badare alle maiuscole', () {
      expect(matchesSearch('Calzini', 'CALZ'), isTrue);
      expect(matchesSearch('Calzoncini da corsa', 'da cor'), isTrue);
    });

    test('ignora gli accenti in entrambi i versi', () {
      expect(matchesSearch('Caffè', 'caffe'), isTrue);
      expect(matchesSearch('Caffe', 'caffè'), isTrue);
    });

    test('una ricerca vuota o di soli spazi trova tutto', () {
      expect(matchesSearch('Jeans blu', ''), isTrue);
      expect(matchesSearch('Jeans blu', '   '), isTrue);
    });

    test('non trova ciò che non c è', () {
      expect(matchesSearch('Jeans blu', 'calz'), isFalse);
    });
  });
}
```

- [ ] **Step 2: verifica che falliscano**

Run: `flutter test test/shared/helpers/search_match_test.dart`
Expected: FAIL, `search_match.dart` non esiste.

- [ ] **Step 3: implementazione**

```dart
/// Confronto per la ricerca degli oggetti: senza maiuscole né accenti, "il
/// testo contiene la ricerca".
///
/// È volutamente l'unico punto da cambiare quando arriverà il motore che
/// tollera i refusi (fase "Ricerca" dello spec del flusso A): la UI chiama
/// solo [matchesSearch].
library;

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
};

String normalizeForSearch(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

bool matchesSearch(String text, String query) {
  final q = normalizeForSearch(query.trim());
  if (q.isEmpty) return true;
  return normalizeForSearch(text).contains(q);
}
```

- [ ] **Step 4: verifica che passino**

Run: `flutter test test/shared/helpers/search_match_test.dart`
Expected: PASS (5 test).

- [ ] **Step 5: commit**

```bash
git add lib/shared/helpers/search_match.dart test/shared/helpers/search_match_test.dart
git commit -m "feat(ricerca): confronto senza maiuscole né accenti per gli oggetti"
```

---

### Task 2: eventi della ricerca

**Files:**
- Modify: `lib/core/analytics/core_analytics_service.dart` (nuova sezione dopo `trackCreateSheetChoice`)
- Test: `test/core/analytics/core_analytics_service_test.dart` (nuovo `group('search_', …)` accanto a `group('navigation_', …)`)

**Interfaces:**
- Produces: `trackSearchOpened({required String context})`, `trackSearchResultTapped({required String context, required int position})`, `trackSearchNoResults({required String context, required int queryLength})`.

- [ ] **Step 1: test che falliscono** (stesso stile di `navigation_`: `service`, `mockAnalytics`, `pump()` già definiti nel file)

```dart
  group('search_', () {
    test('trackSearchOpened logs search_opened', () async {
      service.trackSearchOpened(context: 'house');
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'search_opened',
          properties: {'context': 'house'},
        ),
      ).called(1);
    });

    test('trackSearchResultTapped logs search_result_tapped', () async {
      service.trackSearchResultTapped(context: 'house', position: 2);
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'search_result_tapped',
          properties: {'context': 'house', 'position': 2},
        ),
      ).called(1);
    });

    test('trackSearchNoResults logs search_no_results without the text', () async {
      service.trackSearchNoResults(context: 'house', queryLength: 4);
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'search_no_results',
          properties: {'context': 'house', 'query_length': 4},
        ),
      ).called(1);
    });
  });
```

- [ ] **Step 2: verifica che falliscano**

Run: `flutter test test/core/analytics/core_analytics_service_test.dart`
Expected: FAIL, metodi non definiti.

- [ ] **Step 3: implementazione** (subito dopo `trackCreateSheetChoice`)

```dart
  // ── search_ ───────────────────────────────────────────────────────────────

  /// Ricerca aperta. `context`: `house` (dentro una casa) o `houses_tab`
  /// (ricerca globale, fase successiva).
  void trackSearchOpened({required String context}) {
    _safeLogEvent('search_opened', properties: {'context': context});
  }

  /// Risultato aperto; `position` parte da 1.
  void trackSearchResultTapped({
    required String context,
    required int position,
  }) {
    _safeLogEvent(
      'search_result_tapped',
      properties: {'context': context, 'position': position},
    );
  }

  /// Ricerca senza risultati. Solo la lunghezza: il testo cercato è un dato
  /// dell'utente e non lascia il telefono.
  void trackSearchNoResults({
    required String context,
    required int queryLength,
  }) {
    _safeLogEvent(
      'search_no_results',
      properties: {'context': context, 'query_length': queryLength},
    );
  }
```

- [ ] **Step 4: verifica che passino**

Run: `flutter test test/core/analytics/core_analytics_service_test.dart`
Expected: PASS.

- [ ] **Step 5: commit**

```bash
git add lib/core/analytics/core_analytics_service.dart test/core/analytics/core_analytics_service_test.dart
git commit -m "feat(analytics): eventi search_opened, search_result_tapped, search_no_results"
```

---

### Task 3: `DsGroupHeader` al posto di `CategorySectionHeader`

**Files:**
- Create: `lib/shared/widgets/ds_group_header.dart`
- Delete: `lib/shared/widgets/category_section_header.dart`
- Modify: `lib/shared/widgets/widgets.dart` (export: `category_section_header.dart` → `ds_group_header.dart`)
- Test: `test/shared/widgets/ds_group_header_test.dart`

Prima di cancellare, verifica che l'unico utilizzatore sia `item_category_section.dart`: `grep -rn "CategorySectionHeader" lib test` deve mostrare solo quel file, `widgets.dart` e il file stesso. Il riferimento in `item_category_section.dart` sparisce nel task 4: fai i task 3 e 4 nello stesso commit se l'analisi fallisce nel mezzo (vedi Step 5).

**Interfaces:**
- Produces: `DsGroupHeader({Key? key, required String label, int? count, String? detail, bool? expanded, VoidCallback? onTap})`. `expanded == null` → gruppo non chiudibile, nessuna freccetta.

- [ ] **Step 1: test che falliscono**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_group_header.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
  );

  testWidgets('scrive nome, conteggio e dettaglio separati da un punto', (
    tester,
  ) async {
    await pump(
      tester,
      const DsGroupHeader(label: 'Temporanei', count: 4, detail: 'da Casa Milano'),
    );
    expect(find.text('Temporanei · 4 · da Casa Milano'), findsOneWidget);
  });

  testWidgets('senza stato di apertura non mostra la freccetta', (tester) async {
    await pump(tester, const DsGroupHeader(label: 'Vestiti', count: 7));
    expect(find.byIcon(Icons.expand_less), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('la freccetta segue lo stato e il tocco arriva', (tester) async {
    var taps = 0;
    await pump(
      tester,
      DsGroupHeader(
        label: 'Vestiti',
        count: 7,
        expanded: false,
        onTap: () => taps++,
      ),
    );
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    await tester.tap(find.text('Vestiti · 7'));
    expect(taps, 1);
  });

  testWidgets('il testo è grigio, non arancio', (tester) async {
    await pump(tester, const DsGroupHeader(label: 'Vestiti', count: 7));
    final text = tester.widget<Text>(find.text('Vestiti · 7'));
    expect(text.style?.color, AppTheme.light.colorScheme.onSurfaceVariant);
  });
}
```

- [ ] **Step 2: verifica che falliscano**

Run: `flutter test test/shared/widgets/ds_group_header_test.dart`
Expected: FAIL, `ds_group_header.dart` non esiste.

- [ ] **Step 3: implementazione**

```dart
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Etichetta di un gruppo di righe: "Vestiti · 7".
///
/// Piccola e grigia: è un riferimento, non un titolo né un'azione. Ha lo
/// sfondo della pagina perché nelle liste sta in un `PinnedHeaderSliver` e
/// resta fissa in alto mentre le righe del gruppo le scorrono sotto.
///
/// Con [expanded] non nullo il gruppo è chiudibile: compare la freccetta e
/// [onTap] apre o chiude.
class DsGroupHeader extends StatelessWidget {
  final String label;
  final int? count;

  /// Aggiunta in coda, es. la provenienza dei temporanei.
  final String? detail;

  /// `null` = gruppo non chiudibile.
  final bool? expanded;
  final VoidCallback? onTap;

  const DsGroupHeader({
    super.key,
    required this.label,
    this.count,
    this.detail,
    this.expanded,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final text = [
      label,
      if (count != null) '$count',
      if (detail != null) detail!,
    ].join(' · ');

    return Semantics(
      button: onTap != null,
      expanded: expanded,
      child: Material(
        color: theme.scaffoldBackgroundColor,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.only(
              top: context.spacingMd,
              bottom: context.spacingSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                  ),
                ),
                if (expanded != null)
                  Icon(
                    expanded! ? Icons.expand_less : Icons.expand_more,
                    size: context.iconSizeSm,
                    color: color,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

In `lib/shared/widgets/widgets.dart` sostituisci `export 'category_section_header.dart';` con `export 'ds_group_header.dart';` (in ordine alfabetico, dopo `ds_contextual_app_bar.dart`). Cancella `lib/shared/widgets/category_section_header.dart`.

- [ ] **Step 4: verifica che passino**

Run: `flutter test test/shared/widgets/ds_group_header_test.dart`
Expected: PASS (4 test).

- [ ] **Step 5: commit** (insieme al task 4 se `dart analyze lib` segnala `CategorySectionHeader` mancante)

```bash
git add lib/shared/widgets/ds_group_header.dart lib/shared/widgets/widgets.dart test/shared/widgets/ds_group_header_test.dart
git rm lib/shared/widgets/category_section_header.dart
git commit -m "feat(ds): DsGroupHeader, etichetta di gruppo che sostituisce CategorySectionHeader"
```

---

### Task 4: gruppi della lista con etichetta fissa e chiudibile

**Files:**
- Modify: `lib/features/items/view/item_category_section.dart` (tutto il file)
- Modify: `lib/features/items/view/in_transit_section.dart` (diventa un gruppo sliver)
- Modify: `lib/features/items/view/item_card.dart` (callback `onOpened`)
- Modify: `lib/features/items/view/items_screen.dart` (via "In casa", via il ramo `categoryFilter`, ricerca, chiave del primo gruppo)

**Interfaces:**
- Consumes: `DsGroupHeader` (task 3), `matchesSearch` (task 1).
- Produces:
  - `ItemCategorySection({required ItemCategory category, required List<ItemModel> items, required String houseId, required Map<String,int> itemQuantitiesOnTrip, Key? headerKey, void Function(int index)? onItemOpened})` → restituisce un `SliverMainAxisGroup`.
  - `InTransitSection({required List<TripItem> items, required List<HouseModel> houses, Key? headerKey})` → restituisce un `SliverMainAxisGroup` (prima era un box).
  - `ItemCard(..., VoidCallback? onOpened)`: chiamato in modalità normale appena prima di aprire la scheda.
  - `ItemsScreen({required String houseId, required String houseName, String? selectedSpaceId, String? searchQuery, Key? firstGroupKey, void Function(int position)? onSearchResultOpened})`. **Rimosso** `categoryFilter`.

- [ ] **Step 1: `item_category_section.dart`** — sostituisci il contenuto con:

```dart
import 'package:flutter/material.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/view/item_card.dart';
import 'package:pack_log/shared/widgets/ds_group_header.dart';

/// Gruppo di una categoria nella lista della casa.
///
/// L'etichetta sta in un [PinnedHeaderSliver]: dentro il
/// [SliverMainAxisGroup] resta fissa in alto finché si scorre il gruppo, così
/// con molti oggetti si sa sempre in quale categoria si è. Toccarla chiude o
/// riapre il gruppo.
///
/// Le righe sono in un [SliverList.builder]: costruite solo quando entrano a
/// schermo.
class ItemCategorySection extends StatefulWidget {
  final ItemCategory category;
  final List<ItemModel> items;
  final String houseId;
  final Map<String, int> itemQuantitiesOnTrip;

  /// Key dell'etichetta (il primo gruppo della lista porta quella del tour).
  final Key? headerKey;

  /// Chiamato quando si apre un oggetto, con il suo indice nel gruppo.
  final void Function(int index)? onItemOpened;

  const ItemCategorySection({
    super.key,
    required this.category,
    required this.items,
    required this.houseId,
    required this.itemQuantitiesOnTrip,
    this.headerKey,
    this.onItemOpened,
  });

  @override
  State<ItemCategorySection> createState() => _ItemCategorySectionState();
}

class _ItemCategorySectionState extends State<ItemCategorySection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final onItemOpened = widget.onItemOpened;
    return SliverMainAxisGroup(
      slivers: [
        PinnedHeaderSliver(
          child: DsGroupHeader(
            key: widget.headerKey,
            label: widget.category.displayName,
            count: widget.items.length,
            expanded: _isExpanded,
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
        ),
        if (_isExpanded)
          SliverList.builder(
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return ItemCard(
                item: item,
                houseId: widget.houseId,
                quantityOnTrip: widget.itemQuantitiesOnTrip[item.id] ?? 0,
                onOpened: onItemOpened == null
                    ? null
                    : () => onItemOpened(index),
              );
            },
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: `in_transit_section.dart`** — rendilo `StatefulWidget` chiudibile; il metodo `_originName` resta. `build` diventa:

```dart
  @override
  Widget build(BuildContext context) {
    // Quando i temporanei vengono tutti dalla stessa casa — il caso normale —
    // la provenienza sale nell'etichetta invece di ripetersi su ogni riga.
    final origins = widget.items.map(_originName).toSet();
    final sharedOrigin = origins.length == 1 ? origins.first : null;

    return SliverMainAxisGroup(
      slivers: [
        PinnedHeaderSliver(
          child: DsGroupHeader(
            key: widget.headerKey,
            label: 'common.temporaries'.tr(),
            count: widget.items.length,
            detail: sharedOrigin == null
                ? null
                : '${'common.from'.tr().toLowerCase()} $sharedOrigin',
            expanded: _isExpanded,
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
        ),
        if (_isExpanded)
          SliverList.list(
            children: [
              for (final item in widget.items)
                InTransitItemCard(
                  item: item,
                  originHouseName: _originName(item),
                  showOrigin: sharedOrigin == null,
                ),
            ],
          ),
      ],
    );
  }
```

con i campi `final List<TripItem> items; final List<HouseModel> houses; final Key? headerKey;`, `bool _isExpanded = true;` nello `State`, `_originName` che legge `widget.houses`, e gli import `package:pack_log/shared/widgets/ds_group_header.dart` (via `app_spacing.dart` se non serve più).

- [ ] **Step 3: `item_card.dart`** — aggiungi il campo e chiamalo prima di aprire la scheda:

```dart
  /// Chiamato in modalità normale appena prima di aprire la scheda
  /// dell'oggetto (la ricerca lo usa per l'evento del risultato aperto).
  final VoidCallback? onOpened;
```

costruttore: `this.onOpened,`; nel `UniversalItemTile`, il ramo normale di `onTap` diventa:

```dart
          : () {
              onOpened?.call();
              showAddEditItemSheet(
                context,
                houseId: item.houseId,
                itemId: item.id,
              );
            },
```

- [ ] **Step 4: `items_screen.dart`**

1. Campi: togli `categoryFilter`; aggiungi

```dart
  /// Testo della ricerca nella casa; `null` o vuoto = nessun filtro.
  final String? searchQuery;

  /// Key per l'etichetta del primo gruppo (il tour la usa come bersaglio).
  final Key? firstGroupKey;

  /// Con la ricerca attiva: un risultato è stato aperto. `position` parte
  /// da 1, nell'ordine in cui le righe sono a schermo.
  final void Function(int position)? onSearchResultOpened;
```

2. Nel `build`, i temporanei e gli oggetti passano dal filtro:

```dart
    final query = widget.searchQuery ?? '';
    final isSearching = query.trim().isNotEmpty;
    final temporaryItems = ref
        .watch(temporaryItemsInHouseProvider(widget.houseId))
        .where((i) => matchesSearch(i.name, query))
        .toList();
```

e nel `data:` di `itemsAsync.when` rinomina il parametro in `loadedItems` e scrivi subito `final allItems = loadedItems.where((i) => matchesSearch(i.name, query)).toList();`.

3. Cancella tutto il blocco `// ── Vista per singola categoria (lista piatta)` (il ramo `if (widget.categoryFilter != null)`).

4. Stato vuoto: prima del vuoto esistente aggiungi quello della ricerca:

```dart
              if (isSearching && spaceFiltered.isEmpty && temporaryItems.isEmpty) {
                return ItemsEmptyState(
                  onRefresh: _onRefresh,
                  icon: Icons.search_off,
                  title: 'items.no_search_results'.tr(),
                );
              }
```

e al vuoto esistente (`Icons.inventory_2_outlined`) passa `key: widget.firstGroupKey` (a lista vuota il tour punta lì: la stessa chiave non è mai su due widget insieme).

5. Nella `CustomScrollView` dei gruppi:
   - il blocco temporanei diventa

```dart
                        if (hasTemporaryItems &&
                            widget.selectedSpaceId == null)
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.spacingMd,
                            ),
                            sliver: InTransitSection(
                              items: temporaryItems,
                              houses: houses,
                              headerKey: widget.firstGroupKey,
                            ),
                          ),
```

   - cancella lo `SizedBox(height: context.spacingMd)` che lo seguiva e tutto il blocco `// ── Intestazione "In casa"`;
   - il ciclo delle categorie calcola la posizione dei risultati e dà la chiave al primo gruppo solo se non ci sono temporanei a schermo:

```dart
                        for (final (i, entry) in categoryEntries.indexed)
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.spacingMd,
                            ),
                            sliver: ItemCategorySection(
                              key: ValueKey(entry.key),
                              category: entry.key,
                              items: entry.value,
                              houseId: widget.houseId,
                              itemQuantitiesOnTrip: itemQuantitiesOnTrip,
                              headerKey:
                                  i == 0 && !showsTemporaries
                                  ? widget.firstGroupKey
                                  : null,
                              onItemOpened:
                                  isSearching &&
                                      widget.onSearchResultOpened != null
                                  ? (index) => widget.onSearchResultOpened!(
                                      offsets[i] + index + 1,
                                    )
                                  : null,
                            ),
                          ),
```

     con, prima del `return RefreshIndicator(`:

```dart
                  final showsTemporaries =
                      hasTemporaryItems && widget.selectedSpaceId == null;
                  // Posizione del primo oggetto di ogni gruppo nell'ordine a
                  // schermo, per l'evento del risultato aperto.
                  final offsets = <int>[];
                  var running = 0;
                  for (final entry in categoryEntries) {
                    offsets.add(running);
                    running += entry.value.length;
                  }
```

     (usa `showsTemporaries` anche nella condizione del blocco temporanei). La `ValueKey` tiene lo stato aperto/chiuso attaccato alla categoria quando la ricerca toglie un gruppo.

6. Import: `package:pack_log/shared/helpers/search_match.dart`.

- [ ] **Step 5: analisi e test esistenti**

Run: `dart analyze lib/features/items lib/shared && flutter test test/features/items test/shared`
Expected: nessun problema; test verdi. Se `house_detail_screen.dart` non compila per `categoryFilter`, prosegui col task 5 e committa insieme.

- [ ] **Step 6: commit**

```bash
git add lib/features/items lib/shared
git commit -m "feat(casa): gruppi con etichetta fissa e chiudibile, via In casa e il filtro categoria"
```

---

### Task 5: testata, filtri, barra in basso e ricerca nella casa

**Files:**
- Modify: `lib/features/houses/view/house_detail_screen.dart`
- Modify: `lib/features/items/widgets/rapid_fire_input.dart:222-230` (bordo)
- Modify: `lib/features/tour/tour_keys.dart` (commento di `houseItemsAnchor`)
- Modify: `assets/translations/it-IT.json`, `assets/translations/en-US.json`
- Test: `test/features/houses/view/house_detail_screen_test.dart` (nuovo)

**Interfaces:**
- Consumes: `ItemsScreen(searchQuery:, firstGroupKey:, onSearchResultOpened:)` (task 4), `matchesSearch` (task 1), eventi (task 2).

- [ ] **Step 1: stringhe**

`it-IT.json`, oggetto `houses`: `"search_hint": "Cerca in {}"`, `"search_tooltip": "Cerca oggetti"`. Oggetto `items`: `"no_search_results": "Nessun oggetto trovato"`.
`en-US.json`, stessi percorsi: `"search_hint": "Search in {}"`, `"search_tooltip": "Search items"`, `"no_search_results": "No items found"`.

- [ ] **Step 2: test che falliscono** — `test/features/houses/view/house_detail_screen_test.dart`

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screenshots/support/fakes.dart';
import '../../../screenshots/support/harness.dart';
import '../../../screenshots/support/seed.dart';

class _MockCoreAnalytics extends Mock implements CoreAnalyticsService {}

/// La casa con l'app vera (router, DB in memoria, dati di prova degli
/// screenshot): Casa Milano ha 7 vestiti, tra cui Calzini e Jeans blu.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });

  late _MockCoreAnalytics analytics;

  setUp(() => analytics = _MockCoreAnalytics());

  Future<ScreenshotApp> openHome(WidgetTester tester) async {
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
    await app.push('/houses/$kHomeId');
    return app;
  }

  testWidgets('niente filtri per categoria, gruppi con nome e conteggio', (
    tester,
  ) async {
    final app = await openHome(tester);
    expect(find.text('Tutto'), findsNothing);
    expect(find.text('In casa'), findsNothing);
    expect(find.text('Vestiti · 7'), findsOneWidget);
    await app.finish();
  });

  testWidgets('il tocco sull etichetta chiude e riapre il gruppo', (
    tester,
  ) async {
    final app = await openHome(tester);
    expect(find.text('Calzini'), findsOneWidget);
    await app.tap(find.text('Vestiti · 7'));
    expect(find.text('Calzini'), findsNothing);
    await app.tap(find.text('Vestiti · 7'));
    expect(find.text('Calzini'), findsOneWidget);
    await app.finish();
  });

  testWidgets('la ricerca filtra la lista e registra l apertura', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(find.byKey(const Key('house_search')));
    verify(() => analytics.trackSearchOpened(context: 'house')).called(1);

    await app.enterText(find.byKey(const Key('house_search_field')), 'CALZ');
    expect(find.text('Calzini'), findsOneWidget);
    expect(find.text('Jeans blu'), findsNothing);
    expect(find.text('Vestiti · 1'), findsOneWidget);

    await app.tap(find.text('Calzini'));
    verify(
      () => analytics.trackSearchResultTapped(context: 'house', position: 1),
    ).called(1);
    await app.finish();
  });

  testWidgets('la freccia chiude la ricerca e torna tutta la lista', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(find.byKey(const Key('house_search')));
    await app.enterText(find.byKey(const Key('house_search_field')), 'calz');
    await app.tap(find.byKey(const Key('house_search_close')));
    expect(find.byKey(const Key('house_search_field')), findsNothing);
    expect(find.text('Jeans blu'), findsOneWidget);
    await app.finish();
  });

  testWidgets('senza risultati mostra il vuoto e registra la lunghezza', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(find.byKey(const Key('house_search')));
    await app.enterText(find.byKey(const Key('house_search_field')), 'zzzz');
    expect(find.text('Nessun oggetto trovato'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await app.settle();
    verify(
      () => analytics.trackSearchNoResults(context: 'house', queryLength: 4),
    ).called(1);
    await app.finish();
  });

  testWidgets('in basso solo campo e AI; l AI è l unico arancio', (
    tester,
  ) async {
    final app = await openHome(tester);
    // "⋯" è salito nell'intestazione: un solo bottone in tutta la schermata.
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.more_horiz),
      ),
      findsOneWidget,
    );
    final ai = tester.widget<Icon>(find.byIcon(Icons.auto_awesome));
    expect(ai.color, AppTheme.light.colorScheme.primary);
    await app.finish();
  });
}
```

Prima di scriverlo verifica i nomi: `ShotTheme.light` in `harness.dart`, `useSystemSqlite` in `fakes.dart`, `kHomeId` in `seed.dart`, e che i 7 vestiti di Casa Milano includano "Calzini" e "Jeans blu" (`seed.dart`, `itemDefs`). Se `CircularActionButton` non passa `color` all'`Icon`, nell'ultimo test cerca il colore sull'`Icon` discendente del bottone AI.

- [ ] **Step 3: verifica che falliscano**

Run: `flutter test test/features/houses/view/house_detail_screen_test.dart`
Expected: FAIL (filtri "Tutto" presenti, nessuna `Key('house_search')`, …).

- [ ] **Step 4: implementazione in `house_detail_screen.dart`**

1. Cancella `enum _CategoryTab`, il campo `_categoryTab`, la classe `_CategoryFilterPills` e il suo uso nel `body` (con il commento `// ── Riga 2`). Togli gli import diventati inutili (`tri_slot_bar.dart` e, se nessuno lo usa più nel file, `app_pill_tab.dart` resta perché lo usano le pillole spazi).

2. Stato della ricerca nel `State`:

```dart
  /// Ricerca nella casa: `null` = chiusa, stringa (anche vuota) = aperta.
  String? _search;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CoreAnalyticsService get _analytics => ref.read(coreAnalyticsServiceProvider);

  void _openSearch() {
    _analytics.trackSearchOpened(context: 'house');
    _searchController.clear();
    setState(() => _search = '');
  }

  /// Chiamato all'invio della tastiera e alla chiusura: una ricerca che non
  /// ha trovato niente è il segnale che serve, una per tentativo.
  void _reportIfNoResults() {
    final query = _search?.trim() ?? '';
    if (query.isEmpty) return;
    final items =
        ref.read(itemNotifierProvider(widget.houseId)).valueOrNull ?? const [];
    final temporaries = ref.read(temporaryItemsInHouseProvider(widget.houseId));
    final found =
        items.any((i) => matchesSearch(i.name, query)) ||
        temporaries.any((i) => matchesSearch(i.name, query));
    if (!found) {
      _analytics.trackSearchNoResults(
        context: 'house',
        queryLength: query.length,
      );
    }
  }

  void _closeSearch() {
    _reportIfNoResults();
    _searchController.clear();
    setState(() => _search = null);
  }
```

3. `PopScope`: il tasto indietro chiude prima la selezione, poi la ricerca.

```dart
      canPop: !isSelectionMode && _search == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (isSelectionMode) {
          ref.read(itemSelectionNotifierProvider.notifier).clear();
        } else if (_search != null) {
          _closeSearch();
        }
      },
```

4. `normalAppBar` diventa `_HouseNormalAppBar(...)` con i nuovi parametri:

```dart
              normalAppBar: _HouseNormalAppBar(
                houseName: house.displayName,
                houseIcon: HouseIcons.getIcon(house.iconName),
                searchController: _search == null ? null : _searchController,
                onSearchOpen: _openSearch,
                onSearchChanged: (q) => setState(() => _search = q),
                onSearchSubmitted: _reportIfNoResults,
                onSearchClose: _closeSearch,
                onManage: () => _showManageSheet(
                  context,
                  widget.houseId,
                  house.isPrimary,
                  house.displayName,
                ),
              ),
```

e la classe:

```dart
class _HouseNormalAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String houseName;
  final IconData houseIcon;

  /// Non nullo quando la ricerca è aperta: l'intestazione diventa il campo.
  final TextEditingController? searchController;
  final VoidCallback onSearchOpen;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onSearchClose;
  final VoidCallback onManage;

  const _HouseNormalAppBar({
    required this.houseName,
    required this.houseIcon,
    required this.searchController,
    required this.onSearchOpen,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSearchClose,
    required this.onManage,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = searchController;

    if (controller != null) {
      return AppBar(
        key: const ValueKey('search-appbar'),
        leading: IconButton(
          key: const Key('house_search_close'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'common.back'.tr(),
          onPressed: onSearchClose,
        ),
        title: TextField(
          key: const Key('house_search_field'),
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: onSearchChanged,
          onSubmitted: (_) => onSearchSubmitted(),
          decoration: InputDecoration(
            hintText: 'houses.search_hint'.tr(args: [houseName]),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'common.clear'.tr(),
                    onPressed: () {
                      controller.clear();
                      onSearchChanged('');
                    },
                  ),
          ),
        ],
      );
    }

    return AppBar(
      key: const ValueKey('normal-appbar'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.popOrGo('/'),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Neutra: è il contesto, non un'azione.
          Icon(houseIcon, color: colorScheme.onSurfaceVariant),
          AppSpacing.hGapSm,
          Flexible(child: Text(houseName, overflow: TextOverflow.ellipsis)),
        ],
      ),
      actions: [
        IconButton(
          key: const Key('house_search'),
          icon: const Icon(Icons.search),
          tooltip: 'houses.search_tooltip'.tr(),
          onPressed: onSearchOpen,
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz),
          tooltip: 'houses.manage_sheet_title'.tr(),
          onPressed: onManage,
        ),
      ],
    );
  }
}
```

Verifica che `common.back` e `common.clear` esistano in entrambe le traduzioni (`grep -n '"back"\|"clear"' assets/translations/it-IT.json`); se mancano, aggiungili (`"Indietro"`/`"Back"`, `"Cancella"`/`"Clear"`) nell'oggetto `common`.

5. `ItemsScreen` nel `body`:

```dart
                  child: ItemsScreen(
                    houseId: widget.houseId,
                    houseName: house.displayName,
                    selectedSpaceId: _spaceFilter,
                    searchQuery: _search,
                    firstGroupKey: tourKeys.houseItemsAnchor,
                    onSearchResultOpened: (position) => _analytics
                        .trackSearchResultTapped(
                          context: 'house',
                          position: position,
                        ),
                  ),
```

6. `_SpaceFilterPills`: pillola scelta neutra, con i parametri esistenti di `AppPillTab`.

```dart
      child: AppPillTab<String?>.nullable(
        items: tabItems,
        selectedItem: selectedSpaceId,
        getLabel: ...,            // invariato
        onSelected: onSelected,
        // Il filtro scelto è uno stato di lettura, non l'azione della
        // schermata: niente arancio.
        selectedColor: Theme.of(context).colorScheme.onSurface,
        selectedTextColor: Theme.of(context).colorScheme.onSurface,
        scrollPadding: EdgeInsets.zero,
      ),
```

e il padding del contenitore diventa `EdgeInsets.only(left: context.spacingMd, top: context.spacingSm, bottom: context.spacingXs)` (prima il margine sotto lo dava la fila delle categorie).

7. `_HouseNormalActionBar`: togli `isPrimary`, `houseName`, `onManage` (campi, costruttore e argomenti passati dal `build`), e sostituisci il `TriSlotBar` con:

```dart
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: RapidFireInput(
              houseId: houseId,
              autofocus: autofocusRapidFire,
              currentSpaceId: currentSpaceId,
              height: elementHeight,
              onOpenFullForm: (name, category) => showAddEditItemSheet(
                context,
                houseId: houseId,
                initialName: name.isNotEmpty ? name : null,
                initialCategory: category,
              ),
              onExpandedChanged: onExpandedChanged,
            ),
          ),
          // Mentre si scrive il campo prende tutta la riga.
          if (!isExpanded) ...[
            SizedBox(width: context.spacingSm),
            CircularActionButton(
              icon: Icons.auto_awesome,
              // L'unico arancio della schermata: la scansione AI è la strada
              // che vogliamo far prendere per aggiungere oggetti.
              color: Theme.of(context).colorScheme.primary,
              showBorder: true,
              onPressed: () => context.push('/houses/$houseId/ai-import'),
            ),
          ],
        ],
      ),
    );
```

(`onOpenFullForm` resta fino al blocco 2.) Aggiorna il commento della classe: "campo rapid-fire (sinistra) e scansione AI (destra)".

8. Import nuovi: `../../../core/analytics/core_analytics_service.dart`, `../../../shared/helpers/search_match.dart`.

- [ ] **Step 5: bordo del campo in `rapid_fire_input.dart`**

```dart
                  // Bordo neutro: nella casa l'arancio è del bottone AI, la
                  // strada che vogliamo far prendere. Il campo resta
                  // riconoscibile per la forma e il segnaposto.
                  border: Border.all(color: colorScheme.outlineVariant),
```

al posto del commento e della riga `border: Border.all(color: colorScheme.primary, width: 2),`.

- [ ] **Step 6: commento della chiave del tour in `tour_keys.dart`**

```dart
  /// Etichetta del primo gruppo della lista in [HouseDetailScreen] (o lo
  /// stato vuoto, se la casa non ha oggetti). Target di
  /// [OnboardingStep.moveItemsTooltip].
  final houseItemsAnchor = GlobalKey();
```

- [ ] **Step 7: verifica che passino**

Run: `flutter test test/features/houses/view/house_detail_screen_test.dart`
Expected: PASS (6 test).

- [ ] **Step 8: analisi e suite**

Run: `dart analyze && flutter test`
Expected: analisi pulita; suite verde (i test degli screenshot restano saltati senza `UI_SCREENSHOTS`).

- [ ] **Step 9: commit**

```bash
git add lib/features/houses lib/features/items/widgets/rapid_fire_input.dart lib/features/tour/tour_keys.dart assets/translations test/features/houses
git commit -m "feat(casa): gestisci e ricerca nell'intestazione, barra con campo neutro e AI"
```

---

### Task 6: screenshot e documentazione

**Files:**
- Modify: `test/screenshots/ui_screenshots_test.dart` (flusso `04-dettaglio-casa`)
- Modify: `docs/ui-flows.md` (tracciato: `git add -f`)
- Modify (solo locale, non tracciati): `ARCHITECTURE.md` (sezione della casa, se descrive filtri per categoria o `CategorySectionHeader`)

- [ ] **Step 1: scenari**

Nel flusso `04-dettaglio-casa`: la descrizione dello scenario 1 diventa `'Inventario a gruppi con etichette fisse, filtro spazi, barra con rapid-fire e AI; gestisci e ricerca in alto.'`. Aggiungi in coda allo stesso flusso, con il numero successivo all'ultimo esistente:

```dart
    Scenario(
      14,
      'dettaglio-casa',
      'ricerca',
      route: '/houses/:id',
      source: _houseDetailSrc,
      description: 'Ricerca nella casa: "cal" lascia i soli oggetti che corrispondono.',
      steps: (app) async {
        await _houseDetail(app);
        await app.tap(find.byKey(const Key('house_search')));
        await app.enterText(find.byKey(const Key('house_search_field')), 'cal');
      },
    ),
    Scenario(
      15,
      'dettaglio-casa',
      'gruppo-chiuso',
      route: '/houses/:id',
      source: _houseDetailSrc,
      description: 'Gruppo Vestiti chiuso toccando la sua etichetta.',
      steps: (app) async {
        await _houseDetail(app);
        await app.tap(find.textContaining('Vestiti ·'));
      },
    ),
```

(se l'ultimo scenario non è il 13, usa i due numeri successivi).

- [ ] **Step 2: rigenera e guarda**

Run: `flutter test test/screenshots/ui_screenshots_test.dart --dart-define=UI_SCREENSHOTS=true`
Expected: tutti verdi, nessun overflow nel manifest (`build/ui-screenshots/manifest.json`). Apri `04-dettaglio-casa/01-…-light.png`, `…-dark.png`, `14-…`, `15-…` e confrontali col mock dello spec: un solo arancio (AI), etichette "Vestiti · 7", niente "In casa".

- [ ] **Step 3: documentazione**

In `docs/ui-flows.md`, sezione del dettaglio casa: filtri solo per spazio; gruppi con etichetta fissa e chiudibile; "⋯" e 🔍 in alto; barra con campo e AI; ricerca. In `ARCHITECTURE.md` sostituisci eventuali riferimenti a `CategorySectionHeader` con `DsGroupHeader` e annota il pattern "etichetta in `PinnedHeaderSliver` dentro `SliverMainAxisGroup`".

- [ ] **Step 4: commit**

```bash
git add test/screenshots/ui_screenshots_test.dart
git add -f docs/ui-flows.md
git commit -m "test(screenshot): ricerca e gruppo chiuso nel dettaglio casa; flussi UI aggiornati"
```

---

### Task 7: PR

- [ ] **Step 1:** `git push -u origin feat/casa-lista-ricerca`
- [ ] **Step 2:** PR verso `develop`, titolo "Casa: lista a gruppi, ricerca e un solo arancio", descrizione con: cosa cambia (sezioni 1-3 dello spec e la 🔍), eventi nuovi, cosa resta per i blocchi 2-4, screenshot prima/dopo, test e analisi; chiusura `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- [ ] **Step 3:** CI verde (`Lint & Unit Tests`); poi merge squash dall'utente.

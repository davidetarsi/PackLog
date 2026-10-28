# Scansione AI: ingresso diretto e risultati più chiari

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Dalla card AI, dal bottone AI della casa e dallo stato vuoto si apre subito Galleria/Fotocamera; nella pagina dei risultati ogni capo ha casella, nome con matita, caratteristiche dell'AI e, dove serve, "C'è già?"; in basso un solo "Salva" che dice cosa fa; X in alto con conferma.

**Architecture:** Lo stato dei risultati (`PhotoGroup`) tiene esclusioni e collegamenti invece di cancellare i capi; il notifier salva i nuovi in blocco e aggiunge i metadati agli oggetti collegati solo se non li avevano. Una funzione condivisa `startAiScan` sostituisce la pagina `AiClothingSandboxScreen` (che si cancella con la sua route). La pagina dei risultati riusa `DsGroupHeader`, `UniversalActionBar`, `DsPickerSheet`, `DialogHelpers`, `DsSheetHeader` (esteso con il bottone chiudi).

**Tech Stack:** Flutter 3.38, Riverpod 2.5, Freezed (serve `build_runner`), easy_localization (plurali con `.plural(n)`), image_picker, mocktail; test di widget con l'harness degli screenshot.

**Spec:** `docs/superpowers/specs/2026-10-14-risultati-scansione-ai-design.md`.

**Parte da:** `develop` con i blocchi 2-4 del flusso A dentro (template `DsEmptyState` con CTA e link, `DsLinkButton`, `DsFloatingBar`). I riferimenti di riga possono essere cambiati: cerca per nome.

## Global Constraints

- Branch `feat/scansione-ai-risultati` da `origin/develop`; PR verso `develop` (squash).
- Niente colori, spaziature o font scritti a mano. Nella pagina dei risultati l'unico arancio è "Salva" (più le caselle spuntate e il cursore, che sono stati).
- Riga del capo: casella a sinistra spuntata in partenza; nome `bodyLarge` w500 seguito da `Icons.edit_outlined` `iconSizeSm` `onSurfaceVariant`; sotto le caratteristiche `bodySmall` `onSurfaceVariant` nel formato `"<subCategory> · <baseColor minuscolo> · <pattern minuscolo>"` (parti vuote saltate); capo escluso: nome e caratteristiche `onSurface` al 38%.
- "C'è già?" (`TextButton` con `foregroundColor: onSurfaceVariant`) solo se la casa di destinazione ha almeno un oggetto con la stessa categoria del capo (`item.category.name == result.category`). Mai in onboarding.
- Foglio "C'è già?": informativo, si chiude con la X o toccando fuori; "Più simili" aperto (oggetti il cui nome normalizzato contiene almeno una parola ≥3 lettere tra tipo, colore e parole del nome letto dall'AI, ordinati per numero di parole trovate), "Altri <categoria>" chiuso; ✨ (`Icons.auto_awesome`, `iconSizeSm`, `onSurfaceVariant`) accanto agli oggetti con `aiMetadata`; "Aggiungi i dettagli" **solo** sulle righe di "Più simili" con `aiMetadata == null`; in fondo "Se c'è già, togli la spunta per non aggiungerlo" grigio.
- Collegamento: il capo non si aggiunge come nuovo; `aiMetadata` dell'oggetto esistente si scrive **solo se era nullo** (mai sovrascritto).
- "Salva": `Salva: N nuovi`, `Salva: N aggiornati`, `Salva: N nuovi · M aggiornati` (singolari "nuovo", "aggiornato"); spento con zero.
- Eventi: `already_here_opened {has_manual_candidates}`, `already_here_details_added`, `ai_items_saved` con `updated` in più.
- Ogni stringa nuova in `it-IT.json` **e** `en-US.json`; i plurali sono oggetti `{"one": …, "other": …}` letti con `.plural(n)`.
- Dopo ogni task: `dart analyze` pulito e test verdi; commit (italiano, riga `Co-Authored-By:` del modello che scrive il commit).

---

### Task 1: stato e notifier — esclusioni, collegamenti, salvataggio

**Files:**
- Modify: `lib/features/ai_input/model/ai_import_state.dart` (campi in `PhotoGroup`), poi `dart run build_runner build --delete-conflicting-outputs`
- Modify: `lib/features/ai_input/providers/ai_import_notifier.dart`
- Modify: `lib/core/analytics/core_analytics_service.dart` (`trackAiItemsSaved` con `updated`; `trackAlreadyHereOpened`, `trackAlreadyHereDetailsAdded`)
- Test: `test/features/ai_input/providers/ai_import_notifier_test.dart`, `test/core/analytics/core_analytics_service_test.dart`

**Interfaces:**
- Produces:
  - `PhotoGroup(..., Set<int> excluded = {}, Map<int, String> linkedItemIds = {})`
  - notifier: `void setIncluded(int groupIndex, int itemIndex, bool included)`, `void linkToExisting(int groupIndex, int itemIndex, String itemId)`, `void unlink(int groupIndex, int itemIndex)`, getter `int get newCount`, `int get updatedCount`. **Rimosso** `deleteItem`.
  - analytics: `trackAiItemsSaved({required int count, required bool isOnboarding, int updated = 0})` → `{'count', 'is_onboarding', 'updated'}`; `trackAlreadyHereOpened({required bool hasManualCandidates})` → `already_here_opened {'has_manual_candidates'}`; `trackAlreadyHereDetailsAdded()` → `already_here_details_added`.

- [x] **Step 1: `ai_import_state.dart`** — in `PhotoGroup`:

```dart
@freezed
class PhotoGroup with _$PhotoGroup {
  const factory PhotoGroup({
    required File photo,
    required List<ClothingAnalysisResult> results,

    /// Indici dei capi esclusi (casella tolta): restano a schermo, non si
    /// salvano, e la spunta si può rimettere.
    @Default(<int>{}) Set<int> excluded,

    /// Indice del capo → id dell'oggetto di casa a cui aggiungere i
    /// dettagli ("C'è già?"). Un capo collegato non si salva come nuovo.
    @Default(<int, String>{}) Map<int, String> linkedItemIds,
  }) = _PhotoGroup;
}
```

Poi `dart run build_runner build --delete-conflicting-outputs`.

- [x] **Step 2: test che falliscono** — nel file del notifier sostituisci il `group('deleteItem()', …)` con:

```dart
  group('setIncluded() / link', () {
    test('escludere non toglie il capo, e si può rimettere', () async {
      final service = MockAiClothingAnalyzerService();
      final container = _makeContainer(service: service);
      addTearDown(container.dispose);
      await _seedOneGroup(
        container,
        service,
        results: [_fakeResult(name: 'T-Shirt'), _fakeResult(name: 'Jeans')],
      );
      final notifier = container.read(aiImportNotifierProvider.notifier);

      notifier.setIncluded(0, 0, false);
      var group = container.read(aiImportNotifierProvider).photoGroups.first;
      expect(group.results.length, 2);
      expect(group.excluded, {0});
      expect(notifier.newCount, 1);

      notifier.setIncluded(0, 0, true);
      group = container.read(aiImportNotifierProvider).photoGroups.first;
      expect(group.excluded, isEmpty);
      expect(notifier.newCount, 2);
    });

    test('collegare toglie il capo dai nuovi e lo conta come aggiornato', () async {
      final service = MockAiClothingAnalyzerService();
      final container = _makeContainer(service: service);
      addTearDown(container.dispose);
      await _seedOneGroup(
        container,
        service,
        results: [_fakeResult(name: 'T-Shirt'), _fakeResult(name: 'Jeans')],
      );
      final notifier = container.read(aiImportNotifierProvider.notifier);

      notifier.linkToExisting(0, 1, 'item-jeans');
      expect(notifier.newCount, 1);
      expect(notifier.updatedCount, 1);

      notifier.unlink(0, 1);
      expect(notifier.newCount, 2);
      expect(notifier.updatedCount, 0);
    });
  });
```

e nel `group('saveItems()', …)` aggiungi:

```dart
    test('salva i nuovi inclusi e aggiunge i dettagli solo dove mancano', () async {
      final service = MockAiClothingAnalyzerService();
      final itemRepo = MockItemRepository();
      final syncOrchestrator = MockSyncOrchestrator();
      final container = _makeContainer(
        service: service,
        itemRepo: itemRepo,
        syncOrchestrator: syncOrchestrator,
      );
      addTearDown(container.dispose);
      final stamp = DateTime(2026);
      final manual = ItemModel(
        id: 'manual',
        houseId: 'house-99',
        name: 'Jeans blu',
        category: ItemCategory.vestiti,
        createdAt: stamp,
        updatedAt: stamp,
      );
      final scanned = manual.copyWith(id: 'scanned', aiMetadata: '{"old":1}');
      when(() => itemRepo.insertMultipleItems(any())).thenAnswer((_) async {});
      when(() => itemRepo.updateItem(any())).thenAnswer((_) async {});
      when(
        () => itemRepo.getItemsByHouseId('house-99'),
      ).thenAnswer((_) async => [manual, scanned]);
      when(() => syncOrchestrator.requestSync()).thenReturn(null);

      await _seedOneGroup(
        container,
        service,
        results: [
          _fakeResult(name: 'T-Shirt'),
          _fakeResult(name: 'Jeans'),
          _fakeResult(name: 'Felpa'),
          _fakeResult(name: 'Gonna'),
        ],
      );
      final notifier = container.read(aiImportNotifierProvider.notifier)
        ..setSelectedHouseId('house-99')
        ..setIncluded(0, 0, false) // T-Shirt esclusa
        ..linkToExisting(0, 1, 'manual') // Jeans → oggetto a mano
        ..linkToExisting(0, 2, 'scanned'); // Felpa → oggetto già scansionato

      await notifier.saveItems();

      final inserted =
          verify(() => itemRepo.insertMultipleItems(captureAny())).captured.first
              as List<ItemModel>;
      expect(inserted.map((i) => i.name), ['Gonna']);

      final updated =
          verify(() => itemRepo.updateItem(captureAny())).captured
              .cast<ItemModel>();
      expect(updated.map((i) => i.id), ['manual']);
      expect(updated.single.aiMetadata, isNotNull);
    });
```

  Aggiorna i test esistenti che usano `deleteItem` (rimossi) e, se `registerFallbackValue` non copre `ItemModel` per `updateItem(any())`, aggiungi un fallback (`ItemModel` d'esempio) in `setUpAll`. In `core_analytics_service_test.dart` aggiorna il test di `trackAiItemsSaved` (properties con `'updated': 0`) e aggiungi i test di `trackAlreadyHereOpened(hasManualCandidates: true)` → `already_here_opened {'has_manual_candidates': true}` e `trackAlreadyHereDetailsAdded()` → `already_here_details_added` (`properties: null`, controlla come lo verificano gli altri eventi senza proprietà nel file).

- [x] **Step 3:** `flutter test test/features/ai_input/providers/ai_import_notifier_test.dart test/core/analytics/core_analytics_service_test.dart` → FAIL.

- [x] **Step 4: notifier** — sostituisci `deleteItem` con:

```dart
  PhotoGroup _group(int i) => state.photoGroups[i];

  void _replaceGroup(int index, PhotoGroup group) {
    final groups = List<PhotoGroup>.from(state.photoGroups);
    groups[index] = group;
    state = state.copyWith(photoGroups: groups);
  }

  /// Casella del capo: escluso resta a schermo ma non si salva.
  void setIncluded(int groupIndex, int itemIndex, bool included) {
    final group = _group(groupIndex);
    final excluded = Set<int>.from(group.excluded);
    included ? excluded.remove(itemIndex) : excluded.add(itemIndex);
    _replaceGroup(groupIndex, group.copyWith(excluded: excluded));
  }

  /// "C'è già?" → "Aggiungi i dettagli": il capo diventa i metadati di un
  /// oggetto che c'è già, e non si salva come nuovo.
  void linkToExisting(int groupIndex, int itemIndex, String itemId) {
    final group = _group(groupIndex);
    _replaceGroup(
      groupIndex,
      group.copyWith(
        linkedItemIds: {...group.linkedItemIds, itemIndex: itemId},
      ),
    );
  }

  void unlink(int groupIndex, int itemIndex) {
    final group = _group(groupIndex);
    _replaceGroup(
      groupIndex,
      group.copyWith(
        linkedItemIds: Map.of(group.linkedItemIds)..remove(itemIndex),
      ),
    );
  }

  /// Capi che si salveranno come oggetti nuovi.
  List<ClothingAnalysisResult> get _newResults => [
    for (final g in state.photoGroups)
      for (var i = 0; i < g.results.length; i++)
        if (!g.excluded.contains(i) && !g.linkedItemIds.containsKey(i))
          g.results[i],
  ];

  /// Oggetto esistente → capo i cui metadati gli si aggiungono.
  Map<String, ClothingAnalysisResult> get _links => {
    for (final g in state.photoGroups)
      for (final e in g.linkedItemIds.entries) e.value: g.results[e.key],
  };

  int get newCount => _newResults.length;
  int get updatedCount => _links.length;
```

  `allResults` resta (lo usa la UI per il conteggio "capi identificati"). `saveItems` diventa:

```dart
  Future<void> saveItems() async {
    final houseId = state.selectedHouseId;
    if (houseId == null) {
      state = state.copyWith(errorMessage: 'ai_import.no_house_selected'.tr());
      return;
    }

    final results = _newResults;
    final links = _links;
    if (results.isEmpty && links.isEmpty) return;

    state = state.copyWith(isLoading: true);
    try {
      final now = DateTime.now();
      final repo = ref.read(itemRepositoryProvider);
      if (results.isNotEmpty) {
        await repo.insertMultipleItems([
          for (final r in results)
            ItemModel(
              id: _uuid.v4(),
              houseId: houseId,
              name: r.name,
              category: _mapCategory(r.category),
              quantity: 1,
              createdAt: now,
              updatedAt: now,
              aiMetadata: jsonEncode(r.toJson()),
            ),
        ]);
      }
      // Un update per oggetto: ognuno riceve metadati diversi, quindi non è
      // il caso dell'UPDATE in blocco (WHERE id IN). Sono pochi, uno per
      // capo collegato a mano.
      var updated = 0;
      if (links.isNotEmpty) {
        final existing = await repo.getItemsByHouseId(houseId);
        for (final item in existing) {
          final scan = links[item.id];
          // Mai sovrascrivere: due letture AI possono non coincidere.
          if (scan == null || item.aiMetadata != null) continue;
          await repo.updateItem(
            item.copyWith(aiMetadata: jsonEncode(scan.toJson()), updatedAt: now),
          );
          updated++;
        }
      }

      ref.invalidate(itemNotifierProvider(houseId));
      ref.read(syncOrchestratorProvider).requestSync();
      ref
          .read(coreAnalyticsServiceProvider)
          .trackAiItemsSaved(
            count: results.length,
            isOnboarding: false,
            updated: updated,
          );
      state = const AiImportState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'ai_import.save_error'.tr(args: [e.toString()]),
      );
    }
  }
```

  In `saveItemsOnboarding` usa `_newResults` al posto di `allResults` per costruire gli oggetti (in onboarding non ci sono collegamenti).

- [x] **Step 5: analytics** — `trackAiItemsSaved` con `int updated = 0` e `'updated': updated` nelle proprietà; i due metodi nuovi nella sezione AI:

```dart
  /// Foglio "C'è già?" aperto; `has_manual_candidates`: c'era almeno un
  /// oggetto salvato a mano tra i più simili, cioè arricchibile.
  void trackAlreadyHereOpened({required bool hasManualCandidates}) {
    _safeLogEvent(
      'already_here_opened',
      properties: {'has_manual_candidates': hasManualCandidates},
    );
  }

  void trackAlreadyHereDetailsAdded() =>
      _safeLogEvent('already_here_details_added');
```

- [x] **Step 6:** stesso comando dello step 3 → PASS; `dart analyze` pulito (la pagina dei risultati usa ancora `deleteItem`: in questo task sostituisci la sola chiamata `onDelete: () => notifier.deleteItem(gi, ii)` con `onDelete: () => notifier.setIncluded(gi, ii, false)` perché compili; la pagina si rifà nel task 3).

- [x] **Step 7: commit**

```bash
git add lib/features/ai_input lib/core/analytics test/features/ai_input test/core/analytics
git commit -m "feat(ai): risultati con esclusioni e collegamenti, metadati mai sovrascritti"
```

---

### Task 2: ingresso diretto con `startAiScan`

**Files:**
- Create: `lib/features/ai_input/helpers/start_ai_scan.dart`
- Modify: `lib/shared/widgets/main_shell.dart` (azione `CreateAction.aiScan`), `lib/features/houses/view/house_detail_screen.dart` (bottone AI), `lib/features/items/view/items_screen.dart` e `lib/features/trips/view/trip_items_selector.dart` (CTA "Scansiona con AI" dello stato vuoto)
- Delete: `lib/features/ai_input/view/ai_clothing_sandbox_screen.dart` e la sua `GoRoute` `/houses/:id/ai-import` (name `ai-import`) in `app_router.dart`
- Modify: `lib/features/ai_input/view/ai_results_screen.dart` (`_flowRouteNames` diventa `{'ai-import-results'}`)
- Test: `test/features/ai_input/helpers/start_ai_scan_test.dart`; aggiorna i test che aprono `/houses/:id/ai-import` (`grep -rn "ai-import'" test lib`)

**Interfaces:**
- Produces: `Future<void> startAiScan(BuildContext context, WidgetRef ref, String houseId)`.

- [x] **Step 1: test che fallisce**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/ai_input/helpers/start_ai_scan.dart';

void main() {
  testWidgets('apre subito il foglio Galleria / Fotocamera', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => startAiScan(context, ref, 'h1'),
              child: const Text('scan'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
  });
}
```

  Prima verifica in `lib/features/ai_input/view/widgets/image_source_sheet.dart` le icone reali di Galleria e Fotocamera e usa quelle nel test.

- [x] **Step 2:** `flutter test test/features/ai_input/helpers/start_ai_scan_test.dart` → FAIL.

- [x] **Step 3: `start_ai_scan.dart`**

```dart
import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/ai_import_notifier.dart';
import '../view/widgets/image_source_sheet.dart';

/// Massimo di foto per scansione.
const kAiScanMaxPhotos = 5;

/// Avvia la scansione AI per [houseId]: foglio Galleria / Fotocamera sopra la
/// schermata corrente, poi analisi e pagina dei risultati. È l'unico
/// ingresso: foglio Crea, bottone AI della casa, stati vuoti.
Future<void> startAiScan(
  BuildContext context,
  WidgetRef ref,
  String houseId,
) async {
  final source = await showImageSourceSheet(
    context,
    gallerySubtitle: 'ai_import.gallery_subtitle'.tr(
      args: ['$kAiScanMaxPhotos'],
    ),
    cameraSubtitle: 'ai_import.camera_subtitle'.tr(),
  );
  if (source == null || !context.mounted) return;

  final picker = ImagePicker();
  final List<File> files;
  if (source == ImageSource.gallery) {
    final picked = await picker.pickMultiImage(
      imageQuality: 80,
      limit: kAiScanMaxPhotos,
    );
    files = [for (final f in picked) File(f.path)];
  } else {
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    files = picked == null ? const [] : [File(picked.path)];
  }
  if (files.isEmpty || !context.mounted) return;

  final notifier = ref.read(aiImportNotifierProvider.notifier)
    ..reset()
    ..setSelectedHouseId(houseId);
  // processFiles alza isLoading prima del primo await: la pagina dei
  // risultati si apre già in caricamento.
  unawaited(notifier.processFiles(files));
  await context.push('/houses/$houseId/ai-import/results');
}
```

- [x] **Step 4: ingressi**
  - `main_shell.dart`, `case CreateAction.aiScan:` → `await startAiScan(context, ref, choice.houseId!);` (al posto di `context.push('/houses/${choice.houseId}/ai-import')`), lasciando il tracciamento dell'evento com'è.
  - `house_detail_screen.dart`: il bottone AI di `_HouseNormalActionBar` riceve una callback `onAiScan` dal `State` (che ha `ref`): `onAiScan: () => startAiScan(context, ref, widget.houseId)`.
  - `items_screen.dart` e `trip_items_selector.dart`: `onCta` della CTA "Scansiona con AI" → `() => startAiScan(context, ref, houseId)`.
  - Cancella `ai_clothing_sandbox_screen.dart`, la sua route e l'import in `app_router.dart`; in `ai_results_screen.dart` `_flowRouteNames = {'ai-import-results'}` e aggiorna il commento di classe (non si arriva più da `AiClothingSandboxScreen` ma da `startAiScan`).
  - `grep -rn "ai-import'\|AiClothingSandboxScreen" lib test` non deve restituire niente (tranne `ai-import/results`).

- [x] **Step 5: verifica** — `flutter test test/features/ai_input test/shared test/features/houses && dart analyze` → verdi. In `test/features/ai_input/view/ai_results_exit_test.dart` le route di prova possono includere `/houses/:id/ai-import`: se il test costruisce lo stack passando di lì, sostituisci quel passaggio con il push diretto dei risultati e scrivilo nel report.

- [x] **Step 6: commit**

```bash
git add lib test
git commit -m "feat(ai): la scansione si apre subito su Galleria/Fotocamera, via la pagina intermedia"
```

---

### Task 3: pagina dei risultati

**Files:**
- Modify: `lib/features/ai_input/view/ai_results_screen.dart`
- Modify: `lib/features/ai_input/view/widgets/ai_result_card.dart` (riscritto)
- Modify: `lib/features/ai_input/view/widgets/ai_photo_group_header.dart` (riscritto)
- Modify: `assets/translations/it-IT.json`, `assets/translations/en-US.json`
- Test: `test/features/ai_input/view/ai_results_screen_test.dart` (nuovo, con l'harness); `ai_results_exit_test.dart` aggiornato se cercava la X in basso

**Interfaces:**
- Consumes: task 1 (`setIncluded`, `newCount`, `updatedCount`, `linkedItemIds`, `excluded`).
- Produces: `AiResultCard({Key? key, required ClothingAnalysisResult item, required TextEditingController controller, required ValueChanged<String> onNameChanged, required bool included, required ValueChanged<bool> onIncludedChanged, String? linkedItemName, VoidCallback? onAlreadyHere, VoidCallback? onUnlink})`; `AiPhotoGroupHeader({Key? key, required File photo, required int photoIndex, required int itemCount})`; `String aiDetailsLine(ClothingAnalysisResult r)` (top-level in `ai_result_card.dart`).

- [x] **Step 1: stringhe** (oggetto `ai_import`):
  - it `"rename_hint": "Tocca un nome per chiamarlo come vuoi tu"`, en `"Tap a name to call it what you like"`;
  - it `"items_count": {"one": "{} capo", "other": "{} capi"}`, en `{"one": "{} item", "other": "{} items"}`;
  - it `"photo_number": "Foto {}"`, en `"Photo {}"`;
  - it `"save_new": {"one": "Salva: {} nuovo", "other": "Salva: {} nuovi"}`, en `{"one": "Save: {} new", "other": "Save: {} new"}`;
  - it `"save_updated": {"one": "Salva: {} aggiornato", "other": "Salva: {} aggiornati"}`, en `{"one": "Save: {} updated", "other": "Save: {} updated"}`;
  - it `"updated_part": {"one": "{} aggiornato", "other": "{} aggiornati"}`, en `{"one": "{} updated", "other": "{} updated"}`;
  - it `"linked": "Già in casa: «{}» · dettagli aggiunti"`, en `"Already at home: “{}” · details added"`;
  - it `"already_here": "C'è già?"`, en `"Already have it?"`;
  - it `"discard_title": "Scartare i risultati?"`, en `"Discard the results?"`; it `"discard_body": "I capi riconosciuti non verranno salvati."`, en `"The recognised items won't be saved."`; it `"discard": "Scarta"`, en `"Discard"`;
  - `common.undo` se non esiste: it `"Annulla"`, en `"Undo"`.

- [x] **Step 2: test che falliscono** — `test/features/ai_input/view/ai_results_screen_test.dart`, sul modello di `test/screenshots/mock_ai_results_test.dart` del branch `mock/ai-results` (harness, `aiImportNotifierProvider.overrideWith(FakeAiImport.new)`, `aiResultsState(houseId: …)` da `support/fakes.dart`): apri `/houses/$kHomeId`, push `/houses/$kHomeId/ai-import/results`, emetti `aiResultsState()`. Test:
  1. caselle spuntate e "Salva: 3 nuovi"; togliendo la seconda casella → "Salva: 2 nuovi" e la riga resta;
  2. le caratteristiche: `find.text('T-shirt · bianco · tinta unita')`;
  3. tocco sulla matita della prima riga → compare un `TextField` col nome;
  4. Casa Milano (ha vestiti): tre "C'è già?"; con `aiResultsState(houseId: kEmptyHouseId)` aperta da `/houses/$kEmptyHouseId`: nessuno;
  5. la destinazione in alto: `find.byKey(const Key('ai_destination'))` mostra "in Casa Milano";
  6. X in alto (`Key('ai_results_close')`) con capi spuntati → dialog "Scartare i risultati?"; "Annulla" lo chiude e la pagina resta; "Scarta" torna alla casa.
  Ogni test finisce con `await app.finish();`.

- [x] **Step 3:** FAIL.

- [x] **Step 4: `ai_result_card.dart`** (riscrittura completa):

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/app_spacing.dart';
import '../../model/clothing_analysis_result.dart';

/// "T-shirt · bianco · tinta unita": quello che l'AI ha capito del capo.
String aiDetailsLine(ClothingAnalysisResult r) => [
  r.subCategory,
  r.baseColor.toLowerCase(),
  r.pattern.toLowerCase(),
].where((s) => s.trim().isNotEmpty).join(' · ');

/// Riga di un capo riconosciuto: casella (spuntata in partenza), nome con
/// la matita (tocco → campo sul posto), caratteristiche lette dall'AI, e a
/// destra "C'è già?" o, se collegato, "Annulla".
class AiResultCard extends StatefulWidget {
  final ClothingAnalysisResult item;
  final TextEditingController controller;
  final ValueChanged<String> onNameChanged;
  final bool included;
  final ValueChanged<bool> onIncludedChanged;

  /// Nome dell'oggetto di casa a cui il capo aggiunge i dettagli.
  final String? linkedItemName;

  /// Non nullo solo se "C'è già?" ha senso (casa con oggetti della stessa
  /// categoria).
  final VoidCallback? onAlreadyHere;
  final VoidCallback? onUnlink;

  const AiResultCard({
    super.key,
    required this.item,
    required this.controller,
    required this.onNameChanged,
    required this.included,
    required this.onIncludedChanged,
    this.linkedItemName,
    this.onAlreadyHere,
    this.onUnlink,
  });

  @override
  State<AiResultCard> createState() => _AiResultCardState();
}

class _AiResultCardState extends State<AiResultCard> {
  bool _editing = false;

  void _stopEditing() {
    if (_editing) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final linked = widget.linkedItemName != null;
    final active = widget.included && !linked;
    final dim = cs.onSurface.withValues(alpha: 0.38);
    final nameStyle = textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      color: active ? cs.onSurface : dim,
    );
    final detailStyle = textTheme.bodySmall?.copyWith(
      color: active ? cs.onSurfaceVariant : dim,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacingXs),
      child: Row(
        children: [
          Checkbox(
            value: active,
            // Collegato: non è né nuovo né escluso, si torna indietro con
            // "Annulla".
            onChanged: linked
                ? null
                : (v) => widget.onIncludedChanged(v ?? false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_editing)
                  TextField(
                    controller: widget.controller,
                    autofocus: true,
                    style: nameStyle,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: widget.onNameChanged,
                    onSubmitted: (_) => _stopEditing(),
                    onTapOutside: (_) => _stopEditing(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'ai_import.item_name_hint'.tr(),
                    ),
                  )
                else
                  InkWell(
                    key: const Key('ai_result_name'),
                    onTap: () => setState(() => _editing = true),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(widget.controller.text, style: nameStyle),
                        ),
                        SizedBox(width: context.spacingXs),
                        Icon(
                          Icons.edit_outlined,
                          size: context.iconSizeSm,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: context.spacingXs / 2),
                Text(
                  linked
                      ? 'ai_import.linked'.tr(args: [widget.linkedItemName!])
                      : aiDetailsLine(widget.item),
                  style: detailStyle,
                ),
              ],
            ),
          ),
          if (linked && widget.onUnlink != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
              onPressed: widget.onUnlink,
              child: Text('common.undo'.tr()),
            )
          else if (widget.onAlreadyHere != null)
            TextButton(
              key: const Key('ai_already_here'),
              style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
              onPressed: widget.onAlreadyHere,
              child: Text('ai_import.already_here'.tr()),
            ),
        ],
      ),
    );
  }
}
```

- [x] **Step 5: `ai_photo_group_header.dart`** (riscrittura):

```dart
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_group_header.dart';

/// Intestazione del gruppo di una foto: la foto intera, grande (tocco →
/// schermo intero), e l'etichetta "Foto 1 · 2 capi" come i gruppi della casa.
class AiPhotoGroupHeader extends StatelessWidget {
  final File photo;
  final int photoIndex;
  final int itemCount;

  const AiPhotoGroupHeader({
    super.key,
    required this.photo,
    required this.photoIndex,
    required this.itemCount,
  });

  void _openFull(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        key: const Key('ai_photo_viewer'),
        child: Stack(
          children: [
            Center(child: InteractiveViewer(child: Image.file(photo))),
            SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'common.close'.tr(),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = context.responsive(88);
    return Padding(
      padding: EdgeInsets.only(top: context.spacingMd),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
            onTap: () => _openFull(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                AppConstants.cardBorderRadius,
              ),
              child: Image.file(
                photo,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: context.spacingMd),
          Expanded(
            child: DsGroupHeader(
              label: 'ai_import.photo_number'.tr(args: ['$photoIndex']),
              detail: 'ai_import.items_count'.plural(itemCount),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [x] **Step 6: `ai_results_screen.dart`**
  1. `build`: `AppBar(title: …, leading: widget.isFirstTimeOnboarding ? null : IconButton(key: const Key('ai_results_close'), icon: const Icon(Icons.close), tooltip: 'common.close'.tr(), onPressed: _confirmExit))`; la pagina in un `PopScope(canPop: widget.isFirstTimeOnboarding, onPopInvokedWithResult: (didPop, _) { if (!didPop) _confirmExit(); }, child: …)`.
  2. Metodo:

```dart
  /// X in alto e indietro: se ci sono capi da salvare chiede conferma, poi
  /// torna alla casa (vedi [_exitToHouse]).
  Future<void> _confirmExit() async {
    final notifier = ref.read(aiImportNotifierProvider.notifier);
    final pending = notifier.newCount + notifier.updatedCount;
    if (pending > 0 && !ref.read(aiImportNotifierProvider).isLoading) {
      final ok = await DialogHelpers.showConfirmation(
        context: context,
        title: 'ai_import.discard_title'.tr(),
        message: 'ai_import.discard_body'.tr(),
        confirmLabel: 'ai_import.discard'.tr(),
        isDestructive: true,
      );
      if (!ok || !mounted) return;
    }
    _exitToHouse();
  }
```

     (verifica la firma di `DialogHelpers.showConfirmation` e il tipo che restituisce; adatta se è `Future<bool?>`).
  3. `_buildResults`: sotto "N capi identificati" il testo `'ai_import.rename_hint'.tr()`; poi, se non in onboarding e c'è una casa selezionata, la destinazione:

```dart
              if (!widget.isFirstTimeOnboarding && selectedHouse != null)
                InkWell(
                  key: const Key('ai_destination'),
                  borderRadius: BorderRadius.circular(
                    AppConstants.pillBorderRadius,
                  ),
                  onTap: () => _showHousePicker(state, notifier),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: context.spacingXs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          HouseIcons.getIcon(selectedHouse.iconName),
                          size: context.iconSizeSm,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: context.spacingXs),
                        Text(
                          'create_sheet.in_house'.tr(
                            args: [selectedHouse.displayName],
                          ),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Icon(
                          Icons.expand_more,
                          size: context.iconSizeSm,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
```

     con `selectedHouse` letto da `houseNotifierProvider` come fa oggi `_buildResultsBar`.
  4. Gruppi: `AiPhotoGroupHeader(photo:, photoIndex: gi + 1, itemCount: results.length)`; togli lo `SizedBox` e il `Divider` tra i gruppi. Ogni riga:

```dart
                AiResultCard(
                  key: ValueKey('ai_result_${gi}_$ii'),
                  item: group.results[ii],
                  controller: _controllers[gi][ii],
                  onNameChanged: (value) { /* debounce come oggi */ },
                  included: !group.excluded.contains(ii),
                  onIncludedChanged: (v) => notifier.setIncluded(gi, ii, v),
                  linkedItemName: _linkedName(group.linkedItemIds[ii]),
                  onUnlink: () => notifier.unlink(gi, ii),
                  onAlreadyHere: _showAlreadyHere(state, group.results[ii])
                      ? () => _openAlreadyHere(state, gi, ii)
                      : null,
                ),
```

     dove `_showAlreadyHere` restituisce `false` in onboarding o senza casa, altrimenti se esiste un oggetto della casa con `category.name == result.category` (da `itemNotifierProvider(state.selectedHouseId!)`); `_linkedName(id)` restituisce il nome dell'oggetto con quell'id nella stessa lista (o `null`); `_openAlreadyHere` arriva nel task 4: per ora `Future<void> _openAlreadyHere(AiImportState state, int gi, int ii) async {}`.
  5. `_buildResultsBar`: solo il bottone principale, nessuna `leftAction`/`rightAction`:

```dart
    final newCount = notifier.newCount;
    final updatedCount = notifier.updatedCount;
    final String label;
    if (newCount == 0 && updatedCount == 0) {
      label = 'common.save'.tr();
    } else if (updatedCount == 0) {
      label = 'ai_import.save_new'.plural(newCount);
    } else if (newCount == 0) {
      label = 'ai_import.save_updated'.plural(updatedCount);
    } else {
      label =
          '${'ai_import.save_new'.plural(newCount)} · '
          '${'ai_import.updated_part'.plural(updatedCount)}';
    }
```

     `onPrimaryPressed`: `null` se non c'è niente da salvare, se sta caricando o (fuori onboarding) senza casa; altrimenti `saveItemsOnboarding` / `saveItems`. Il ramo "l'AI non ha trovato niente" (`retry_photo`) resta. Togli gli import diventati inutili (`circular_action_button.dart`).
  6. Il listener del salvataggio riuscito: il conteggio della snackbar usa i nuovi + aggiornati del `prev` (calcolali come fa il notifier, oppure salvali in un campo prima di chiamare il salvataggio).

- [x] **Step 7: verifica** — `flutter test test/features/ai_input && dart analyze && flutter test` → verdi.

- [x] **Step 8: commit**

```bash
git add lib/features/ai_input assets/translations test/features/ai_input
git commit -m "feat(ai): risultati con casella, nome modificabile, caratteristiche e un solo Salva"
```

---

### Task 4: foglio "C'è già?"

**Files:**
- Modify: `lib/shared/widgets/ds_sheet_header.dart` (parametro `onClose` opzionale: X a destra del titolo)
- Create: `lib/features/ai_input/view/widgets/already_here_sheet.dart`
- Modify: `lib/features/ai_input/view/ai_results_screen.dart` (`_openAlreadyHere`)
- Modify: traduzioni
- Test: `test/features/ai_input/view/already_here_sheet_test.dart` (con l'harness), test di `DsSheetHeader` se esiste

**Interfaces:**
- Produces: `Future<String?> showAlreadyHereSheet(BuildContext context, {required String houseId, required ClothingAnalysisResult scanned})` → id dell'oggetto a cui aggiungere i dettagli, `null` se chiuso. `DsSheetHeader({required String title, VoidCallback? onClose})`.

- [x] **Step 1: stringhe** (`ai_import`): it `"already_here_title": "C'è già in {}?"` / en `"Already in {}?"`; it `"from_photo": "Dalla foto: {}"` / en `"From the photo: {}"`; it `"most_similar": "Più simili"` / en `"Most similar"`; it `"others_of": "Altri {}"` / en `"Other {}"` (con la categoria minuscola, es. `vestiti`/`categories.vestiti`.tr()); it `"add_details": "Aggiungi i dettagli"` / en `"Add the details"`; it `"already_here_help": "Se c'è già, togli la spunta per non aggiungerlo."` / en `"If you already have it, untick it so it isn't added."`.

- [x] **Step 2: test che falliscono** — `already_here_sheet_test.dart` con l'harness. Prepara gli oggetti: in Casa Milano gli oggetti del seed non hanno `aiMetadata` (verifica in `seed.dart`); per avere anche un oggetto "già scansionato" inseriscine uno con `aiMetadata: '{}'` via `itemRepositoryProvider.insertMultipleItems` e `container.invalidate(itemNotifierProvider(kHomeId))`, come in `test/screenshots/mock_list_test.dart` del branch `mock/house-list`. Poi apri i risultati con `aiResultsState()`:
  1. "C'è già?" sulla riga "T-shirt bianca" (seconda riga: `find.byKey(const Key('ai_already_here')).at(1)`) → foglio con "C'è già in Casa Milano?", "Più simili · 1" con "T-shirt bianca", "Altri vestiti" chiuso (le sue righe non ci sono finché non lo tocchi);
  2. sulla riga di "Più simili" senza metadati c'è "Aggiungi i dettagli"; sull'oggetto con metadati no, e ha la ✨;
  3. "Aggiungi i dettagli" → il foglio si chiude, la riga mostra "Già in casa: «T-shirt bianca» · dettagli aggiunti", il bottone diventa "Salva: 2 nuovi · 1 aggiornato", e `trackAlreadyHereDetailsAdded` è chiamato (override di `coreAnalyticsServiceProvider` con un mock, come in `house_detail_screen_test.dart`);
  4. aprendo il foglio parte `trackAlreadyHereOpened(hasManualCandidates: true)`;
  5. la X del foglio lo chiude senza cambiare niente ("Salva: 3 nuovi").

- [x] **Step 3:** FAIL.

- [x] **Step 4: `ds_sheet_header.dart`** — `final VoidCallback? onClose;` (`this.onClose` nel costruttore); il titolo va in una `Row` con `Expanded(child: Text(…))` e, se `onClose != null`, `IconButton(key: const Key('sheet_close'), icon: const Icon(Icons.close), tooltip: MaterialLocalizations.of(context).closeButtonTooltip, onPressed: onClose)`. Senza `onClose` l'aspetto resta identico.

- [x] **Step 5: `already_here_sheet.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/core_analytics_service.dart';
import '../../../../shared/helpers/search_match.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_group_header.dart';
import '../../../../shared/widgets/ds_sheet_header.dart';
import '../../../houses/providers/house_provider.dart';
import '../../../items/model/item_model.dart';
import '../../../items/providers/item_provider.dart';
import '../../model/clothing_analysis_result.dart';
import 'ai_result_card.dart' show aiDetailsLine;

/// Apre "C'è già?" per un capo riconosciuto. Restituisce l'id dell'oggetto a
/// cui aggiungere i dettagli, o `null` se lo si chiude e basta.
Future<String?> showAlreadyHereSheet(
  BuildContext context, {
  required String houseId,
  required ClothingAnalysisResult scanned,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AlreadyHereSheet(houseId: houseId, scanned: scanned),
  );
}

/// Quante parole del capo (tipo, colore, parole del nome) compaiono nel nome
/// dell'oggetto. Solo un ordinamento: l'app non dichiara mai un doppione.
int alreadyHereScore(ClothingAnalysisResult scanned, ItemModel item) {
  final words = {
    scanned.subCategory,
    scanned.baseColor,
    ...scanned.name.split(' '),
  }.map(normalizeForSearch).where((w) => w.length >= 3);
  final name = normalizeForSearch(item.name);
  return words.where(name.contains).length;
}

class _AlreadyHereSheet extends ConsumerStatefulWidget {
  final String houseId;
  final ClothingAnalysisResult scanned;

  const _AlreadyHereSheet({required this.houseId, required this.scanned});

  @override
  ConsumerState<_AlreadyHereSheet> createState() => _AlreadyHereSheetState();
}

class _AlreadyHereSheetState extends ConsumerState<_AlreadyHereSheet> {
  bool _othersOpen = false;
  bool _tracked = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final s = widget.scanned;
    final houseName =
        ref
            .watch(houseNotifierProvider)
            .valueOrNull
            ?.where((h) => h.id == widget.houseId)
            .firstOrNull
            ?.displayName ??
        '';
    final sameCategory =
        (ref.watch(itemNotifierProvider(widget.houseId)).valueOrNull ??
                const <ItemModel>[])
            .where((i) => i.category.name == s.category)
            .toList();
    final scored = [for (final i in sameCategory) (i, alreadyHereScore(s, i))]
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final similar = [for (final e in scored) if (e.$2 > 0) e.$1];
    final others = [for (final e in scored) if (e.$2 == 0) e.$1];

    if (!_tracked) {
      _tracked = true;
      ref
          .read(coreAnalyticsServiceProvider)
          .trackAlreadyHereOpened(
            hasManualCandidates: similar.any((i) => i.aiMetadata == null),
          );
    }

    Widget row(ItemModel item, {required bool canAddDetails}) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Flexible(
            child: Text(
              item.name,
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          if (item.aiMetadata != null) ...[
            SizedBox(width: context.spacingXs),
            Icon(
              Icons.auto_awesome,
              size: context.iconSizeSm,
              color: cs.onSurfaceVariant,
            ),
          ],
        ],
      ),
      subtitle: (item.quantity ?? 1) > 1 ? Text('x${item.quantity}') : null,
      trailing: canAddDetails && item.aiMetadata == null
          ? TextButton(
              key: ValueKey('add_details_${item.id}'),
              onPressed: () {
                ref
                    .read(coreAnalyticsServiceProvider)
                    .trackAlreadyHereDetailsAdded();
                Navigator.pop(context, item.id);
              },
              child: Text('ai_import.add_details'.tr()),
            )
          : null,
    );

    final categoryLabel = 'categories.${s.category}'.tr().toLowerCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSheetHeader(
          title: 'ai_import.already_here_title'.tr(args: [houseName]),
          onClose: () => Navigator.pop(context),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.spacingMd,
            context.spacingSm,
            context.spacingMd,
            0,
          ),
          child: Text(
            'ai_import.from_photo'.tr(args: ['${s.name} · ${aiDetailsLine(s)}']),
            style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
            children: [
              if (similar.isNotEmpty) ...[
                DsGroupHeader(
                  label: 'ai_import.most_similar'.tr(),
                  count: similar.length,
                ),
                for (final i in similar) row(i, canAddDetails: true),
              ],
              if (others.isNotEmpty) ...[
                DsGroupHeader(
                  label: 'ai_import.others_of'.tr(args: [categoryLabel]),
                  count: others.length,
                  expanded: _othersOpen,
                  onTap: () => setState(() => _othersOpen = !_othersOpen),
                ),
                if (_othersOpen)
                  for (final i in others) row(i, canAddDetails: false),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(context.spacingMd),
          child: Text(
            'ai_import.already_here_help'.tr(),
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
```

  Verifica che `categories.<categoria>` esista per i valori di `result.category` (`vestiti`, `toiletries`, `elettronica`, `varie`); se il capo ha una categoria diversa, usa `ItemCategory` tramite la stessa conversione di `_mapCategory` del notifier e `displayName`.

- [x] **Step 6: `_openAlreadyHere`** in `ai_results_screen.dart`:

```dart
  Future<void> _openAlreadyHere(AiImportState state, int gi, int ii) async {
    final houseId = state.selectedHouseId;
    if (houseId == null) return;
    final itemId = await showAlreadyHereSheet(
      context,
      houseId: houseId,
      scanned: state.photoGroups[gi].results[ii],
    );
    if (itemId == null || !mounted) return;
    ref.read(aiImportNotifierProvider.notifier).linkToExisting(gi, ii, itemId);
  }
```

- [x] **Step 7: verifica** — `flutter test test/features/ai_input test/shared && dart analyze && flutter test` → verdi.

- [x] **Step 8: commit**

```bash
git add lib assets/translations test
git commit -m "feat(ai): foglio C'è già? informativo, con Aggiungi i dettagli solo per gli oggetti scritti a mano"
```

---

### Task 5: screenshot e documentazione

**Files:**
- Modify: `test/screenshots/ui_screenshots_test.dart` (flusso `06-import-ai`)
- Modify: `docs/ui-flows.md` (`git add -f`); `ARCHITECTURE.md` solo locale; spec, se serve

- [x] **Step 1: scenari** — togli gli scenari della pagina intermedia (`import-ai/vuoto`, che apriva `AiClothingSandboxScreen`); lo scenario "scelta sorgente" parte dal bottone AI della casa (`_icon(Icons.auto_awesome)`) e mostra subito il foglio Galleria/Fotocamera. Gli scenari dei risultati restano e si aggiungono:
  - `ai-risultati / un-capo-tolto` (tocco sulla seconda casella);
  - `ai-risultati / nome-in-modifica` (tocco sul primo nome);
  - `ai-risultati / c-e-gia` (foglio aperto sulla T-shirt);
  - `ai-risultati / collegato` (dopo "Aggiungi i dettagli");
  - `ai-risultati / casa-vuota` (risultati per `kEmptyHouseId`: niente "C'è già?");
  - `ai-risultati / conferma-uscita` (X con capi spuntati).
  Numera di seguito agli scenari esistenti del flusso.
- [x] **Step 2:** `flutter test test/screenshots/ui_screenshots_test.dart --dart-define=UI_SCREENSHOTS=true` → verdi, manifest senza problemi; guarda il flusso 06 in chiaro e scuro e confrontalo con il mock (`mock/ai-results`).
- [x] **Step 3:** `docs/ui-flows.md`: ingresso diretto, nuova pagina dei risultati, "C'è già?". `ARCHITECTURE.md`: `startAiScan` unico ingresso; `PhotoGroup.excluded`/`linkedItemIds`; regola "aiMetadata mai sovrascritto"; `DsSheetHeader(onClose:)`.
- [x] **Step 4: commit**

```bash
git add test/screenshots/ui_screenshots_test.dart
git add -f docs/ui-flows.md
git commit -m "test(screenshot): scansione AI con ingresso diretto e risultati nuovi; flussi UI aggiornati"
```

---

### Task 6: PR

- [x] Push su `davidetarsi/PackLog`, PR in bozza [#31](https://github.com/davidetarsi/PackLog/pull/31) verso `develop`. Implementazione GPT-6 Luna, review controller; nessun merge. CI verde: run 38704278524, Lint & Unit Tests passati. Il footer Claude del piano originale è sostituito dall’attribuzione effettiva del lavoro.

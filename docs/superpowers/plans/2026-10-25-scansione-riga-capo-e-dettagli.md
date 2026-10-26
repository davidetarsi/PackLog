# Scansione AI e scheda oggetto: riga del capo e dettagli a tag · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Riga del capo più leggibile nella scansione, sezione "Dettagli" a tag nella scheda oggetto (dalla scansione e dalla casa), tutto in italiano dai dizionari, un solo componente pillola di scelta nel design system, e via l'arricchimento "Aggiungi i dettagli".

**Spec:** `docs/superpowers/specs/2026-10-25-scansione-riga-capo-e-dettagli-design.md` · **Etichette:** `docs/superpowers/specs/2026-10-25-dettagli-etichette-it-en.md` (la lista si può correggere dopo: le chiavi non cambiano) · **Mock:** `docs/superpowers/mock/scansione/` (`mock-v3.diff.txt` ha il codice usa e getta dei mock).

**Architecture:** I dettagli restano dentro `aiMetadata` (stesso JSON, stesse chiavi del server): niente schema nuovo. Il modello già esistente `ClothingAnalysisResult` (con `extras` per le chiavi non tipizzate) è il formato di lettura/scrittura sia per i capi della scansione sia per gli oggetti della casa. Una tassonomia Dart rispecchia `supabase/functions/_shared/valigia/tassonomia.ts` con un test di coerenza. Due widget condivisi nuovi (`DsChoicePill`, `DsChoiceGroup`) in `lib/shared/widgets/`.

**Tech Stack:** Flutter 3.38, Riverpod 2.5 (code-gen), Drift, Freezed, easy_localization, mocktail; harness screenshot `test/screenshots/`.

## Global Constraints

- Tutte le stringhe visibili nei dizionari `assets/translations/it-IT.json` e `en-US.json`, mai testo fisso nel codice.
- Solo token del design system: `context.spacingXs/Sm/Md/Lg`, `context.iconSizeSm/Md/Lg`, `context.responsive()`, `AppConstants.*`, `Theme.of(context).colorScheme`/`textTheme`. Niente numeri sparsi.
- L'arancio resta dei bottoni principali e della casella; pillole e titoli neutri.
- Provider → Repository → DAO; niente accesso al DB dalla UI. Modelli Freezed immutabili. Dopo modifiche a Freezed/@riverpod: `dart run build_runner build --delete-conflicting-outputs`.
- I valori salvati in `aiMetadata` restano quelli del server (`subCategory`, `warmth` 1–5, `waterResistance` 0–2, `formality` uno di Loungewear/Casual/Smart Casual/Business/Formal, `activityTags` dagli 8 valori, `baseColor` testo libero italiano max 40). Si traduce solo la visualizzazione.
- Colori di base, in quest'ordine: Bianco, Nero, Grigio, Blu, Marrone, Beige (si salva la parola italiana anche con l'app in inglese).
- Git: branch `feat/scansione-dettagli` da `origin/develop`; niente push su `develop`/`main`; mai `git worktree add`; non toccare i branch `codex/*` né i file non tracciati dell'utente. Commit con l'attribuzione indicata dall'ambiente.
- Ogni task: test della parte toccata + `dart analyze lib test` puliti prima del commit.
- Implementatori: modello economico per i task meccanici (1, 2, 3), modello standard per gli altri; revisore per ogni task; revisione finale con gli screenshot veri.

---

### Task 0: Branch e documenti

**Files:** nessun file di codice. Documenti: i 38 di `bc08263`, la spec, la lista etichette, questo piano, i mock in `docs/superpowers/mock/scansione/`.

- [ ] **Step 1:** `git fetch origin && git switch -c feat/scansione-dettagli origin/develop` (dalla cartella del progetto; prima `git status` per assicurarsi che non ci siano modifiche tracciate in sospeso sul branch corrente).
- [ ] **Step 2:** `git cherry-pick bc08263` (documenti di ottobre già ripuliti).
- [ ] **Step 3:** Controllo dei temi esclusi sui documenti nuovi (spec, lista etichette, piano, mock), con la stessa lista concordata con l'utente il 21/10. Usare uno script Python (non `grep`, che qui è sostituito). Correggere le copie se serve.
- [ ] **Step 4:** `git add -f` dei soli file elencati, uno per uno, con percorsi espliciti; `git diff --cached --name-only` deve contenere solo quelli. Commit `docs: specifica, piano e mock di scansione e dettagli`.
- [ ] **Step 5:** Dopo ogni cambio di branch successivo ricordare che i documenti tracciati spariscono dalla cartella se il branch di arrivo non li ha (vedi incidente del 25/10): non serve fare niente finché si resta su questo branch.

---

### Task 1: Tassonomia Dart e valori dei dettagli

**Files:**
- Create: `lib/features/items/model/clothing_taxonomy.dart`
- Test: `test/features/items/model/clothing_taxonomy_test.dart`

**Interfaces — Produces:**
```dart
/// Categorie in ordine di visualizzazione.
const List<String> kClothingCategories = ['Upper Body', 'Lower Body', 'Full Body', 'Shoes', 'Outerwear', 'Accessory', 'Essentials'];
/// Sottocategorie per categoria, nell'ordine di tassonomia.ts (vecchie poi nuove), con 'Other' in fondo a ogni gruppo.
const Map<String, List<String>> kClothingTypes = {...};
const String kClothingOther = 'Other';
/// La categoria di una sottocategoria; null se sconosciuta o se è 'Other'.
String? clothingCategoryOf(String subCategory);
const List<int> kWarmthLevels = [1, 2, 3, 4, 5];
const List<int> kWaterResistanceLevels = [0, 1, 2];
const List<String> kFormalities = ['Loungewear', 'Casual', 'Smart Casual', 'Business', 'Formal'];
const List<String> kActivityTags = ['Everyday', 'Office', 'Beach', 'Swimming', 'Hiking', 'Sport', 'Formal', 'Lounge'];
const List<String> kBaseColors = ['Bianco', 'Nero', 'Grigio', 'Blu', 'Marrone', 'Beige'];
/// Chiave del dizionario per un valore: minuscolo, non alfanumerici → '_' ("Cap/Hat" → "cap_hat").
String clothingKey(String value);
```

- [ ] **Step 1: test che falliscono.**
  - Coerenza col server: il test legge `supabase/functions/_shared/valigia/tassonomia.ts` come testo, estrae con regex le chiavi di `VECCHIE`, `NUOVE` e la lista `CATEGORIE`, e confronta: stesso insieme di categorie, stesso insieme di sottocategorie per categoria (Dart ha in più solo `Other`).
  - Le liste formality/activity coincidono con `FORMALITA` e `TAG` di `supabase/functions/_shared/capi/scheda.ts` (stessa estrazione da testo).
  - `clothingCategoryOf('Fleece') == 'Upper Body'`, `clothingCategoryOf('Other') == null`, `clothingCategoryOf('Boh') == null`.
  - `clothingKey('Cap/Hat') == 'cap_hat'`, `clothingKey('Smart Casual') == 'smart_casual'`.
- [ ] **Step 2:** implementazione.
- [ ] **Step 3:** test verdi, `dart analyze`, commit `feat(items): tassonomia dei capi lato app`.

---

### Task 2: Etichette nei dizionari

**Files:**
- Modify: `assets/translations/it-IT.json`, `assets/translations/en-US.json` (inserimento testuale, senza riformattare il file: vedi come sono stati aggiunti i blocchi `trips.pack.*`)
- Create: `lib/features/items/model/clothing_labels.dart`
- Test: `test/features/items/model/clothing_labels_test.dart`

**Interfaces — Consumes:** Task 1. **Produces:**
```dart
String clothingTypeLabel(String subCategory);   // 'clothing.type.<key>'.tr()
String clothingGroupLabel(String category);      // 'clothing.group.<key>'.tr()
String warmthLabel(int level);                   // 'clothing.warmth.<n>'.tr()
String waterResistanceLabel(int level);          // 'clothing.water.<n>'.tr()
String formalityLabel(String value);             // 'clothing.formality.<key>'.tr()
String activityLabel(String value);              // 'clothing.activity.<key>'.tr()
/// Colore da mostrare: un colore di base si traduce (clothing.color.<key>), gli altri si mostrano come scritti, con l'iniziale maiuscola.
String colorLabel(String color);
```
Chiavi nuove (valori dalla lista etichette): `clothing.type.*`, `clothing.group.*`, `clothing.warmth.1..5`, `clothing.water.0..2`, `clothing.formality.*`, `clothing.activity.*`, `clothing.color.*`, e i testi `clothing.details.{title,type,color,warmth,water,formality,uses,uses_hint,to_check,other_color,color_hint,choose_type}`, `ai_import.to_check` (plurale: one "{} da controllare" / other "{} da controllare").

- [ ] **Step 1: test che falliscono:** ogni valore di `kClothingTypes`, `kClothingCategories`, livelli, `kFormalities`, `kActivityTags`, `kBaseColors` ha la chiave in **entrambi** i dizionari (lettura dei JSON da disco come fa `test/helpers/memory_asset_loader.dart`); `colorLabel('verde scuro') == 'Verde scuro'`; `colorLabel('Blu')` in en == `'Blue'`.
- [ ] **Step 2:** chiavi nei dizionari e funzioni.
- [ ] **Step 3:** test verdi, commit `feat(items): etichette dei dettagli in italiano e inglese`.

---

### Task 3: Pillola e gruppo di scelta nel design system

**Files:**
- Create: `lib/shared/widgets/ds_choice_pill.dart`, `lib/shared/widgets/ds_choice_group.dart`
- Modify: `lib/shared/widgets/ds_field_label.dart` (variante evidente), `lib/shared/widgets/widgets.dart` (export, se il barrel li elenca)
- Test: `test/shared/widgets/ds_choice_pill_test.dart`, `test/shared/widgets/ds_choice_group_test.dart`

**Interfaces — Produces:**
```dart
/// Pillola di scelta compatta: bordo e testo, niente icone. Faccia alta
/// AppConstants.pillTabCompact, area di tocco kMinInteractiveDimension,
/// padding orizzontale spacingSm + spacingXs, testo labelLarge.
/// Scelta: bordo e testo onSurface, e nel tema chiaro sfondo surfaceContainerHigh.
/// Non scelta: bordo outlineVariant, testo onSurfaceVariant, sfondo trasparente.
class DsChoicePill extends StatelessWidget {
  const DsChoicePill({super.key, required this.label, required this.selected, required this.onTap});
}

/// Gruppo di pillole con titolo. [note] sta sulla stessa riga del titolo
/// (grigio); con [doubt] la nota diventa "?" + testo in onSurface.
class DsChoiceGroup<T> extends StatelessWidget {
  const DsChoiceGroup({
    super.key,
    required this.title,
    required this.options,          // List<T>
    required this.labelOf,          // String Function(T)
    required this.selected,         // Set<T>
    required this.onChanged,        // ValueChanged<Set<T>>
    this.multiple = false,
    this.required = true,           // non si può restare senza scelta
    this.note,
    this.doubt = false,
    this.trailing,                  // es. la pillola "+ Altro colore"
  });
}
```
- `DsFieldLabel`: aggiungere `const DsFieldLabel.prominent(this.text)` con stile `titleMedium` semibold `onSurface` e padding `top: spacingLg, bottom: spacingXs`; `static TextStyle? prominentStyle(BuildContext)`. Lo stile normale resta com'è per gli altri fogli. `DsChoiceGroup` usa `prominentStyle` per il titolo.
- Regole di scelta: singola e obbligatoria → toccare la scelta non la toglie; singola facoltativa → la toglie; multipla obbligatoria → l'ultima non si toglie.

- [ ] **Step 1: test che falliscono:** aspetto (altezza faccia, colori di bordo/testo/sfondo per chiaro e scuro, nessuna `Icon`), semantica `selected`, area di tocco ≥ 48; le tre regole di scelta; la nota sulla stessa riga del titolo (stessa `dy` di centro ± 4); `doubt` mostra `Icons.help_outline`.
- [ ] **Step 2:** implementazione, poi verdi; commit `feat(ui): pillola e gruppo di scelta nel design system`.
- [ ] **Nota:** `AiChoicePill` vive su `feat/valigia-ai` (non in develop): non si tocca qui. Va segnato nella PR che quel branch la deve sostituire con `DsChoicePill` quando si allinea.

---

### Task 4: Dettagli dentro i metadati (lettura, modifica, dubbi)

**Files:**
- Modify: `lib/features/ai_input/model/clothing_analysis_result.dart`
- Create: `lib/features/items/model/clothing_details.dart`
- Test: `test/features/ai_input/model/clothing_analysis_result_test.dart` (crearlo se manca), `test/features/items/model/clothing_details_test.dart`

**Interfaces — Consumes:** Task 1. **Produces:**
```dart
// ClothingAnalysisResult: nuovi
List<String> get doubts;                 // campi in dubbio dal server, NON in toJson
int get waterResistance;                 // da extras['waterResistance'], default 0
ClothingAnalysisResult withDoubts(List<String> doubts);
// fromItemMetadata legge json['dubbi'] (lista di {campo, ...}) → doubts = i 'campo'

/// I dettagli modificabili di un capo, letti da e riscritti in un ClothingAnalysisResult.
class ClothingDetails {
  final String subCategory;
  final String? color;            // null se vuoto o 'N/A'
  final int warmth;
  final int waterResistance;
  final String formality;
  final Set<String> uses;
  factory ClothingDetails.of(ClothingAnalysisResult r);
  ClothingDetails copyWith({...});
  /// Riscrive i campi; cambia anche `category` secondo clothingCategoryOf
  /// (solo se la sottocategoria è nota); tiene ogni altra chiave ed extras.
  ClothingAnalysisResult applyTo(ClothingAnalysisResult r);
  /// Nomi dei campi cambiati rispetto a [before], per l'evento analytics.
  List<String> changedFields(ClothingDetails before);
}
/// Lettura comoda da ItemModel.aiMetadata (null se assente o non è un capo).
ClothingAnalysisResult? clothingFromMetadata(String? aiMetadata);
```
- "Non è un capo": `category == 'Not Clothing'` o JSON non leggibile.

- [ ] **Step 1: test che falliscono:** parse di `dubbi`; `toJson()` non contiene `doubts`; `applyTo` conserva chiavi sconosciute (`bulk`, `coverage`, `fit`, `notClothingKind`…) e `waterResistance` finisce in `extras`; cambio tipo `Sweater`→`Hiking Boots` sposta `category` a `Shoes`; `color` null per `'N/A'`; `changedFields`.
- [ ] **Step 2:** implementazione, `build_runner` se il modello è Freezed (oggi non lo è: verificare), test verdi, commit `feat(items): dettagli dei capi letti e scritti nei metadati`.

---

### Task 5: Colori dell'utente

**Files:**
- Modify: `lib/features/items/repositories/item_repository.dart` (+ implementazione Drift)
- Create: `lib/features/items/providers/user_colors_provider.dart` (+ `.g.dart`)
- Test: `test/features/items/providers/user_colors_provider_test.dart`, test del repository se esiste il file corrispondente

**Interfaces — Produces:**
```dart
// ItemRepository
Future<List<String>> getUsedColors(); // da getAllItems(): baseColor dei metadati, senza 'N/A'/vuoti, deduplicati ignorando maiuscole/spazi, ordinati per frequenza poi alfabetico
// Provider
@riverpod Future<List<String>> userColors(Ref ref); // watcha i cambi degli oggetti (invalidato da ItemNotifier.addItem/updateItem tramite ref.invalidate(userColorsProvider))
/// Pillole del colore: kBaseColors + i colori dell'utente che non sono già tra quelli di base (confronto senza maiuscole).
List<String> colorChoices(List<String> userColors);
```
- [ ] **Step 1: test che falliscono:** doppioni "blu"/"Blu " uniti; 'N/A' escluso; ordine; `colorChoices` non ripete i colori di base.
- [ ] **Step 2:** implementazione (lettura dal repository, nessun SQL nuovo nel repository), `build_runner`, test verdi, commit `feat(items): colori già usati dall'utente`.

---

### Task 6: Sezione "Dettagli" nella scheda oggetto (dalla casa)

**Files:**
- Modify: `lib/features/items/view/item_sheet.dart`
- Create: `lib/features/items/view/widgets/clothing_details_section.dart`
- Modify: `lib/core/analytics/core_analytics_service.dart` (`trackItemDetailsEdited({required String source, required List<String> fields})` → evento `item_details_edited`)
- Test: `test/features/items/view/item_sheet_test.dart`, `test/features/items/view/clothing_details_section_test.dart`

**Interfaces — Consumes:** Task 1–5. **Produces:**
```dart
class ClothingDetailsSection extends ConsumerWidget {
  const ClothingDetailsSection({super.key, required this.details, required this.onChanged, this.doubts = const {}, this.onDoubtResolved});
  // Tipo: riga con DsFieldLabel.prominent + valore + chevron → DsPickerSheet raggruppato per categoria (titolo clothing.details.choose_type)
  // Colore: DsChoiceGroup(required: false) con colorChoices(...) e trailing "+ Altro colore" → campo di testo (dsFieldDecoration, max 40, hint clothing.details.color_hint)
  // Calore, Pioggia, Stile: DsChoiceGroup singola obbligatoria
  // Usi: DsChoiceGroup multipla obbligatoria, note 'clothing.details.uses_hint'
  // doubts: nomi dei campi ('subCategory','warmth','waterResistance','formality') → doubt: true sul gruppo; un tocco nel gruppo chiama onDoubtResolved(campo)
}
```
- Nella scheda: la sezione compare dopo Spazio, solo se `clothingFromMetadata(item.aiMetadata) != null`. Tutti i titoli della scheda passano a `DsFieldLabel.prominent` (Nome, Categoria, Quantità, Spazio, Nota) e `_InlineField` usa `prominentStyle`.
- Il titolo della nota diventa "Nota" (`items.note_label`, nuova chiave), il titolo "Dettagli" (`items.details_label`) va sopra la sezione.
- "Salva" si accende anche con un cambiamento nei dettagli. Al salvataggio: `aiMetadata = jsonEncode(details.applyTo(result).toJson())` dentro lo stesso `updateItem`, poi `trackItemDetailsEdited(source: 'house', fields: changedFields)` se la lista non è vuota.

- [ ] **Step 1: test che falliscono:** sezione presente per un capo, assente per un oggetto senza metadati o non-capo; cambiare Calore e Salva scrive `warmth` nel JSON e lascia le altre chiavi; usi: l'ultimo non si toglie; "+ Altro colore" aggiunge e seleziona "Rosa chiaro"; colori dell'utente mostrati dopo quelli di base; picker del tipo raggruppato; Salva spento a riposo e acceso dopo un tag.
- [ ] **Step 2:** implementazione, test verdi, commit `feat(items): dettagli a tag nella scheda oggetto`.

---

### Task 7: Scheda dalla scansione

**Files:**
- Modify: `lib/features/items/view/item_sheet.dart` (terza modalità), `lib/features/ai_input/providers/ai_import_notifier.dart`
- Test: `test/features/items/view/item_sheet_test.dart`, `test/features/ai_input/providers/ai_import_notifier_test.dart`

**Interfaces — Produces:**
```dart
/// Apre la scheda su un capo della scansione non ancora salvato. Restituisce il capo modificato, o null se si chiude.
Future<ClothingAnalysisResult?> showScanItemSheet(BuildContext context, {required ClothingAnalysisResult result, required String name});
// AiImportNotifier
void updateResult(int groupIndex, int itemIndex, ClothingAnalysisResult result); // sostituisce il capo; il nome segue result.name
```
- Modalità scansione: campi Nome, Categoria, Dettagli (niente Quantità, Spazio, Nota, menu ⋯: si impostano dalla casa dopo il salvataggio — scelta di piano, la spec dice solo "niente ⋯"); titolo `items.edit_item`; bottone `common.save`.
- La Categoria della scheda scrive `appCategory` del capo (stessa regola di `aiItemCategory`).
- Dubbi: la scheda riceve `result.doubts`; quelli risolti si tolgono con `withDoubts` nel risultato restituito.
- Al salvataggio della pagina, se un capo ha dettagli cambiati rispetto all'analisi, `trackItemDetailsEdited(source: 'scan', ...)` (il notifier tiene una copia dei risultati originali).

- [ ] **Step 1: test che falliscono:** apertura dalla scansione senza ⋯ né spazio; modifica di Pioggia → il capo nella pagina ha `waterResistance` nuovo e il dubbio sparito; nome cambiato nella scheda → nome nella riga; chiusura senza Salva → niente cambia.
- [ ] **Step 2:** implementazione, test verdi, commit `feat(ai-import): scheda del capo dalla scansione`.

---

### Task 8: Pagina dei risultati e via l'arricchimento

**Files:**
- Modify: `lib/features/ai_input/view/widgets/ai_photo_group_header.dart`, `lib/features/ai_input/view/widgets/ai_result_card.dart`, `lib/features/ai_input/view/ai_results_screen.dart`, `lib/features/ai_input/view/widgets/already_here_sheet.dart`, `lib/features/ai_input/model/ai_import_state.dart` (+ `.freezed.dart`), `lib/features/ai_input/providers/ai_import_notifier.dart`, `lib/features/items/repositories/item_repository.dart` (+ Drift), `lib/core/database/daos/items_dao.dart`, `lib/core/analytics/core_analytics_service.dart`, dizionari
- Test: i test esistenti di questi file (`test/features/ai_input/...`, `items_dao` e repository) aggiornati

- [ ] **Foto:** foto intera alta `context.responsive(160)`, `Align(centerLeft)`, `ClipRRect` con `cardBorderRadius`, niente `Material` colorato attorno; tocco → schermo intero; sotto `DsGroupHeader` "Foto N · M capi". (Riferimento: `mock-v3.diff.txt`.)
- [ ] **Riga del capo:** casella a sinistra; nome `titleMedium` semibold con matita (rinomina sul posto invariata); riga dettagli `bodyMedium`: `clothingTypeLabel(subCategory) · colorLabel(baseColor)` (salta i vuoti/'N/A'), "›", tocco → `showScanItemSheet` → `updateResult`; se `doubts` non è vuoto una riga "?" + `ai_import.to_check` plurale in `onSurface`; "C'è già?" a destra (stessa condizione di oggi). `aiDetailsLine` cambia di conseguenza e si sposta su queste funzioni.
- [ ] **Via l'arricchimento:** `linkedItemIds`, `linkToExisting`, `unlink`, riga "Già in casa…" con "Annulla", il conteggio `updated` e il testo "· N aggiornati" del bottone; in `already_here_sheet.dart` l'azione "Aggiungi i dettagli" (`add_details_*`) e la nota del ✨ se serve solo a quella; `saveAiItemsToHouse` perde `metadataByItemId` e il DAO perde il ramo di arricchimento; `trackAiItemsSaved` perde `updated`; via `already_here_details_added`; chiavi di dizionario non più usate rimosse (verificare con ricerca).
- [ ] **ARCHITECTURE.md:** aggiornare solo se descrive `saveAiItemsToHouse` o l'arricchimento (contratto del repository cambiato).
- [ ] **Test:** riga (tipo e colore in italiano, niente fantasia, conteggio dubbi, "C'è già?" a destra, "›" apre la scheda); foglio "C'è già?" senza "Aggiungi i dettagli"; salvataggio solo di nuovi; DAO/repository senza arricchimento.
- [ ] Commit `feat(ai-import): riga del capo con dettagli e via l'arricchimento`.

---

### Task 9: Screenshot e verifica finale

**Files:** `test/screenshots/ui_screenshots_test.dart`, `test/screenshots/support/fakes.dart`

- [ ] Fake dei risultati: un capo con `doubts: ['waterResistance']` e valori server (inglesi) per verificare la traduzione.
- [ ] Scenari nuovi: `06-import-ai` riga con dubbio; scheda dalla scansione; `05-oggetti` scheda con dettagli (in alto e scorsa fino agli usi); picker del tipo; "+ Altro colore" aperto. Chiaro e scuro.
- [ ] `dart analyze lib test` pulito, `flutter test` tutto verde, screenshot controllati a occhio contro `docs/superpowers/mock/scansione/*-v3-*`.
- [ ] Revisione finale (modello più capace) sul diff da `origin/develop`, con le Minor raccolte nei task.
- [ ] PR verso `develop` con descrizione completa (squash): cosa cambia per l'utente, componenti nuovi, cosa è stato tolto, nota su `AiChoicePill` di `feat/valigia-ai`, verifiche fatte.

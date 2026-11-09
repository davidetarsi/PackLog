# Analytics e Sentry: catalogo eventi — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Far registrare all'app esattamente il catalogo di eventi approvato, tutto dal livello tipato, più gli errori silenziosi in Sentry.

**Architecture:** `CoreAnalyticsService` (core, solo `String`/numeri/liste) diventa l'unico punto che emette eventi: ogni `logEvent` diretto delle feature diventa un metodo tipato con nome e proprietà identici. I calcoli (differenza valigia/proposta, contesto del viaggio, conteggi dello scan) sono funzioni pure nelle feature, testate da sole. Le modifiche alla valigia si osservano in un punto solo, `TripNotifier`, confrontando il viaggio prima e dopo ogni scrittura.

**Tech Stack:** Flutter 3.47, Riverpod (riverpod_annotation), freezed, mocktail, sentry_flutter 8, amplitude_flutter, tgram_analytics 0.2.

**Spec:** `docs/superpowers/analytics-domande.md`, sezione "Catalogo degli eventi" (è il riferimento per ogni nome e proprietà).

## Global Constraints

- Mai nomi di capi, case, viaggi, luoghi, codici promo o testo scritto dall'utente nelle proprietà: solo conteggi, esiti, id generati dal client, id di catalogo (attività, alloggi), sottocategorie della tassonomia, nomi di campi.
- Valori ammessi da tgram: `String`, `int`, `double` finito, `bool`, `null`, liste di questi. Mai `Map` annidate.
- Gli eventi SPOSTATI tengono **nome e proprietà identici** a oggi.
- `lib/core/` non importa da `lib/features/` (regola già scritta in testa a `core_analytics_service.dart`).
- Il gate del consenso resta in `AppAnalyticsService`; non si tocca.
- Sentry non riceve: offline/rete, tetti raggiunti (429), codici rifiutati. Solo guasti.
- Nessuna parola "capospalla" in testi utente (non si aggiungono testi utente in questo lavoro).
- Ramo `feat/analytics-domande`, solo locale: niente push senza Davide.

## Review Focus

1. Valigia senza proposta AI (viaggio fatto a mano, `aiResult == null`): nessun `ai_suitcase_changed`.
2. Spuntare un capo (`toggleItemCheck`) non cambia i conteggi: nessun `ai_suitcase_changed`.
3. Rigenerazione: la nuova proposta sostituisce la vecchia; il primo evento dopo la rigenerazione confronta con la **nuova** proposta (`generatedAt` diverso = niente diff col viaggio precedente, solo stato iniziale).
4. Meteo assente o tappe senza temperature: le proprietà di clima mancano, l'evento parte lo stesso.
5. Capi della casa non ancora caricati (`itemNotifierProvider(houseId).valueOrNull == null`): le liste di sottocategorie restano vuote, i conteggi partono comunque.

Ogni riga ha il suo test nel task che possiede il codice (Task 5 per 1–3 e 5, Task 4 per 4).

---

### Task 1: Livello tipato completo (eventi SPOSTATI e pulizia)

**Files:**
- Modify: `lib/core/analytics/core_analytics_service.dart`
- Modify (chiamanti, sostituire `analyticsServiceProvider`…`.logEvent` con `coreAnalyticsServiceProvider`…`.trackX`): `lib/bootstrap.dart:167`, `lib/features/profile/view/profile_screen.dart:317,460,467`, `lib/features/tour/providers/post_login_onboarding_provider.dart:96`, `lib/features/tour/controllers/tour_orchestrator.dart:113,120,151`, `lib/features/tour/widgets/tour_trigger_wrapper.dart:113,143,152,173`, `lib/features/tour/view/ai_onboarding_intro_screen.dart:34,40`, `lib/features/onboarding/view/onboarding_screen.dart:68,122`, `lib/features/auth/view/login_screen.dart:36,65,77,83,87,108`, `lib/features/trips/providers/trip_provider.dart:277,301`, `lib/features/trips/view/new_trip_screen.dart:251`, `lib/features/trips/view/pack_suitcase_screen.dart:597,621`, `lib/features/trips/view/widgets/slots/slot_fill_flow.dart:161`, `lib/features/trips/view/widgets/slots/slot_edits.dart:33`, `lib/features/trips/view/widgets/slots/trip_kit_row.dart:91,118,134`, `lib/features/kits/view/kit_editor_screen.dart:123`
- Test: `test/core/analytics/core_analytics_service_test.dart`

**Interfaces:**
- Produces (in `CoreAnalyticsService`, ognuno emette l'evento omonimo con le chiavi tra parentesi, esattamente come oggi):
  - `trackAppOpened({required String trigger})` → `app_opened` {trigger}
  - `trackOnboardingPageViewed({required int pageIndex, required String pageName})` → {page_index, page_name}
  - `trackOnboardingSkipped({required int pageIndex})` → {page_index}
  - `trackLoginScreenViewed()`
  - `trackConsentGiven({required String policyVersion})` → {policy_version}
  - `trackLoginAttempted({required String method})`, `trackLoginCompleted({required String method})` → {method}
  - `trackLoginFailed({required String method, String? reason, String? errorType})` → {method, reason?|error_type?} (chiave presente solo se non null, come oggi)
  - `trackAnalyticsOptIn()` → `analytics_opt_in` {enabled: true}; `trackAnalyticsOptOut()` → {enabled: false}
  - `trackOnboardingStepViewed / trackOnboardingStepAdvanced / trackOnboardingClosed({required String stepName, required int stepIndex})` → {step_name, step_index}
  - `trackAiOnboardingStarted()`, `trackAiOnboardingSkipped()`, `trackTourRelaunched()`
  - `trackTourCompleted({required bool skippedAi, required int lastStepIndex})`
  - `trackFirstTripStarted()`
  - `trackFirstSuitcaseGenerated({required int slotsImportant, required int slotsProposed, required int slotsTotal, required int tripItems, required bool fromFirstRun})`
  - `trackKitAutoAdded({required int kits, required int items})`
  - `trackSlotFilled({required String level, required int copies})`, `trackSlotMarkedToBuy({required String level, required String from})`, `trackSlotBought({required String level})`
  - `trackKitSuggestionAccepted({required int missing})`, `trackKitSuggestionDismissed()`, `trackKitUseLearned({required String kind})`, `trackKitCreated({required int items, required int uses})`
  - `trackPackingStarted({required String tripId, required int totalItems, required int? daysToDeparture})`, `trackPackingProgress({required String tripId, required int threshold, required int? daysToDeparture})`, `trackPackingCompleted({required String tripId, required int totalItems, required int? daysToDeparture})` — le chiavi le prende da `packing_progress_tracker.dart:81-118`; `TripNotifier._emitPackingEvents` fa lo switch su `event.name`.
- Rimossi: `trackBulkTemplateToggled`, `trackBulkGenderSet`, `trackBulkSessionSaved`.

- [ ] **Step 1: Test che falliscono** — in `core_analytics_service_test.dart` un gruppo `'eventi spostati'` con un test per metodo, stile dei test esistenti (`service.trackX(...)`, `await pump()`, `verify(() => mockAnalytics.logEvent('nome', properties: {...})).called(1)`). Valori di esempio: `trackLoginFailed(method: 'google', reason: 'cancelled')` → `{'method': 'google', 'reason': 'cancelled'}` senza `error_type`; `trackAnalyticsOptOut()` → `{'enabled': false}`. Togliere i test `bulk_*` se esistono.
- [ ] **Step 2:** `flutter test test/core/analytics/core_analytics_service_test.dart` → FAIL (metodi non definiti).
- [ ] **Step 3:** Aggiungere i metodi (tutti via `_safeLogEvent`), togliere i `bulk_*`, poi sostituire ogni chiamante dell'elenco Files. Nei widget: `ref.read(coreAnalyticsServiceProvider)`. In `bootstrap.dart` costruire `CoreAnalyticsService(analytics)` sull'istanza già in mano.
- [ ] **Step 4:** `grep -rn "\.logEvent(" lib | grep -v lib/core/analytics` → nessun risultato. `flutter test` → i test dei chiamanti (`tour_orchestrator_test`, `onboarding_screen_test`, `post_login_onboarding_provider_test`, `trip_provider_test`, `packing_progress_tracker_test`) passano; dove verificano `logEvent` subito dopo l'azione, aggiungere `await tester.pump()` / `await Future.delayed(Duration.zero)` perché `_safeLogEvent` è fire-and-forget.
- [ ] **Step 5: Commit** `refactor(analytics): tutti gli eventi dal livello tipato, via i bulk_* morti`

---

### Task 2: Tetti, codici promo, errori silenziosi in Sentry

**Files:**
- Modify: `lib/core/analytics/core_analytics_service.dart`
- Modify: `lib/core/routing/app_router.dart:88` (observer)
- Modify: `lib/features/trips/services/trip_weather_service.dart` (nuova `TripWeatherNetworkException extends TripWeatherException`, lanciata nel `catch` attorno a `http.post`)
- Modify: `lib/features/trips/providers/trip_weather_provider.dart:88-95`
- Modify: `lib/features/items/services/item_metadata_service.dart`, `lib/features/items/providers/item_metadata_service_provider.dart`, `lib/features/items/services/item_metadata_backfill.dart`
- Modify: `lib/features/promo/service/promo_code_service.dart` (+ suo provider)
- Modify: `lib/features/ai_input/service/ai_clothing_analyzer_service.dart:77-95`
- Test: `test/core/analytics/core_analytics_service_test.dart`, `test/features/trips/providers/trip_weather_provider_test.dart`, `test/features/items/services/item_metadata_service_test.dart` (crea se manca), `test/features/promo/promo_code_service_test.dart` (crea se manca)

**Interfaces:**
- Produces:
  - `CoreAnalyticsService.trackAiLimitReached({required String feature})` → `ai_limit_reached` {feature}; valori: `suitcase` | `scan` | `weather` | `item_name`.
  - `CoreAnalyticsService.trackPromoCodeRedeemed({required String outcome, int? credits})` → `promo_code_redeemed` {outcome, credits?}.
  - `String promoOutcomeOf(PromoRedeemResult r)` in `promo_redeem_result.dart`: `PromoRedeemed`→`redeemed`, `PromoFailed`→`failed`, `PromoRejected`→ snake_case del motivo (`invalid_code`, `expired`, `exhausted`, `already_redeemed`, `too_late`, `too_many_attempts`).
  - `ItemMetadataService` e `ItemMetadataBackfill` e `PromoCodeService` ricevono opzionali `AppMonitoringService? monitoring` e (solo `ItemMetadataService`, `PromoCodeService`) `CoreAnalyticsService? analytics`, passati dai provider. Null nei test esistenti = nessun cambiamento.

Regole per servizio:
- **Meteo** (`TripWeatherNotifier`): `TripWeatherCapException` → `trackAiLimitReached(feature: 'weather')`; `TripWeatherNetworkException` → niente; altra `TripWeatherException` → `monitoring.captureException(e, tags: {'operation': 'trip_weather'})`.
- **item-metadata** `fromName`: 429 → `trackAiLimitReached(feature: 'item_name')`; altro non-200 → Sentry con tag `{'operation': 'item_metadata', 'status': '<code>'}`; `SocketException`/`TimeoutException`/`http.ClientException` → niente; altre eccezioni (parse) → Sentry. Il ritorno resta `null` in tutti i casi.
- **Backfill**: i due `catch` → Sentry con tag `{'operation': 'item_metadata_backfill'}` (escluse le eccezioni di rete come sopra).
- **Promo** `redeem`: dopo aver calcolato il risultato, `trackPromoCodeRedeemed(outcome: promoOutcomeOf(r), credits: r is PromoRedeemed ? r.credits : null)`; il `catch` manda a Sentry con tag `{'operation': 'promo_redeem'}` salvo eccezioni di rete.
- **Scan**: in `processClothingItem`, se `e is GptLimitExceededException` → `trackAiLimitReached(feature: 'scan')` in più a `trackAiInputFailed` (che resta).
- **Router**: `observers: [AnalyticsNavigatorObserver(analytics), SentryNavigatorObserver()]`.

- [ ] **Step 1: Test che falliscono:**
  - `trackAiLimitReached(feature: 'weather')` → `logEvent('ai_limit_reached', properties: {'feature': 'weather'})`.
  - `trackPromoCodeRedeemed(outcome: 'expired')` → `{'outcome': 'expired'}` (niente chiave `credits`).
  - `promoOutcomeOf(const PromoRejected(PromoRejectReason.alreadyRedeemed))` == `'already_redeemed'`.
  - `trip_weather_provider_test`: servizio finto che lancia `TripWeatherCapException` → `verify(analytics.trackAiLimitReached(feature: 'weather')).called(1)`, `verifyNever(monitoring.captureException(...))`; che lancia `TripWeatherException('HTTP 500')` → `captureException` chiamato una volta; che lancia `TripWeatherNetworkException` → nessuno dei due.
  - `item_metadata_service_test` con `MockClient` di `package:http/testing.dart`: 429 → `trackAiLimitReached(feature: 'item_name')` e risultato `null`; 500 → `captureException` con tag `status: '500'`.
- [ ] **Step 2:** `flutter test` sui file sopra → FAIL.
- [ ] **Step 3:** Implementare secondo le regole sopra.
- [ ] **Step 4:** `flutter test` sui file sopra → PASS; `flutter analyze` pulito.
- [ ] **Step 5: Commit** `feat(analytics): tetti AI, codici promo ed errori silenziosi in Sentry`

---

### Task 3: Scan — `ai_items_saved` arricchito e `ai_scan_doubt_resolved`

**Files:**
- Modify: `lib/features/ai_input/model/clothing_analysis_result.dart` (tenere anche la proposta di Jev dei dubbi)
- Create: `lib/features/ai_input/helpers/scan_analytics.dart`
- Modify: `lib/features/ai_input/providers/ai_import_notifier.dart` (`_trackScanEdits`, `saveItems`, `saveItemsOnboarding`)
- Modify: `lib/core/analytics/core_analytics_service.dart`
- Test: `test/features/ai_input/helpers/scan_analytics_test.dart`, `test/features/ai_input/providers/ai_import_notifier_test.dart`

**Interfaces:**
- Produces:
  - `ClothingAnalysisResult.doubtJev`: `Map<String, Object?>` campo → valore `jev` della voce di `dubbi` (default `{}`; incluso in `copyWith`, `==`, `hashCode`; **non** scritto in `toJson`, che finisce in `ai_metadata`).
  - In `scan_analytics.dart`:
    - `typedef ScanSaveStats = ({int found, int saved, int excluded, int linked, int renamed, int detailsEdited, int photos, List<String> excludedTypes, List<String> renamedTypes});`
    - `ScanSaveStats scanSaveStats(AiImportState state, Map<(int, int), ClothingAnalysisResult> analyzed)` — `found` = tutti i risultati; `excluded` = indici in `excluded`; `linked` = chiavi di `linkedItemIds`; `renamed` = salvati (non esclusi, non collegati) con nome diverso dall'originale dopo `trim()`; `detailsEdited` = salvati con `changedFields` non vuoto; `photos` = numero di gruppi; i `*Types` = `subCategory` dell'**originale**, ordinate, con ripetizioni.
    - `typedef DoubtOutcome = ({List<String> doubtFields, List<String> choseJev, List<String> keptGpt, List<String> otherValue, List<String> correctedWithoutDoubt, String subCategory});`
    - `DoubtOutcome? doubtOutcome(ClothingAnalysisResult original, ClothingAnalysisResult saved)` — null se nessun dubbio e nessun campo cambiato. Per ogni campo in `original.doubts` (solo quelli noti a `clothingFieldOfDoubt`): valore finale == originale → `keptGpt`; == `doubtJev[campo]` → `choseJev`; altrimenti `otherValue`. Campi cambiati (da `ClothingDetails.changedFields`) che non sono dubbi → `correctedWithoutDoubt`. Confronto valori: il valore del campo in `ClothingDetails.of(...)`; `activityTags` confrontati come insiemi; colore come in `_colorKey`.
  - `CoreAnalyticsService.trackAiItemsSaved` aggiunge parametri `found, excluded, linked, renamed, detailsEdited, photos, excludedTypes, renamedTypes` (chiavi snake_case: `found`, `excluded`, `linked`, `renamed`, `details_edited`, `photos`, `excluded_types`, `renamed_types`); `count` e `is_onboarding` restano.
  - `CoreAnalyticsService.trackAiScanDoubtResolved({required List<String> doubtFields, required List<String> choseJev, required List<String> keptGpt, required List<String> otherValue, required List<String> correctedWithoutDoubt, required String subCategory})` → `ai_scan_doubt_resolved` con chiavi `doubt_fields`, `chose_jev`, `kept_gpt`, `other_value`, `corrected_without_doubt`, `sub_category`.

Nota sulla spec: `photos` va su `ai_items_saved` (uno per scansione) e non su `ai_input_completed` (che parte una volta per foto).

- [ ] **Step 1: Test che falliscono** in `scan_analytics_test.dart`:
  - stato con 1 gruppo da 4 risultati (Shorts, T-Shirt, Jewelry, Sneakers), escluso l'indice 2, collegato l'indice 3, il risultato 0 rinominato → `found 4, saved 2, excluded 1, linked 1, renamed 1, photos 1, excludedTypes ['Jewelry'], renamedTypes ['Shorts']`;
  - rinomina che cambia solo spazi → `renamed 0`;
  - `doubtOutcome`: originale `warmth 3`, `doubts ['warmth']`, `doubtJev {'warmth': 4}`, salvato `warmth 4` → `choseJev ['warmth']`; salvato `warmth 3` → `keptGpt ['warmth']`; salvato `warmth 5` → `otherValue ['warmth']`; originale senza dubbi e `formality` cambiata → `correctedWithoutDoubt ['formality']`; nulla cambiato e nessun dubbio → `null`;
  - `ClothingAnalysisResult.fromItemMetadata` con `dubbi: [{campo: 'warmth', valore: 3, jev: 4, sicurezza: 0.6}]` → `doubts ['warmth']`, `doubtJev {'warmth': 4}`, e `toJson()` senza chiave `doubtJev`.
- [ ] **Step 2:** `flutter test test/features/ai_input/helpers/scan_analytics_test.dart` → FAIL.
- [ ] **Step 3:** Implementare; in `ai_import_notifier.dart` calcolare `scanSaveStats` **prima** di svuotare lo stato, passare tutto a `trackAiItemsSaved`; `_trackScanEdits` resta per `item_details_edited` e in più chiama `trackAiScanDoubtResolved` per ogni capo salvato con `doubtOutcome != null`.
- [ ] **Step 4:** `flutter test test/features/ai_input` → PASS (adeguare in `ai_import_notifier_test.dart` le `verify` su `trackAiItemsSaved` con i nuovi parametri e aggiungere: salvataggio con un capo escluso → `excluded: 1`).
- [ ] **Step 5: Commit** `feat(analytics): qualità dello scan e verifica dei dubbi di Jev`

---

### Task 4: Contesto del viaggio e `trip_created` arricchito

**Files:**
- Create: `lib/features/trips/services/suitcase_analytics.dart`
- Modify: `lib/features/trips/providers/trip_provider.dart:88-94`
- Modify: `lib/core/analytics/core_analytics_service.dart`
- Test: `test/features/trips/services/suitcase_analytics_test.dart`

**Interfaces:**
- Produces (in `suitcase_analytics.dart`):
  - `String tempBand(double celsius)`: `<5` → `'lt5'`, `[5,15)` → `'5_15'`, `[15,21)` → `'15_21'`, `[21,26)` → `'21_26'`, `>=26` → `'gte26'`.
  - `Map<String, Object> tripContext(TripModel trip, {LuggageModel? luggage, TripWeather? weather})` con chiavi:
    - `activities`: id unici di `trip.aiSetup.stops.values.expand(activities)`, ordinati;
    - `stays`: `stay` non null delle tappe, unici, ordinati;
    - `washer`: `true` se almeno una tappa ha `washer`;
    - `luggage_size`: `luggage.sizeType.name` (assente se `luggage` null);
    - `transports`: `trip.transports`;
    - se `weather` ha almeno una tappa con `tempMax`: `temp_max_band` = `tempBand` del massimo dei `tempMax`; idem `temp_min_band` col minimo dei `tempMin`; `rain_days` = somma dei `rainDays` non null (assente se tutti null); `weather_source` = `weather.source?.name ?? 'mixed'`.
  - `int? daysToDeparture(DateTime? departure, DateTime now)`: giorni di calendario, null se `departure` null, negativo ammesso.
  - `CoreAnalyticsService.trackTripCreated` aggiunge `int? daysToDeparture` → chiavi `trip_number` (= `totalTrips`) e `days_to_departure` (assente se null). `is_first_trip` resta.

- [ ] **Step 1: Test che falliscono:**
  - `tempBand(4.9) == 'lt5'`, `tempBand(21) == '21_26'`, `tempBand(20.9) == '15_21'`, `tempBand(26) == 'gte26'`;
  - viaggio con due tappe (attività `['hiking','beach']` + `['beach']`, alloggi `'apartment'` e `null`, lavatrice false/true), meteo con `tempMax` 23 e 19, `tempMin` 12 e 8, `rainDays` 2 e null, fonte forecast → `activities ['beach','hiking']`, `stays ['apartment']`, `washer true`, `temp_max_band '21_26'`, `temp_min_band '5_15'`, `rain_days 2`, `weather_source 'forecast'`;
  - **(Review Focus 4)** stesso viaggio con `weather: null` → nessuna chiave che inizia per `temp_`, nessuna `rain_days`/`weather_source`;
  - `trackTripCreated(tripId: 't', totalTrips: 3, daysToDeparture: 10)` → `{'trip_id': 't', 'is_first_trip': false, 'trip_number': 3, 'days_to_departure': 10}`.
- [ ] **Step 2:** `flutter test test/features/trips/services/suitcase_analytics_test.dart` → FAIL.
- [ ] **Step 3:** Implementare; in `addTrip` passare `daysToDeparture(model.departureDateTime, DateTime.now())`.
- [ ] **Step 4:** test → PASS.
- [ ] **Step 5: Commit** `feat(analytics): contesto del viaggio e numero d'ordine del viaggio`

---

### Task 5: Valigia — `ai_suitcase_changed`, `ai_warning_dismissed`, `ai_slot_removed`

**Files:**
- Modify: `lib/features/trips/services/suitcase_analytics.dart`
- Modify: `lib/features/trips/providers/trip_provider.dart` (dopo ogni scrittura: `updateTrip`, `toggleItemCheck`, `updateAiSlot`, `fillAiSlot`, `addItemsToTrip`)
- Modify: `lib/core/analytics/core_analytics_service.dart`
- Test: `test/features/trips/services/suitcase_analytics_test.dart`, `test/features/trips/providers/trip_provider_test.dart`

**Interfaces:**
- Consumes: `tripContext`, Task 4.
- Produces:
  - `typedef SuitcaseDiff = ({int proposed, int kept, int removed, int added, int slotCopiesFilled, int quantityChanged, List<String> removedTypes, List<String> addedTypes, List<String> quantityUpTypes, List<String> quantityDownTypes});`
  - `SuitcaseDiff? suitcaseDiff(TripModel trip, Map<String, String> subCategoryById)` — null se `trip.aiResult == null`. Proposta = `proposal` (id → quantity) ∪ `kitAdded` (id, quantità 1 se non già in `proposal`). `kept` = proposti ancora fra `trip.items`; `removed` = proposti assenti; `added` = `trip.items` non proposti; `slotCopiesFilled` = Σ `(copies - remaining)` dei posti non `removed`; `quantityChanged` = tenuti con quantità diversa; liste = `subCategoryById[id] ?? category.name`, ordinate.
  - `Map<String, String> subCategoryByIdOf(List<ItemModel> items)` — da `ai_metadata` (`subCategory`, se testo non vuoto e non `N/A`).
  - `CoreAnalyticsService.trackAiSuitcaseChanged({required String tripId, required Map<String, Object> counts, required Map<String, Object> context})` → `ai_suitcase_changed` con chiavi `trip_id`, `proposed`, `kept`, `removed`, `added`, `added_from_slots` (= `slotCopiesFilled`), `quantity_changed`, `removed_types`, `added_types`, `quantity_up_types`, `quantity_down_types`, più tutte le chiavi di `tripContext`. La conversione record → mappa piatta sta in `suitcase_analytics.dart` (`Map<String, Object> suitcaseDiffProperties(SuitcaseDiff d)`), così il core non conosce il record.
  - `trackAiWarningDismissed({required String code, required String level})`, `trackAiSlotRemoved({required String type, required String level})`.
  - In `TripNotifier`: `void _emitSuitcaseEvents(TripModel? before, TripModel after)`, chiamato dopo ogni scrittura riuscita:
    - `ai_suitcase_changed` se `suitcaseDiff(after)` ≠ null e, quando `before?.aiResult?.generatedAt == after.aiResult.generatedAt`, differisce da `suitcaseDiff(before)` (confronto dei record). Con `generatedAt` diverso o `before` null **non** emette: è la proposta appena salvata, non una modifica dell'utente.
    - un `ai_warning_dismissed` per ogni id nuovo in `after.aiResult.dismissedWarnings` (stesso `generatedAt`), con `code` e `level.name` dell'avviso;
    - un `ai_slot_removed` per ogni posto passato da `removed == false` a `true`, con `type` e `level.name`.
    - `subCategoryById` da `ref.read(itemNotifierProvider(after.aiResult!.houseId)).valueOrNull ?? []`; contesto da `tripContext(after, luggage: <primo bagaglio del viaggio con id == aiSetup.luggageId, se c'è>, weather: <TripWeatherReady.weather di tripWeatherNotifierProvider(after.id) se già caricato, senza avviarlo>)`.

- [ ] **Step 1: Test che falliscono** (`suitcase_analytics_test.dart`):
  - proposta A×2, B×1, C×1 (C da `kitAdded`); valigia A×3, C×1, D×1; un posto `copies 2 remaining 1`; sottocategorie A=`T-Shirt`, B=`Sweater`, D=`Shorts` → `proposed 3, kept 2, removed 1, added 1, slotCopiesFilled 1, quantityChanged 1, removedTypes ['Sweater'], addedTypes ['Shorts'], quantityUpTypes ['T-Shirt'], quantityDownTypes []`;
  - **(Review Focus 1)** viaggio con `aiResult: null` → `null`;
  - **(Review Focus 5)** `subCategoryById` vuoto → stessi conteggi, liste coi nomi di categoria (`'vestiti'`).
- [ ] **Step 2: Test che falliscono** (`trip_provider_test.dart`, con `coreAnalyticsServiceProvider` mockato):
  - `updateTrip` che toglie B → `trackAiSuitcaseChanged` chiamato una volta con `removed: 1`;
  - **(Review Focus 2)** `toggleItemCheck` sullo stesso viaggio → `verifyNever(trackAiSuitcaseChanged)`;
  - **(Review Focus 3)** `updateTrip` con un nuovo `aiResult` (altro `generatedAt`) → `verifyNever(trackAiSuitcaseChanged)`; la modifica successiva confronta con la nuova proposta;
  - `updateTrip` che aggiunge un id a `dismissedWarnings` → `trackAiWarningDismissed(code: ..., level: ...)` una volta;
  - `updateAiSlot` che mette `removed: true` → `trackAiSlotRemoved` una volta.
- [ ] **Step 3:** `flutter test test/features/trips` → FAIL.
- [ ] **Step 4:** Implementare.
- [ ] **Step 5:** `flutter test test/features/trips` → PASS.
- [ ] **Step 6: Commit** `feat(analytics): quanto la valigia si allontana dalla proposta, avvisi e posti scartati`

---

### Task 6: Valigia — `ai_suitcase_finished` e `ai_item_reason_opened`

**Files:**
- Modify: `lib/features/trips/model/pack_trip_job.dart` (campi `bool isRegeneration`, `List<String> setupChanged`, default `false` / `const []`)
- Modify: `lib/features/trips/view/pack_suitcase_screen.dart:439-490` (`_prepareAi`: calcolare i due campi **prima** di sovrascrivere `aiSetup`)
- Modify: `lib/features/trips/view/ai_packing_wait_screen.dart` (`_generate`, `_cancel`)
- Modify: `lib/features/trips/services/suitcase_analytics.dart`
- Modify: `lib/features/trips/view/widgets/ai/ai_pack_item_sheet.dart` (`showAiPackItemSheet`: parametro `String? subCategory`), chiamanti `pack_suitcase_screen.dart:295`, `trip_detail_screen.dart:237`
- Modify: `lib/core/analytics/core_analytics_service.dart`
- Test: `test/features/trips/services/suitcase_analytics_test.dart`

**Interfaces:**
- Consumes: `tripContext`, `daysToDeparture` (Task 4); `trackAiLimitReached` (Task 2); `subCategoryByIdOf` (Task 5).
- Produces (in `suitcase_analytics.dart`):
  - `String packOutcomeOf(Object? failure, {required bool cancelled})`: `cancelled` → `'cancelled'`; null → `'ok'`; `PackTripCreditsException` → `'credits'`; `PackTripEmptyWardrobeException` → `'empty_wardrobe'`; `PackTripWardrobeTooLargeException` → `'wardrobe_too_large'`; `PackTripNetworkException` → `'network'`; altro → `'error'`.
  - `Map<String, Object> wardrobeStats(List<ItemModel> items)`: `wardrobe_items` (tutti), `wardrobe_with_metadata` (`aiMetadata` non vuoto), e per `ai_metadata.category`: `Upper Body`→`wardrobe_upper`, `Lower Body`→`wardrobe_lower`, `Full Body`→`wardrobe_full_body`, `Outerwear`→`wardrobe_outerwear`, `Shoes`→`wardrobe_shoes`, `Accessory`→`wardrobe_accessory`, `Essentials`→`wardrobe_essentials`, tutto il resto (anche senza metadati)→`wardrobe_other`. Tutte le chiavi sempre presenti (0 se nessuno).
  - `List<String> setupChangedFields(AiPackingSetup? before, AiPackingSetup after)`: sottoinsieme ordinato di `activities`, `stays`, `washer`, `luggage` (confrontando le unioni come in `tripContext` e `luggageId`); `[]` se `before` null.
  - `CoreAnalyticsService.trackAiSuitcaseFinished({required String outcome, required int durationMs, required String tripId, required Map<String, Object> properties})` → `ai_suitcase_finished` con `outcome`, `duration_ms`, `trip_id` e le chiavi di `properties` (`nights`, `stops`, `is_regeneration`, `days_to_departure`, `setup_changed`, `proposal_items`, `slots_count` solo se `ok`, statistiche dell'armadio, contesto del viaggio).
  - `CoreAnalyticsService.trackAiItemReasonOpened({required String reasonCode, required String subCategory})`.

Regole:
- `ai_suitcase_finished` parte **una volta per tentativo**: alla fine di `_generate` (riuscita o errore) e in `_cancel` se la richiesta era in corso (`_result == null && _failure == null`). `durationMs` dal `Stopwatch` già presente; per l'annullamento serve tenerlo come campo dello state.
- Con `outcome == 'credits'` chiamare anche `trackAiLimitReached(feature: 'suitcase')`.
- Armadio: `ref.read(itemNotifierProvider(widget.job.houseId)).valueOrNull ?? []`. Viaggio: da `tripNotifierProvider` con `widget.tripId`. Meteo: come in Task 5, senza avviare richieste. `stops` = numero di tappe di `aiSetup.stops`.
- `ai_item_reason_opened` parte dentro `showAiPackItemSheet` solo se `reason != null`, con `subCategory ?? item.category.name`. I chiamanti passano `subCategory` da `subCategoryByIdOf([inventoryItem])`.

- [ ] **Step 1: Test che falliscono:**
  - `packOutcomeOf(const PackTripCreditsException(), cancelled: false) == 'credits'`; `packOutcomeOf(null, cancelled: true) == 'cancelled'`; `packOutcomeOf(const PackTripException('x'), cancelled: false) == 'error'`; `packOutcomeOf(PackTripNetworkException('rete'), cancelled: false) == 'network'`;
  - `wardrobeStats` con 3 capi (Upper Body con metadati, Shoes con metadati, uno senza metadati) → `wardrobe_items 3, wardrobe_with_metadata 2, wardrobe_upper 1, wardrobe_shoes 1, wardrobe_other 1, wardrobe_lower 0`;
  - `setupChangedFields` con lavatrice cambiata e attività identiche in ordine diverso → `['washer']`; con `before` null → `[]`.
- [ ] **Step 2:** `flutter test test/features/trips/services/suitcase_analytics_test.dart` → FAIL.
- [ ] **Step 3:** Implementare funzioni pure, `PackTripJob`, `_prepareAi`, wait screen, foglio del capo.
- [ ] **Step 4:** `flutter test` (tutta la suite) → PASS; `flutter analyze` pulito.
- [ ] **Step 5: Commit** `feat(analytics): esito, durata e contesto di ogni generazione della valigia`

---

### Task 7: Verifica finale e documento

**Files:**
- Modify: `docs/superpowers/analytics-domande.md` (aggiungere sotto "Catalogo degli eventi" la nota: `photos` su `ai_items_saved`; `added_from_slots` = copie riempite dai posti; nessun evento su toggle/spunta; prima proposta salvata non conta come modifica)

- [ ] **Step 1:** `flutter analyze` → `No issues found!`
- [ ] **Step 2:** `flutter test` → tutti i test passano (confrontare col numero di partenza della suite su develop).
- [ ] **Step 3:** Controllo dei nomi: `grep -oE "_safeLogEvent\(\s*'[a-z_]+'" -r lib/core/analytics | sort` e confronto a mano con la sezione "Catalogo degli eventi"; ogni nome del catalogo compare, nessun nome in più a parte `screen_view`/pageview.
- [ ] **Step 4:** Controllo privacy: `grep -n "name\b\|\.name)" lib/core/analytics/core_analytics_service.dart` e lettura dei chiamanti nuovi: nessuna proprietà riceve `item.name`, `trip.name`, `house.name`, nomi di tappa o il codice promo.
- [ ] **Step 5: Commit** `docs: note di implementazione del catalogo eventi`
- [ ] **Step 6:** Ricordare a Davide: (a) gli avvisi Telegram da impostare a mano (sezione "Avvisi su Telegram"); (b) il ramo è locale, push e PR solo su sua richiesta; (c) prova reale solo da build prod o dev con tgram inizializzato (in dev `TGA.init` non parte).

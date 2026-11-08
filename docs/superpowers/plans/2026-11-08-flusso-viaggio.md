# Flusso di creazione del viaggio — piano di lavoro

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** passo 1 con due strade, valigia AI salvata solo all'arrivo e in background, dettaglio come unica pagina della valigia, Rigenera e avviso dopo modifica senza passare dalla pagina a mano.

**Architecture:** un lavoro AI unico per l'app vive in un provider `keepAlive` (`AiPackingRun`) che possiede richiesta, esito e salvataggio; la pagina d'attesa e un ascoltatore globale lo osservano. Un "lanciatore" condiviso (`startAiPacking`) apre il foglio da passo 1, Rigenera e avviso. Il dettaglio usa una sola lista modificabile per tutte le valigie; `pack_suitcase_screen.dart` diventa la pagina di aggiunta.

**Tech Stack:** Flutter 3.38.5, Riverpod (generator), Freezed, Drift, go_router, easy_localization.

**Spec:** `docs/superpowers/specs/2026-11-08-flusso-viaggio-design.md` (ramo WIP `wip/stato-3-novembre`). Prova visiva: ramo locale `spike/flusso-viaggio`, worktree `/srv/claude/workspaces/PackLog-spike-flusso` (solo da guardare).

**Tre PR, tre rami, in ordine:** Parte A `feat/flusso-a-passo1-ai` da `origin/develop`; Parte B `feat/flusso-b-dettaglio-valigia` da A; Parte C `feat/flusso-c-rigenera` da B. Worktree `/srv/claude/workspaces/PackLog-flusso-nuovo`. PR verso `develop`, B e C impilate (base = ramo precedente) finché A non è unita.

## Global Constraints

- Solo componenti DS (`lib/shared/widgets/ds_*`), token del tema, `AppMotion`/`AppOpacity`; nessun widget Material diretto nuovo. Widget piccoli a una responsabilità.
- Ogni stringa nuova in `assets/translations/it-IT.json` **e** `en-US.json`.
- Prima di build_runner/test: `source /srv/claude/workspaces/.strumenti/flutter338.sh`, poi `dart run build_runner build --delete-conflicting-outputs`. Non committare `analysis_options.yaml`/`pubspec.lock` se cambiati dall'ambiente.
- Git: mai `--no-verify`, mai `-c core.hooksPath=...` o altri modi di saltare gli hook, mai force push, mai commit su `main`. Push dei rami di lavoro ammesso.
- Il server non cambia: `pack-trip` consuma il credito all'inizio e lo restituisce se fallisce. L'app non tocca i crediti.
- Il viaggio si scrive con `tripNotifierProvider.notifier.addTrip` (atomico: viaggio, oggetti, bagagli) o `updateTrip`; mai `addTrip` seguito da `updateTrip` per lo stesso salvataggio.
- Ogni componente rimasto senza uso si cancella; elencarlo nel testo della PR.
- Il ramo `feat/modifiche-valigia` (eventi delle modifiche alla proposta) non è in develop: non portarlo dentro. Chi lo integra dopo deve far sì che il salvataggio di `AiPackingRun` conti come prima adozione della proposta (nessun evento).
- Test di riferimento: `flutter analyze` pulito; `flutter test test/features/trips test/core` verde a fine di ogni task.

## Review Focus

1. La valigia arriva mentre l'utente è in un altro passo 1 o in un foglio aperto: compare solo lo snackbar, nessuna navigazione forzata. → test in Task A4.
2. Rigenera in background mentre l'utente spunta oggetti della vecchia valigia: all'arrivo la valigia nuova si applica al viaggio letto in quel momento dal provider. → test in Task A1.
3. Viaggio cancellato durante una Rigenera: risultato scartato, nessun viaggio ricreato. → test in Task A1.
4. Indietro premuto durante l'animazione d'arrivo: una sola navigazione. → test in Task A3.
5. Oggetti della casa non leggibili all'arrivo: viaggio salvato lo stesso con la proposta, snackbar `trips.pack.ai.items_error`. → test in Task A1.

---

## Parte A — passo 1, strada AI, attesa

### Task A1: lavoro AI e salvataggio della valigia fuori dalle pagine

**Files:**
- Create: `lib/features/trips/model/ai_packing_request.dart`, `lib/features/trips/services/ai_suitcase_adoption.dart`, `lib/features/trips/providers/ai_packing_run_provider.dart`
- Modify: `lib/features/trips/view/pack_suitcase_screen.dart` (spostare fuori `_proposedItems`, `_joinStops`, `_logFirstSuitcase`, `_logKitAutoAdded`, la costante `_firstSuitcaseLoggedKey`)
- Test: `test/features/trips/services/ai_suitcase_adoption_test.dart`, `test/features/trips/providers/ai_packing_run_provider_test.dart`

**Interfaces:**
- Produces:
  - `class AiPackingRequest { final TripModel trip; final bool isNew; final AiPackingSetup setup; final PackTripJob job; final LuggageModel? luggage; }` (immutabile, `const`).
  - `TripModel adoptedTrip({required TripModel trip, required AiPackingResult proposal, required AiPackingSetup setup, LuggageModel? luggage, List<ItemModel>? houseItems})` — funzione pura: applica `carryKitCounted(trip.aiResult, carryToBuy(trip.aiResult, proposal))`, oggetti proposti da `houseItems` (con `houseItems == null` tiene gli oggetti e i bagagli del viaggio), bagaglio scelto, `aiSetup`, `aiResult`, `updatedAt`.
  - `String joinStopNames(List<String> names)` (ex `_joinStops`).
  - `sealed class AiPackingRunState`: `AiRunIdle()`, `AiRunRunning(AiPackingRequest request)`, `AiRunFailed(AiPackingRequest request, Object error)`, `AiRunDone(String tripId, {required bool itemsError})`.
  - `@Riverpod(keepAlive: true) class AiPackingRun` → `aiPackingRunProvider`, con: `bool start(AiPackingRequest request)` (false se c'è già `AiRunRunning`), `Future<void> retry()` (solo da `AiRunFailed`), `void clear()` (torna `AiRunIdle`), `bool get attached`, `void attach()`, `void detach()`.

- [ ] **Step 1: test di `adoptedTrip`**: `adopts_proposal_items_and_luggage` (oggetti = proposta, bagagli = `{luggage}`, `aiSetup`/`aiResult` impostati), `keeps_trip_items_when_house_items_missing` (`houseItems: null` → oggetti e bagagli invariati, `aiResult` impostato), `carries_to_buy_and_kit_counted_from_previous_result`.
- [ ] **Step 2: test del provider** (con `PackTripService` finto e `ProviderContainer`):
  - `start_returns_false_while_running`;
  - `new_trip_is_added_only_on_success`: con `isNew: true` nessun `addTrip` prima della risposta; dopo, un solo `addTrip` con oggetti e `aiResult`; stato `AiRunDone`;
  - `failure_saves_nothing`: errore → nessuna scrittura, stato `AiRunFailed`;
  - `regenerate_applies_to_current_trip` (Review Focus 2): il viaggio nel provider cambia durante la richiesta → `updateTrip` riceve il viaggio corrente con la valigia nuova;
  - `regenerate_on_deleted_trip_is_discarded` (Review Focus 3): viaggio assente all'arrivo → nessuna scrittura, stato `AiRunIdle`;
  - `items_unreadable_still_saves` (Review Focus 5): lettura oggetti della casa che fallisce → salvataggio con `itemsError: true`;
  - `first_trip_and_events_on_success`: `completeFirstTrip()` chiamato, `first_suitcase_generated` una volta sola per dispositivo.
- [ ] **Step 3:** eseguire i test: falliscono (simboli mancanti).
- [ ] **Step 4:** implementare. Il provider chiama `PackTripService.generate(request.job.body, houseId: request.job.houseId)`, poi `ref.invalidate(gptUsageProvider)`, registra `PackTripTiming`, segnala a `monitoringServiceProvider` solo i `PackTripException` che non sono `PackTripNetworkException` (come oggi nell'attesa), legge `itemNotifierProvider(result.houseId).future`, costruisce con `adoptedTrip`, scrive (`isNew` → `addTrip`, altrimenti `updateTrip` sul viaggio letto ora da `tripNotifierProvider`), poi `completeFirstTrip`, `first_suitcase_generated`, kit aggiunti. `pack_suitcase_screen.dart` usa le funzioni spostate (comportamento invariato in questo task).
- [ ] **Step 5:** test verdi, `flutter analyze` pulito.
- [ ] **Step 6:** commit `feat(trips): lavoro AI fuori dalle pagine`.

### Task A2: lanciatore condiviso

**Files:**
- Create: `lib/features/trips/services/ai_packing_launcher.dart`
- Modify: `lib/features/trips/view/pack_suitcase_screen.dart` (`_onAiTap`/`_prepareAi`/`_adoptResult` sostituiti dal lanciatore), `lib/core/routing/app_router.dart`
- Test: `test/features/trips/services/ai_packing_launcher_test.dart`, aggiornare `test/features/trips/view/pack_suitcase_ai_flow_test.dart`

**Interfaces:**
- Consumes: `AiPackingRequest`, `aiPackingRunProvider`, `joinStopNames` (A1).
- Produces: `Future<AiPackingSetup?> startAiPacking(BuildContext context, WidgetRef ref, {required TripModel trip, required bool isNew})`. Ritorna le risposte del foglio se il lavoro è partito, `null` altrimenti. Rotta nuova `/ai-packing` (senza id) che sostituisce `/trips/:id/ai-packing`.

- [ ] **Step 1: test**: `busy_shows_snackbar_and_no_sheet` (lavoro in corso → snackbar `trips.ai.busy`, foglio non aperto, ritorna null); `unavailable_shows_reason` (`AiUnavailable` → `AppSnackBar.showInfo(messageKey)`); `existing_items_ask_confirmation_only_when_not_new`; `sheet_closed_starts_nothing`; `confirmed_starts_run_and_opens_wait` (stato `AiRunRunning`, rotta `/ai-packing`).
- [ ] **Step 2:** test rossi.
- [ ] **Step 3:** implementare: `aiAvailabilityOf(trip, houses:, today:)`, conferma `trips.pack.ai.replace_*` se `!isNew && trip.items.isNotEmpty`, `showAiPackingSheet(context, trip: trip, plan: plan)`, kit (`kitNotifierProvider(houseId).future`, vuoto se errore), `packTripBody(...)` come oggi, `PackTripJob`, `start`, `context.push('/ai-packing')`. Le risposte (`aiSetup`) non si scrivono subito, né per un viaggio nuovo né per Rigenera: si salvano con la valigia all'arrivo (`adoptedTrip`); se la richiesta fallisce resta l'`aiSetup` di prima (spec, Parte C). Stringa: `trips.ai.busy` it "Sto già preparando una valigia: ti avviso quando è pronta." en "I'm already packing a suitcase: I'll let you know when it's ready."
- [ ] **Step 4:** test verdi (anche quelli della pagina valigia aggiornati).
- [ ] **Step 5:** commit `feat(trips): lanciatore condiviso della valigia AI`.

### Task A3: attesa senza Annulla, in background

**Files:**
- Modify: `lib/features/trips/view/ai_packing_wait_screen.dart`, `lib/features/trips/view/widgets/wait/ai_wait_body.dart`, `lib/features/trips/view/widgets/wait/ai_wait_failure.dart` (solo i collegamenti)
- Test: `test/features/trips/view/ai_packing_wait_screen_test.dart`

**Interfaces:**
- Consumes: `aiPackingRunProvider` (A1).
- Produces: `AiPackingWaitScreen()` senza parametri; legge la richiesta dallo stato.

- [ ] **Step 1: test**: `no_cancel_button`; `shows_stay_line` (testo `trips.ai.wait.stay`); `back_detaches_and_keeps_running` (indietro → `detach()`, stato ancora `AiRunRunning`); `arrival_while_attached_opens_review` (→ `/trips/<id>?review=1` con `context.go`); `back_during_handoff_navigates_once` (Review Focus 4); `failure_retry_and_close` (Riprova → `retry()`, Chiudi → `clear()` e pop).
- [ ] **Step 2:** test rossi.
- [ ] **Step 3:** implementare: `attach()` in `initState`, `detach()` in uscita; niente `PackTripService` nella pagina; passi e `WaitHandoff` come oggi. In `AiWaitBody` via `onCancel`/`canCancel` e il bottone; sotto "Di solito ci vogliono una decina di secondi." la riga `bodySmall`, `onSurfaceVariant`: `trips.ai.wait.stay` it "Resta qui mentre prepariamo la valigia: non chiudere PackLog e non aprire altre app." en "Stay here while we pack your suitcase: don't close PackLog or open other apps."
- [ ] **Step 4:** test verdi.
- [ ] **Step 5:** commit `feat(trips): attesa senza Annulla, continua in background`.

### Task A4: avviso globale all'arrivo

**Files:**
- Create: `lib/features/trips/view/widgets/wait/ai_packing_run_listener.dart`, `lib/features/trips/services/ai_failure_message.dart`
- Modify: `lib/bootstrap.dart` (avvolgere il figlio del `MaterialApp.router` nel suo `builder:`)
- Test: `test/features/trips/view/widgets/wait/ai_packing_run_listener_test.dart`

**Interfaces:**
- Produces: `class AiPackingRunListener extends ConsumerWidget { final Widget child; }`; `String aiFailureMessageKey(Object error)`.

- [ ] **Step 1: test**: `done_while_detached_shows_open_snackbar` (`AppSnackBar.showAction`, testo `trips.ai.ready` con il titolo del lavoro, azione `trips.ai.open` → `/trips/<id>?review=1`, poi `clear()`); `done_while_attached_shows_nothing`; `failure_while_detached_shows_error` (poi `clear()`); `server_error_says_no_credit` / `network_error_is_generic` per `aiFailureMessageKey`; `arrival_during_other_new_trip_does_not_navigate` (Review Focus 1).
- [ ] **Step 2:** test rossi.
- [ ] **Step 3:** implementare con `ref.listen(aiPackingRunProvider, ...)`; lo snackbar va sul `ScaffoldMessenger` della radice; `itemsError: true` → anche `trips.pack.ai.items_error`. Stringhe:
  - `trips.ai.ready` it "Valigia pronta per {}" en "Suitcase ready for {}"; `trips.ai.open` it "Apri" en "Open";
  - `trips.ai.failed_no_credit` it "Non sono riuscito a preparare la valigia. Nessun credito è stato scalato." en "I couldn't pack the suitcase. No credit was used.";
  - `trips.ai.failed_network` it "Non sono riuscito a preparare la valigia. Controlla la connessione e riprova." en "I couldn't pack the suitcase. Check your connection and try again."
  `aiFailureMessageKey`: `PackTripNetworkException` → `failed_network`; tutto il resto → `failed_no_credit`. La pagina d'errore dell'attesa (`AiWaitFailure`) usa la stessa regola dove parla di crediti.
- [ ] **Step 4:** test verdi.
- [ ] **Step 5:** commit `feat(trips): avviso globale della valigia pronta`.

### Task A5: passo 1 con due bottoni

**Files:**
- Modify: `lib/features/trips/view/new_trip_screen.dart`, `assets/translations/*.json`
- Test: `test/features/trips/view/new_trip_screen_test.dart`

**Interfaces:**
- Consumes: `startAiPacking` (A2).

- [ ] **Step 1: test**: `two_buttons_only` (chiavi `new_trip_prepare_ai` e `new_trip_choose_items`; assenti `new_trip_next`, `new_trip_later`, `new_trip_manual`) in creazione normale e con `aiIntent: true`; `edit_shows_save_only`; `ai_does_not_save_trip` (dopo il tocco nessun viaggio nel provider, `startAiPacking` chiamato con `isNew: true` e un `TripModel` da `_draft.toTripModel`); `sheet_closed_keeps_step_filled`; `setup_kept_on_reopen` (le risposte ritornate da `startAiPacking` finiscono in `aiSetup` del viaggio passato alla volta dopo); `choose_items_saves_and_opens_pack` (`/trips/<id>/edit-items?from=new`); `disabled_tap_shows_missing`.
- [ ] **Step 2:** test rossi.
- [ ] **Step 3:** implementare: `_buildBottomBar` con due rami (creazione/riuso, modifica); un id del viaggio generato una volta per pagina e riusato fra i tentativi; via `_onLater`, `_onPackMyself`, il ramo `aiIntent` e `_newTripCtaHeight` per tre righe. Bottone secondario `DsButtonVariant.secondary`. Stringhe: `trips.new.prepare_with_ai` → it "Prepara la valigia con AI" en "Pack with AI"; nuova `trips.new.choose_items` it "Scegli tu cosa portare" en "Choose what to bring"; cancellare le chiavi rimaste senza uso.
- [ ] **Step 4:** test verdi.
- [ ] **Step 5:** commit `feat(trips): passo 1 con due strade`.

### Task A6: Riusa come passo 1 precompilato

**Files:**
- Modify: `lib/features/trips/model/trip_draft.dart`, `lib/features/trips/view/new_trip_screen.dart`, `lib/features/trips/view/trips_screen.dart` (`_handleReuse`), `lib/core/routing/app_router.dart`, repository/DAO/provider di `reuseTrip`
- Test: riscrivere `test/features/trips/view/edit_trip_reuse_test.dart`; `test/features/trips/model/trip_draft_test.dart`

**Interfaces:**
- Produces: `factory TripDraft.reuseOf(TripModel trip, {String? houseName})` (meta, tappe senza date, mezzi, nome; niente date); `NewTripScreen({String? reuseFromId, ...})`; rotta `/new-trip?reuseFrom=<id>`.

- [ ] **Step 1: test**: `reuse_opens_prefilled_step_without_saving` (nessun viaggio nuovo nel provider all'apertura né all'uscita); `reuse_has_two_buttons`; `reuse_choose_items_saves_copy_with_unchecked_items_and_luggages`; `reuse_ai_starts_new_trip_without_items` (`isNew: true`, `items` vuoti: la valigia AI sostituisce); `trip_draft_reuse_of_drops_dates`.
- [ ] **Step 2:** test rossi.
- [ ] **Step 3:** implementare. Gli oggetti e i bagagli dell'originale restano in memoria nella pagina e si scrivono con `addTrip` solo con "Scegli tu cosa portare" (`isChecked: false`). Cancellare `discardOnExit`, `_onClosed`, `_isReuse` legato alla copia, `?reuse=1`, `reuseTrip` di provider/repository/DAO e `_TripCopyMode.reuse` se restano senza uso. Il bottone "Riusa" resta solo nella cartolina dei viaggi passati (`trip_album.dart`). "Duplica" invariato.
- [ ] **Step 4:** test verdi; `flutter test` completo verde.
- [ ] **Step 5:** commit `feat(trips): Riusa come passo 1 precompilato`.

### Task A7: screenshot e PR della Parte A

- [ ] **Step 1:** aggiornare gli scenari di `test/screenshots/ui_screenshots_test.dart` e `store_screenshots_test.dart` toccati (passo 1, attesa, Riusa); eseguire `flutter test test/screenshots --dart-define=UI_SCREENSHOTS=true --dart-define=UI_THEMES=light` e controllare a occhio passo 1 e attesa.
- [ ] **Step 2:** `flutter analyze`, `flutter test` completo verdi.
- [ ] **Step 3:** commit, push del ramo, testo della PR in scratchpad (cosa cambia, componenti cancellati, nessun deploy né migrazione).

---

## Parte B — il dettaglio è la valigia

### Task B1: una lista degli oggetti, modificabile, per tutte le valigie

**Files:**
- Modify: `lib/features/trips/view/widgets/slots/trip_items_card.dart`, `lib/features/trips/view/trip_detail_screen.dart`
- Delete: `PlainItemsSection` (in `trip_items_card.dart`), `lib/features/trips/view/widgets/pack/pack_luggages.dart`
- Test: `test/features/trips/view/trip_detail_manual_suitcase_test.dart` (nuovo)

**Interfaces:**
- Produces: `ItemsOnlySection` rinominata `SuitcaseItemsSection`, con `houseId` opzionale (null = valigia senza proposta: niente ricerca della casa proposta).

- [ ] **Step 1: test**: `manual_suitcase_is_editable` (spunta, togli, apri la scheda dell'oggetto, cambi bagagli con `PackLuggageSelector`); `manual_and_ai_use_same_section` (stesso widget `SuitcaseItemsSection` in entrambi); `old_ai_result_without_slots_shows_as_manual`.
- [ ] **Step 2:** test rossi.
- [ ] **Step 3:** implementare riusando le mutazioni del dettaglio (`_removeInventoryItem`, `_toggleInventoryItem`, `_openTripItem`, `_toggleTripLuggage`) anche senza posti. Per la valigia a mano niente posti, "Cosa manca", "Perché queste scelte".
- [ ] **Step 4:** test verdi.
- [ ] **Step 5:** commit `feat(trips): il dettaglio modifica ogni valigia`.

### Task B2: "Aggiungi oggetti" nel dettaglio

**Files:**
- Modify: `lib/features/trips/view/trip_detail_screen.dart`, traduzioni
- Test: `test/features/trips/view/trip_detail_manual_suitcase_test.dart`, `trip_detail_slots_test.dart`

- [ ] **Step 1: test**: `add_items_cta_for_all_suitcases` (chiave `trip_detail_cta`, testo `trips.detail.add_items`, apre `/trips/<id>/edit-items`) per valigia AI dopo la revisione, a mano e vuota (con `EmptySuitcase`); `first_review_keeps_done`.
- [ ] **Step 2:** test rossi.
- [ ] **Step 3:** implementare; `Icons.add`; stringa `trips.detail.add_items` it "Aggiungi oggetti" en "Add items". Cancellare `trips.detail.edit_suitcase` se senza uso.
- [ ] **Step 4:** test verdi.
- [ ] **Step 5:** commit `feat(trips): Aggiungi oggetti dal dettaglio`.

### Task B3: la pagina valigia serve solo ad aggiungere

**Files:**
- Modify: `lib/features/trips/view/pack_suitcase_screen.dart`, `lib/features/trips/view/widgets/pack/pack_parts.dart`, `lib/core/routing/app_router.dart`
- Test: `test/features/trips/view/pack_suitcase_screen_test.dart`; cancellare o riscrivere `pack_suitcase_ai_mode_test.dart` e `pack_suitcase_ai_flow_test.dart`

- [ ] **Step 1: test**: `add_page_has_only_search_and_house_items` (assenti `PackWeatherSection`, `PackLuggageSelector`, `PackSummaryLine`, `AiPackRows`, chiave `pack_ai_suitcase`); `title_from_detail_is_add_to_suitcase` (`trips.pack.add_title`); `title_from_new_trip_has_steps`; `done_from_new_trip_replaces_with_detail` (`pushReplacement('/trips/<id>')`); `done_from_detail_pops`.
- [ ] **Step 2:** test rossi.
- [ ] **Step 3:** implementare. Restano ricerca (`PackInventorySearch`, `PackAddRow`), selettore della casa, oggetti della casa da spuntare (`PackItemRow` senza la modalità `packedOnly`, che si cancella: era la riga della valigia generata), Rapid Fire e kit dove sono oggi. Via ogni codice solo-AI (avvisi, `_aiResult`, `_searchFrom`, `_dismissWarning`). Il parametro `?ai=1` resta finché C3 non lo toglie. Stringa `trips.pack.add_title` it "Aggiungi alla valigia" en "Add to suitcase".
- [ ] **Step 4:** test verdi.
- [ ] **Step 5:** commit `refactor(trips): pagina di aggiunta`.

### Task B4: screenshot e PR della Parte B

- [ ] **Step 1:** scenari di dettaglio e pagina valigia aggiornati; screenshot controllati come in A7.
- [ ] **Step 2:** `flutter analyze`, `flutter test` verdi.
- [ ] **Step 3:** commit, push, testo PR con l'elenco dei componenti cancellati (`PlainItemsSection`, `PackLuggages`, modalità `packedOnly`, codice AI della pagina valigia).

---

## Parte C — Rigenera, avviso dopo modifica, date

### Task C1: la valigia ricorda il viaggio per cui è fatta

**Files:**
- Modify: `lib/features/trips/model/ai_packing.dart`, `lib/features/trips/services/ai_suitcase_adoption.dart`
- Create: `lib/features/trips/services/suitcase_outdated.dart`
- Test: `test/features/trips/services/suitcase_outdated_test.dart`, `ai_suitcase_adoption_test.dart`

**Interfaces:**
- Produces: `@freezed class AiTripShape { DateTime? departure; DateTime? returnAt; List<AiTripShapeStop> stops; List<String> transports; factory AiTripShape.of(TripModel trip); }`, `@freezed class AiTripShapeStop { String name; DateTime? from; DateTime? to; }`; in `AiPackingResult` i campi `AiTripShape? tripShape` e `@Default(false) bool changeNoticeDismissed`; `bool suitcaseOutdated(TripModel trip, {required DateTime now})`.

- [ ] **Step 1: test**: `adopted_trip_stores_shape`; `outdated_when_dates_change` / `_stops_change` / `_transports_change`; `not_outdated_when_only_name_changes`; `not_outdated_without_shape` (valigie vecchie); `not_outdated_when_dismissed`; `not_outdated_after_departure` (usa `TripModel.notDeparted` se presente sul ramo, altrimenti `departureDateTime` contro `now`); `json_round_trip_keeps_shape`.
- [ ] **Step 2:** test rossi.
- [ ] **Step 3:** implementare; `adoptedTrip` imposta `tripShape: AiTripShape.of(trip)` e `changeNoticeDismissed: false`. `aiResult` viaggia come JSON (`ai_packing_result`): nessuna migrazione.
- [ ] **Step 4:** test verdi.
- [ ] **Step 5:** commit `feat(trips): la valigia ricorda il viaggio`.

### Task C2: avviso nel dettaglio e Rigenera senza la pagina valigia

**Files:**
- Create: `lib/features/trips/view/widgets/trip_changed_notice.dart`
- Modify: `lib/features/trips/view/trip_detail_screen.dart`, `lib/features/trips/view/pack_suitcase_screen.dart` (via `?ai=1`), `lib/core/routing/app_router.dart`
- Test: `test/features/trips/view/trip_detail_changed_notice_test.dart`

**Interfaces:**
- Consumes: `suitcaseOutdated` (C1), `startAiPacking` (A2).

- [ ] **Step 1: test**: `notice_shows_when_outdated`; `notice_action_starts_ai_on_detail` (`startAiPacking(isNew: false)`, nessuna navigazione a `edit-items`); `notice_close_persists` (`changeNoticeDismissed: true` scritto con `changeTrip`, avviso assente dopo un nuovo pump); `regenerate_menu_starts_ai_on_detail` (dialogo di conferma, poi foglio sopra il dettaglio).
- [ ] **Step 2:** test rossi.
- [ ] **Step 3:** implementare con un componente DS di avviso già esistente (cercarlo in `lib/shared/widgets`; se non c'è, comporre con `DsCard` e token) sopra la valigia; testi `trips.detail.changed_notice` it "Hai cambiato il viaggio: la valigia potrebbe non andare più bene." en "You changed the trip: the suitcase may no longer fit."; `trips.detail.changed_redo` it "Rifalla con AI" en "Redo with AI". Rigenera e avviso chiamano `startAiPacking(context, ref, trip: trip, isNew: false)`; cancellare `?ai=1` e l'apertura automatica del foglio nella pagina valigia.
- [ ] **Step 4:** test verdi.
- [ ] **Step 5:** commit `feat(trips): avviso dopo modifica e Rigenera dal dettaglio`.

### Task C3: "Quando?" mostra tutto il viaggio

**Files:**
- Modify: `lib/features/trips/view/new_trip_screen.dart` (`_buildWhen`, `_pickDates`), `lib/features/trips/model/trip_draft.dart`
- Test: `test/features/trips/model/trip_draft_test.dart`, `test/features/trips/view/new_trip_screen_test.dart`

**Interfaces:**
- Produces: `TripDraft withTripDates(DateTime departure, DateTime returnDate)` → `TripDraft?` (null se le date tagliano fuori una tappa).

- [ ] **Step 1: test**: `when_shows_whole_trip_with_two_stops` ("mer 18 nov – lun 23 nov", 5 notti); `one_stop_unchanged`; `with_trip_dates_moves_departure_and_last_end`; `with_trip_dates_rejects_cut_stop` (partenza ≥ fine della prima tappa, o ritorno ≤ inizio dell'ultima → null); `cut_stop_shows_snackbar` (`trips.new.dates_cut_stops`).
- [ ] **Step 2:** test rossi.
- [ ] **Step 3:** implementare: con una tappa tutto come oggi (`withFirstDates`); con più tappe il campo mostra partenza → fine dell'ultima tappa, il foglio si apre su quelle date e il risultato passa da `withTripDates`. Stringa `trips.new.dates_cut_stops` it "Queste date tagliano fuori una tappa: cambiala nell'itinerario." en "These dates leave out a stop: change it in the itinerary." Vale in creazione e in modifica (stessa pagina).
- [ ] **Step 4:** test verdi.
- [ ] **Step 5:** commit `feat(trips): date di tutto il viaggio in Quando`.

### Task C4: screenshot e PR della Parte C

- [ ] **Step 1:** scenari: dettaglio con avviso, Modifica viaggio con due tappe; screenshot controllati.
- [ ] **Step 2:** `flutter analyze`, `flutter test` verdi.
- [ ] **Step 3:** commit, push, testo PR. Nessuna migrazione né deploy.

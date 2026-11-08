# Frase rassicurante e modifiche alla valigia — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** una riga che rassicura sotto il titolo della valigia AI, e la registrazione delle modifiche che l'utente fa alla proposta prima di partire, salvate in locale e mandate a Supabase con la sincronizzazione.

**Architecture:** le modifiche non si agganciano a ogni bottone: si ricavano confrontando il viaggio prima e dopo ogni salvataggio in `TripNotifier` (una funzione pura, `modificheValigia`). Gli eventi vanno in una tabella locale "in uscita" (Drift) e `SyncService.processQueue` li inserisce in una tabella Supabase solo in scrittura, poi li cancella in locale. `pack-trip` aggiunge una costante di versione alla risposta, salvata con la proposta.

**Tech Stack:** Flutter 3.38.5, Riverpod, Freezed, Drift; Supabase (Postgres + RLS, Edge Function Deno/TS).

**Spec:** `/srv/claude/workspaces/PackLog-giri-dev/docs/superpowers/specs/2026-11-08-profilo-personale-design.md` (parti 1 e 2; la parte 3 è esclusa).

## Global Constraints

- Testo it-IT: "Con questa valigia hai il necessario per questo viaggio. Se vuoi portare altro, aggiungilo dalla ricerca."
- Testo en-US: "This suitcase has what you need for this trip. If you want to bring more, add it from search."
- Si registra solo: viaggi con `aiResult != null`, prima di `departureDateTime` (ora del telefono). Mai durante il viaggio, mai le spunte (`isChecked`, `checked`).
- Mai il nome scritto dall'utente nell'evento: solo la scheda (`ai_metadata`: category, subCategory, warmth, waterResistance, formality, activityTags) o, per i posti, `type` e `level`.
- `analisi_consentita` = `ConsentService.analyticsEnabled` nel momento dell'evento; non si aggiorna dopo.
- UI: solo componenti del DS, token del tema, stringhe it/en (test di parità). Widget piccoli a una responsabilità.
- Migrazioni Supabase e deploy li fa Davide: il piano scrive i file, non li applica.
- Regole d'ambiente: `/tmp/claude-1001/-srv-claude-workspaces-PackLog/a389a2f8-d273-43c6-b669-b6e7c79291e2/scratchpad/ds-piani/ambiente.md`. Mai push forzati; commit con le righe di attribuzione della sessione.

## Review Focus

1. Rigenerare la valigia (nuovo `aiResult.generatedAt`) non deve produrre "tolto" per tutta la proposta vecchia e "aggiunto" per la nuova: è una proposta nuova, non una modifica.
2. Il primo salvataggio che adotta la proposta (viaggio senza `aiResult` → con `aiResult`) non produce eventi.
3. Rete assente: gli eventi restano in locale e partono al primo sync, una volta sola (nessun doppione se il sync si interrompe a metà: id evento generato in locale + insert idempotente).
4. Eliminazione dell'account: la coda locale si svuota con `wipeAllUserData`.
5. Un oggetto senza `ai_metadata` (oggetti non vestiti, armadi vecchi): evento con scheda vuota, nessun errore.

---

### Task 1: La frase rassicurante

**Files:**
- Create: `lib/features/trips/view/widgets/ai/ai_pack_reassurance.dart`
- Modify: `lib/features/trips/view/pack_suitcase_screen.dart` (sopra `AiPackRows`, ~riga 797), `assets/translations/it-IT.json`, `assets/translations/en-US.json` (chiave `trips.pack.ai.reassurance`)
- Test: `test/features/trips/view/widgets/ai/ai_pack_reassurance_test.dart`

**Interfaces:** Produces `class AiPackReassurance extends StatelessWidget` (nessun parametro).

- [ ] **Step 1:** test: con locale it mostra esattamente il testo it; con en il testo en; usa `bodySmall` o `bodyMedium` con colore `onSurfaceVariant`.
- [ ] **Step 2:** test di `pack_suitcase_screen` (file esistente dei flussi AI): con una valigia AI e partenza futura la riga c'è; con viaggio partito (`departureDateTime` nel passato) non c'è.
- [ ] **Step 3:** implementa e collega; verifica con lo scenario screenshot esistente "valigia-ai" (png in `build/ui-screenshots/`).
- [ ] **Step 4:** `flutter analyze`, test della cartella `test/features/trips/view`, commit `feat(valigia-ai): una riga che rassicura sotto il titolo`.

### Task 2: Versione del generatore

**Files:**
- Modify: `supabase/functions/_shared/valigia/uscita.ts` (o il punto dove `pack-trip/index.ts` compone la risposta, ~riga 174): campo `versione_generatore`.
- Create: costante `VERSIONE_GENERATORE = "2026-11-08"` in `supabase/functions/_shared/valigia/costanti_app.ts` (file nuovo, non `costanti.ts` che è generato dal banco).
- Modify: `lib/features/trips/model/ai_packing.dart` (`AiPackingResult`: `String? generatorVersion`), `lib/features/trips/services/pack_trip_service.dart` (lettura di `versione_generatore`), rigenerare freezed/json.
- Test: test TS della risposta di `pack-trip` (cartella `supabase/functions/pack-trip` o `_shared/valigia/test`), test del parser in `test/features/trips/services/`.

**Interfaces:** Produces `AiPackingResult.generatorVersion` (`String?`, null per le risposte vecchie).

- [ ] **Step 1:** test TS: la risposta contiene `versione_generatore: "2026-11-08"`; il test 888/888 del confronto col banco resta verde (il campo è fuori dalla valigia).
- [ ] **Step 2:** test Dart: risposta con il campo → `generatorVersion == "2026-11-08"`; risposta senza → null; un viaggio salvato prima (json senza campo) si legge.
- [ ] **Step 3:** implementa; `deno check supabase/functions/pack-trip/index.ts` dalla cartella della funzione; commit `feat(pack-trip): versione del generatore nella risposta`.

### Task 3: Le modifiche come funzione pura

**Files:**
- Create: `lib/features/trips/model/suitcase_edit.dart` (Freezed), `lib/features/trips/services/suitcase_edits.dart`
- Test: `test/features/trips/services/suitcase_edits_test.dart`

**Interfaces:**
- Produces:
  - `enum SuitcaseEditAction { added, removed, copies, suggestionRemoved, slotFilled, toBuy }` (nel database: `aggiunto`, `tolto`, `copie`, `suggerimento_tolto`, `posto_riempito`, `da_comprare`).
  - `enum SuitcaseEditOrigin { proposal, slot, kit, user }`.
  - `SuitcaseEdit { String id; String tripId; DateTime at; SuitcaseEditAction action; SuitcaseEditOrigin origin; int? copiesBefore; int? copiesAfter; Map<String, Object?> card; Map<String, Object?> context; String? generatorVersion; bool analysisAllowed; }`.
  - `List<SuitcaseEdit> suitcaseEdits({required TripModel before, required TripModel after, required DateTime now, required bool analysisAllowed, required Map<String, Object?>? Function(String itemId) cardOf, Map<String, Object?>? weather, String Function()? newId})`.
- Regole (dallo spec e dalle scelte del 8 nov):
  - nessun evento se `after.aiResult == null`, se `before.aiResult == null`, se `before.aiResult!.generatedAt != after.aiResult!.generatedAt`, o se `now` non è prima di `after.departureDateTime`;
  - oggetti del viaggio confrontati per `id`: nuovo → `added`; sparito → `removed`; `quantity` diversa → `copies` con prima/dopo; `isChecked` ignorato;
  - origine di un oggetto: in `aiResult.proposal` (per `itemId`) → `proposal`; in `aiResult.kitAdded` → `kit`; riempie un posto in questo stesso salvataggio → `slot`; altrimenti `user`;
  - posti confrontati per `id`: `removed` falso→vero → `suggestionRemoved`; `toBuy` falso→vero → `toBuy`; `remaining` sceso → `slotFilled`; la scheda di un evento sul posto è `{type, level}`;
  - `card`: `cardOf(itemId)` filtrato ai campi dei Global Constraints; null → `{}`;
  - `context`: giorni del viaggio, per ogni tappa `{activities, stay, washer}` da `aiSetup.stops`, mezzi del viaggio, e `weather` se passato (temperature medie min/max e giorni di pioggia per tappa).

- [ ] **Step 1:** test, uno per regola: aggiunta utente; rimozione di un proposto (origine `proposal`); copie 3→2; spunta ignorata; posto tolto con la X; posto da comprare; posto riempito con un capo nuovo (un `slotFilled` + un `added` con origine `slot`); Review Focus 1 (rigenerazione → `[]`) e 2 (adozione → `[]`); dopo la partenza → `[]`; oggetto senza scheda → `card == {}`; nessun campo `name` in `card` né in `context`.
- [ ] **Step 2:** implementa; commit `feat(valigia-ai): le modifiche alla proposta come funzione pura`.

### Task 4: Coda locale e registrazione

**Files:**
- Create: `lib/core/database/tables/suitcase_edits_table.dart`, `lib/core/database/daos/suitcase_edits_dao.dart`
- Modify: `lib/core/database/database.dart` (tabella, `schemaVersion` 13 → 14, `onUpgrade` con `if (from < 14) await m.createTable(suitcaseEdits)`), `lib/features/trips/providers/trip_provider.dart` (dopo ogni salvataggio riuscito di `updateTrip`, `addItemsToTrip`, `updateAiSlot`, `fillAiSlot`), `lib/core/sync/sync_service.dart` (`wipeAllUserData` svuota anche questa tabella)
- Test: `test/core/database/suitcase_edits_dao_test.dart`, test di `trip_provider` esistente, test di `wipeAllUserData` esistente

**Interfaces:**
- Consumes: `suitcaseEdits(...)` del Task 3; `ConsentService.analyticsEnabled`; `clothingFromMetadata` / `ItemModel.aiMetadata` per `cardOf`.
- Produces: `SuitcaseEditsDao.enqueue(List<SuitcaseEdit>)`, `Future<List<SuitcaseEdit>> pending({int limit = 200})`, `Future<void> deleteByIds(List<String> ids)`, `Future<void> deleteAll()`. Colonne: `id` (pk), `trip_id`, `at`, `action`, `origin`, `copies_before`, `copies_after`, `card_json`, `context_json`, `generator_version`, `analysis_allowed`.

- [ ] **Step 1:** test del DAO (enqueue, pending in ordine di `at`, deleteByIds, deleteAll) e test della migrazione 13→14 sul database in memoria.
- [ ] **Step 2:** test di `TripNotifier`: rimuovere un oggetto proposto con `updateTrip` mette un evento in coda; un salvataggio fallito non mette niente; un viaggio senza `aiResult` non mette niente.
- [ ] **Step 3:** test: `wipeAllUserData` lascia la coda vuota (Review Focus 4).
- [ ] **Step 4:** implementa; il meteo per `context` si prende dallo stato `TripWeatherReady` del viaggio se è già in memoria, altrimenti si omette (nessuna chiamata in più); commit `feat(valigia-ai): le modifiche in una coda locale`.

### Task 5: Tabella Supabase, invio e cancellazione con l'account

**Files:**
- Create: `supabase/migrations/20261108090000_valigia_modifiche.sql`
- Modify: `lib/core/sync/supabase_repository.dart` (`insertSuitcaseEdits`), `lib/core/sync/sync_service.dart` (`processQueue`: dopo le entità, invia la coda a blocchi di 200 e cancella in locale ciò che è arrivato), `supabase/functions/hard-delete-account/index.ts` (aggiungi `valigia_modifiche` all'elenco delle tabelle cancellate per `user_id`, prima di `trips`)
- Test: test di `SyncService` esistente (repository finto), test di `hard-delete-account` se presente

**Interfaces:**
- Consumes: `SuitcaseEditsDao` del Task 4.
- Produces: tabella `public.valigia_modifiche(id uuid pk, user_id uuid not null default auth.uid() references auth.users on delete cascade, trip_id uuid not null, creato_il timestamptz not null, azione text not null check (azione in ('aggiunto','tolto','copie','suggerimento_tolto','posto_riempito','da_comprare')), origine text not null check (origine in ('proposta','posto','kit','utente')), copie_prima int, copie_dopo int, scheda jsonb not null default '{}', contesto jsonb not null default '{}', versione_generatore text, analisi_consentita boolean not null)`; RLS attiva; policy solo `insert` e `select` con `user_id = auth.uid()`; nessuna `update`/`delete` per gli utenti. Indici su `user_id` e `creato_il`.

- [ ] **Step 1:** test di `SyncService`: tre eventi in coda → un insert con tre righe, coda vuota dopo; insert che fallisce → coda intatta; Review Focus 3: insert ripetuto con gli stessi id non crea doppioni (upsert `onConflict: 'id', ignoreDuplicates: true`).
- [ ] **Step 2:** scrivi la migrazione; controlla la sintassi con `supabase db lint` se disponibile, altrimenti leggila contro le migrazioni vicine (`20261103090000_kit.sql`).
- [ ] **Step 3:** `hard-delete-account`; `deno check` dalla cartella della funzione.
- [ ] **Step 4:** `flutter analyze`, `flutter test test/core test/features/trips`; commit `feat(sync): le modifiche alla valigia arrivano su Supabase`.

### Chiusura

- Testo della PR in `…/scratchpad/ds-piani/pr-modifiche-valigia.md` con, per Davide: migrazione da applicare su DEV poi PROD; deploy di `pack-trip` e `hard-delete-account`; testi da aggiornare nella privacy policy e nella scheda "Sicurezza dei dati" (attività nell'app, raccolta, collegata all'utente, non condivisa, cancellata con l'account; analisi d'insieme solo con "Statistiche d'uso"), e il testo sotto l'interruttore "Statistiche d'uso" da approvare.
- Scelta del piano da far vedere a Davide: gli eventi si ricavano **a ogni salvataggio**. Nella pagina "Prepara la valigia" le modifiche si salvano tutte insieme con "Salva", quindi lì si vede la differenza di quel salvataggio, non ogni tocco.

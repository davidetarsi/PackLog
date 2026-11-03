# Il foglio per riempire un posto — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Toccare un proposto ("Sneakers ×3 >") o "Aggiungi le tue" su un importante apre un foglio dal basso con il Rapid Fire: si scrivono i propri oggetti, le copie scendono, a zero il foglio si chiude da solo dopo un attimo. Sostituisce la variante B del Rapid Fire da un posto: niente riga che sale, niente resto spento, niente bolla.

**Spec:** decisioni di Davide del 3 novembre 2026, in chat; questo piano le riporta per intero. Base: design `2026-11-02-rapid-fire-posto-design.md` (comportamento dei posti, copie, "Da comprare", togliere), di cui cambia solo l'aspetto.

**Branch:** `feat/foglio-proposte` da `origin/develop`, worktree `/srv/claude/workspaces/PackLog-foglio`.

## Decisioni (Davide, 3 nov)

- Il foglio si apre da: riga di "Proposti da PackLog", "Aggiungi le tue" della card importante, "Presa" nella vista "Da comprare". Lo stesso foglio per tutti.
- Contenuto, dall'alto:
  - riga di testa con nome e copie che mancano ("Sneakers ×3") e, a destra, "Da comprare" come `DsTextButton` neutro;
  - la frase già esistente `trips.slots.open_hint` ("PackLog ne propone {}. Scrivi qui sotto quelle che hai davvero…");
  - gli oggetti scritti in questa apertura, ognuno con le sue copie, che compaiono con l'animazione d'ingresso del DS;
  - il `RapidFireInput` in fondo, con la tastiera aperta.
- Ogni invio crea l'oggetto nella casa e lo mette in valigia come oggi (logica esistente in `slot_actions.dart` / `slot_edits.dart`) e fa scendere le copie del posto.
- **Copie a zero:** il campo si disabilita, l'oggetto appena scritto compare nella lista del foglio, poi parte l'attesa `AppMotion.slotSheetCloseDelay` (nuovo token, 200 ms, che parte **dopo** la fine dell'animazione d'ingresso della riga), poi il foglio si chiude. Vale anche per gli importanti.
- **Chiusura** (automatica, trascinamento, indietro, tocco fuori): gli oggetti sono già nei loro gruppi della valigia; il posto resta fra i proposti con le copie che mancano, o sparisce se completo. Nessun volo.
- **"Da comprare"** nel foglio: chiude il foglio e segna il posto come oggi (proposta → vista "Da comprare"; importante → riga spenta "Importante · Da comprare").
- Restano: lo scorrimento a sinistra per togliere un proposto, la X con dialog sugli importanti, le regole delle copie e dei conteggi.
- Si tolgono (codice della variante B, solo se non più usato altrove): `slot_focus.dart`, `slot_pop.dart`, `slot_end_spacer.dart`, `open_slot_body.dart`, `slot_rapid_fire_bar.dart`, la riga aperta dentro `proposed_slots_card.dart` e `_OpenImportantCard` in `important_slot_cards.dart`, e lo stato di "posto aperto" in `trip_detail_screen.dart`. **Restano** `slot_flights.dart`, `item_flight.dart`, `flight_target.dart`: li usa la riga del kit (`flyKitItems`).

## Global Constraints

- Regole d'ambiente: `/tmp/claude-1001/-srv-claude-workspaces-PackLog/a389a2f8-d273-43c6-b669-b6e7c79291e2/scratchpad/ds-piani/ambiente.md` (cartella del worktree di questo piano).
- Solo componenti del DS (foglio: lo stesso componente dei fogli esistenti, es. quello di "Sposta"/"In un kit"), token del tema, `AppMotion`, `AppOpacity`, stringhe it-IT ed en-US (c'è un test di parità). Widget piccoli a una responsabilità; `trip_detail_screen.dart` deve scendere di righe, non salire.
- Con le animazioni di sistema disattivate: niente attesa animata, chiusura subito dopo l'invio che azzera le copie.

## Review Focus

1. Copie che arrivano a zero con un invio multiplo ("3 sneakers nere" su un posto ×2): si chiude, l'eccedenza resta come oggetto normale (copie del posto mai negative).
2. Chiudere il foglio mentre un invio è in corso: l'oggetto viene comunque salvato e il conteggio è giusto.
3. Tastiera: il foglio sale sopra la tastiera, il campo resta visibile su telefoni piccoli.
4. Importante segnato "Da comprare" e poi "Presa": riapre il foglio, non la vecchia riga aperta.
5. Kit: la riga del kit e il suo volo funzionano come prima.

---

### Task 1: Il foglio

**Files:** Create `lib/features/trips/view/widgets/slots/slot_fill_sheet.dart` (+ eventuali parti piccole nella stessa cartella); Modify `lib/shared/theme/app_motion.dart` (`slotSheetCloseDelay`); test `test/features/trips/view/widgets/slots/slot_fill_sheet_test.dart`.

**Interfaces:** `Future<void> showSlotFillSheet(BuildContext context, {required AiSlot slot, required String tripId, ...})` — chi chiama passa le callback esistenti per aggiungere un oggetto al posto e per "Da comprare" (riusare `SlotActions`).

Test: apre con nome, copie e frase; un invio mostra l'oggetto e fa scendere ×3 → ×2; l'invio che azzera disabilita il campo, mostra l'oggetto, chiude dopo `slotSheetCloseDelay` (pump della durata d'ingresso + del ritardo); con `disableAnimations` chiude subito; "Da comprare" chiude e segna; Review Focus 1 e 2.

Commit: `feat(valigia-ai): foglio dal basso per riempire un posto`.

### Task 2: Collegare il foglio e togliere la variante B

**Files:** Modify `proposed_slot_row.dart`, `proposed_slots_card.dart`, `important_slot_cards.dart`, `slots_section.dart`, `to_buy_slot_row.dart` / `to_buy_screen.dart` ("Presa"), `trip_detail_screen.dart`; Delete i file elencati nelle Decisioni (dichiararlo nel commit); aggiornare/togliere i test che li coprivano.

Test: toccare un proposto apre il foglio; "Aggiungi le tue" su un importante apre il foglio; "Presa" apre il foglio; dopo la chiusura gli oggetti sono nei gruppi e il posto ha le copie giuste; nessuna riga spenta (`AppOpacity`) nella pagina mentre il foglio è aperto; Review Focus 4 e 5.

Commit: `feat(valigia-ai): proposti e importanti si riempiono dal foglio; via la riga aperta`.

### Chiusura

Suite completa + `flutter analyze`; screenshot del foglio aperto (scuro e chiaro) con lo scenario screenshot esistente della valigia con posti; testo PR in `…/scratchpad/ds-piani/pr-foglio-proposte.md`.

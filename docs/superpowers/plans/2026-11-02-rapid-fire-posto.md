# Rapid Fire da un posto — piano di lavoro

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** il posto che si riempie si apre in cima ai "Proposti da PackLog" con il resto spento, si chiude con la bolla e il volo degli oggetti; "da comprare" e "tolto" cambiano come da spec.

**Architecture:** tutto nell'app, sul dettaglio del viaggio. Un campo `removed` sul posto, i conteggi aggiornati, e poi widget piccoli e separati: il contenuto del riquadro aperto, lo spegnimento, la bolla, il volo. Il dettaglio coordina, i widget animano.

**Tech Stack:** Flutter 3.38.5, Riverpod, freezed, easy_localization.

**Spec:** `docs/superpowers/specs/2026-11-02-rapid-fire-posto-design.md` (approvato il 2 novembre 2026). Mockup: https://claude.ai/artifact/UZm7aHL5nhL8T6YfPrssBN, variante B.

## Global Constraints

- Branch `feat/rapid-fire-posto` da `feat/prima-valigia`, worktree `/srv/claude/workspaces/PackLog-rapid-fire` (Task 0). Niente push.
- Solo componenti, tema, token e stringhe che esistono già: `ds_*`, `design_system.dart`, `AppMotion` per durate e curve, `AppOpacity` per gli spenti, `DialogHelpers.showConfirmation`, `AppSnackBar.showUndo`. Nessun colore, durata o testo scritto a mano (regola di Davide).
- Widget piccoli con una sola responsabilità. Nessun widget nuovo sopra le 200 righe, e `trip_detail_screen.dart` non cresce: la sezione dei posti esce in un file suo.
- Con `MediaQuery.disableAnimationsOf(context)` vero nessuna animazione: gli stati cambiano subito.
- Niente disegni o emoji degli oggetti.
- Risultati senza posti (`slots == null`): il dettaglio resta come oggi.

## Review Focus

1. **"5 t-shirt" su "Magliette ×3":** il riquadro scoppia una volta sola, l'oggetto finisce fra quelli dell'utente con 5 copie, e non resta nessuna riga vuota. → test nel Task 4.
2. **Back di Android con il riquadro aperto:** chiude il riquadro, gli oggetti scritti vanno fra quelli dell'utente, e la pagina non viene chiusa. → test nel Task 3.
3. **L'ultimo gruppo della pagina:** si apre comunque in cima alla vista, grazie allo spazio aggiunto in fondo, senza lasciare la pagina scorsa a metà. → test nel Task 3.
4. **"Annulla" su "Tolta" dopo aver lasciato la pagina:** ripristina il posto, leggendo il notifier prima dello snack. → test nel Task 2.
5. **Una proposta da comprare riaperta con "Presa" e chiusa con copie che restano:** resta fra le proposte, non torna nella vista "Da comprare". → test nel Task 3.

---

### Task 0: Ramo

- [ ] `git -C /srv/claude/workspaces/PackLog-prima-valigia worktree add /srv/claude/workspaces/PackLog-rapid-fire -b feat/rapid-fire-posto feat/prima-valigia`.
- [ ] Nel nuovo worktree esegui `flutter analyze` e `flutter test`: devono essere puliti e verdi (circa 2066).

### Task 1: "Tolto" e i conteggi

**Files:**
- Modify: `lib/features/trips/model/ai_packing.dart`, `lib/features/trips/model/suitcase_progress.dart`, `lib/features/trips/providers/to_buy_provider.dart` (+ `build_runner`)
- Test: `test/features/trips/model/ai_packing_test.dart`, `suitcase_progress_test.dart`, `test/features/trips/providers/to_buy_provider_test.dart`

**Interfaces:**
- Produces:
  - `AiSlot.removed` (`@Default(false) bool`);
  - `bool get isOpen => remaining > 0 && !removed`;
  - `bool get inSuitcase => isOpen && !(level == AiSlotLevel.useful && toBuy)`: un posto aperto che sta in valigia;
  - `SuitcaseProgress` conta solo i posti `inSuitcase`;
  - `toBuyEntriesOf` usa `isOpen && toBuy`, invariato, quindi esclude da solo i posti tolti.

- [ ] **Test:**
  - un posto `removed` non è aperto;
  - una proposta `toBuy` non è `inSuitcase`, un importante `toBuy` sì;
  - `SuitcaseProgress`: 4 oggetti, 9 proposte di cui 2 `toBuy`, 1 proposta `removed`, 5 importanti di cui 1 `toBuy` e 1 `removed` danno `proposed 7`, `importantOpen 4`, `readyTotal 15`;
  - vista "Da comprare": un posto `toBuy` e `removed` non c'è;
  - `carryToBuy` invariato.
- [ ] Verifica che falliscano, scrivi il codice, verifica che passino.
- [ ] Commit `feat(valigia): posti tolti e proposte da comprare fuori dai conteggi`.

### Task 2: Togliere un posto, e la valigia senza proposte da comprare

**Files:**
- Create: `lib/features/trips/view/widgets/slots/slots_section.dart`, dove esce `_SlotsSection` da `trip_detail_screen.dart`, senza cambiare comportamento
- Modify: `slot_widgets.dart`, `trip_detail_screen.dart`, le traduzioni
- Test: `test/features/trips/view/trip_detail_slots_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `ImportantSlotCard({..., VoidCallback? onRemove})`, con `DsIconButton` X in alto a destra, nascosta se `onRemove` è null;
  - `ProposedSlotsCard({..., ValueChanged<AiSlot>? onRemove})`, con ogni riga dentro `Dismissible` verso sinistra, chiave `slot_dismiss_<id>`;
  - nel dettaglio: `_removeSlot(AiSlot slot, {required bool confirm})`.

**Comportamento e testi:**
- **X su un importante:** `DialogHelpers.showConfirmation` con
  - titolo `trips.slots.remove_title` "Togli {}?" / "Remove {}?";
  - testo `trips.slots.remove_body` "PackLog la considera importante per questo viaggio." / "PackLog considers it important for this trip.", seguito da uno spazio e dal motivo del posto, se c'è;
  - conferma `trips.slots.remove_confirm` "Togli" / "Remove";

  poi `updateAiSlot(... removed: true)`.
- **Scorrere una proposta:** `removed: true` subito, poi `AppSnackBar.showUndo` con `trips.slots.removed` "Tolta {}" / "Removed {}". "Annulla" rimette `removed: false`. Il notifier si legge prima di mostrare lo snack.
- **Proposte da comprare:** non si mostrano più nella card "Proposti da PackLog". Il numero nella testata del gruppo conta solo i posti `inSuitcase` più gli oggetti.

- [ ] **Test:**
  - X → dialog → "Togli" → card sparita e legenda "4 importanti da sistemare";
  - X → "Annulla" → card ancora lì;
  - scorrere "Magliette" → riga sparita e snack "Tolta Magliette"; "Annulla" dopo `pop` della pagina → posto di nuovo aperto (Review Focus 4);
  - proposta `toBuy` → non c'è nel dettaglio;
  - i test del dettaglio che già esistono restano verdi.
- [ ] Verifica che falliscano, scrivi il codice, verifica che passino.
- [ ] Commit `feat(viaggio): togliere un posto, X per gli importanti e scorrimento per le proposte`.

### Task 3: Il riquadro aperto e lo spegnimento

**Files:**
- Create:
  - `lib/features/trips/view/widgets/slots/open_slot_body.dart`: il contenuto del riquadro;
  - `lib/features/trips/view/widgets/slots/slot_focus.dart`: lo spegnimento e il tocco fuori.
- Modify: `slot_widgets.dart`, `slots_section.dart`, `trip_detail_screen.dart`, le traduzioni
- Test: `test/features/trips/view/trip_detail_open_slot_test.dart`

**Interfaces:**
- Consumes: Task 2; quello che c'è già, cioè `SlotRapidFireBar`, `_openSlot`, `_fillSlot`, `fillAiSlot`.
- Produces:
  - `OpenSlotBody({required AiSlot slot, required List<TripItem> written})`: nome, ×remaining, la frase, gli oggetti scritti;
  - `SlotFocus({required bool active, required Widget child, required VoidCallback onTapOutside})`: con `active` mette il figlio a `AppOpacity` spento dentro `AbsorbPointer`, con un tocco che chiama `onTapOutside`, e anima l'opacità con `AppMotion`;
  - nel dettaglio, lo stato della schermata `List<TripItem> _written` per gli oggetti scritti in questa apertura (spec § 8.1) e `GlobalKey`s per la card del gruppo aperto.

**Comportamento:**
- **Frase del riquadro:** `trips.slots.open_hint` "PackLog ne propone {}. Scrivi qui sotto quelle che hai davvero, anche più di una insieme («2 t-shirt nere»): prendono il loro posto." / "PackLog suggests {}. Write below the ones you actually have, several at once too («2 black t-shirts»): they take their place." Il numero è `slot.copies`.
- **Proposta aperta:**
  - diventa la prima riga della sua `ProposedSlotsCard`, con dentro `OpenSlotBody`, su una superficie un livello più chiara (i livelli di superficie del tema);
  - le altre righe, le altre card, le testate e il resto della lista stanno dentro `SlotFocus(active: true)`.
- **Importante aperto:** si apre la sua `ImportantSlotCard`, al suo posto, con `OpenSlotBody` e la X nascosta.
- **Apertura:** `Scrollable.ensureVisible` porta la card in cima, con `AppMotion`. Finché il riquadro è aperto, la lista ha in fondo spazio pari all'altezza della vista.
- **Gli oggetti scritti** (`_written`) non compaiono fra gli oggetti dell'utente finché il riquadro è aperto.
- **"Presa" su una proposta da comprare:** mette `toBuy: false`, poi apre il riquadro (spec § 8.2).
- **Chiusura con copie che restano:** con la X del chip, il back o un tocco fuori, il riquadro si richiude, il resto si riaccende e `_written` si svuota. Gli oggetti tornano fra quelli dell'utente: il volo è nel Task 4, qui compaiono e basta.

- [ ] **Test:**
  - tocco "Magliette ×5" → `OpenSlotBody` prima riga della card e frase con "5";
  - invio "2 t-shirt nere" → "×3" e "T-shirt nere" dentro il riquadro ma non fra gli oggetti dell'utente;
  - tocco fuori → riquadro chiuso, "T-shirt nere" fra gli oggetti dell'utente, "Magliette ×3" fra le proposte;
  - back di Android → come il tocco fuori, pagina ancora aperta (Review Focus 2);
  - ultimo gruppo → `Scrollable.ensureVisible` chiamato e card a `dy` ≈ cima della vista (Review Focus 3);
  - "Presa" su una proposta da comprare, poi chiusura con ×2 → fra le proposte, non in `toBuyEntries` (Review Focus 5);
  - importante "Aggiungi la tua" → card aperta senza X;
  - con `disableAnimations` nessun ticker attivo dopo un `pump()`.
- [ ] Verifica che falliscano, scrivi il codice, verifica che passino.
- [ ] Commit `feat(viaggio): il posto si apre in cima ai proposti e il resto si spegne`.

### Task 4: La bolla e il volo

**Files:**
- Create:
  - `lib/features/trips/view/widgets/slots/slot_pop.dart`: la bolla;
  - `lib/features/trips/view/widgets/slots/item_flight.dart`: il volo.
- Modify: `slots_section.dart`, `trip_detail_screen.dart`
- Test: `test/features/trips/view/trip_detail_slot_close_test.dart`, `test/features/trips/view/widgets/slots/slot_pop_test.dart`

**Interfaces:**
- Consumes: Task 3 (`_written`, le chiavi).
- Produces:
  - `SlotPop({required Widget child, required bool popping, VoidCallback? onDone})`: scala e dissolvenza con `AppMotion.medium` e `AppMotion.standard`, poi `onDone`;
  - `Future<void> flyItems(BuildContext context, {required List<ItemFlight> flights})`, con `class ItemFlight { final Rect from; final GlobalKey to; final Widget child; }`. Usa un `OverlayEntry` che sposta ogni figlio da `from` al rettangolo di `to`, con `AppMotion.slow`, poi lo toglie.
  - Con `disableAnimations`: `SlotPop` chiama subito `onDone`, `flyItems` ritorna subito.

**Comportamento:**
- **Copie finite** (`remaining` a 0 dopo un invio) **o "Da comprare" nella barra su una proposta:** il riquadro fa `SlotPop`; poi `flyItems` porta gli oggetti di `_written` alle righe del gruppo della loro categoria (spec § 8.5). Il gruppo compare se non c'era. Un oggetto sommato a uno già presente vola una volta sola. Il resto si riaccende e la barra si chiude.
- **Chiusura con copie che restano:** niente bolla, solo `flyItems`.

- [ ] **Test:**
  - "5 t-shirt" su ×3 → `SlotPop` una volta, poi nessuna riga "Magliette" e "T-shirt" ×5 fra gli oggetti dell'utente (Review Focus 1);
  - "Da comprare" nella barra → bolla, proposta fuori dal dettaglio e presente in `toBuyEntries`;
  - "Cappello di lana" scritto da "Magliette" → finisce nel gruppo della sua categoria;
  - `flyItems` con `disableAnimations` → nessun `OverlayEntry` dopo `pump()`;
  - `slot_pop_test`: `onDone` chiamato una volta, dopo `AppMotion.medium`.
- [ ] Verifica che falliscano, scrivi il codice, verifica che passino. Poi `flutter analyze` e `flutter test` completo.
- [ ] Commit `feat(viaggio): la bolla del posto finito e il volo degli oggetti`.

### Task 5: Chiusura

- [ ] Screenshot (harness `test/screenshots/ui_screenshots_test.dart`, flusso del dettaglio viaggio), chiari e scuri:
  - "posto aperto", con Magliette ×3 e T-shirt nere ×2 scritte;
  - "importante da togliere", con il dialog aperto.

  Le immagini vanno nello scratchpad, in `rapid-fire-shots/`.
- [ ] Testo della PR in `scratchpad/ds-piani/pr-rapid-fire-posto.md`: dipende da `feat/prima-valigia`, nessun deploy, scelte e note. Commit degli scenari.

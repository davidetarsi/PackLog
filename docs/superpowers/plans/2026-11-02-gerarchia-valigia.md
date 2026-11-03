# Gerarchia della valigia — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** La valigia mostra prima gli importanti (arancione), poi i proposti (gradiente sottile), secondo la regola dei colori di Davide.

**Architecture:** Solo app. Due parametri nuovi in componenti condivisi (`DsTextButton.accent`, `PackLogGradientBorder.restingOpacity`) e un token d'opacità; poi tre widget della valigia li usano. Nessun dato cambia.

**Tech Stack:** Flutter 3.38.5, easy_localization, flutter_test.

**Spec:** `/srv/claude/workspaces/PackLog-giri-dev/docs/superpowers/specs/2026-11-02-kit-design.md` § 2 (Parte A). Mockup: schermata 5 di https://claude.ai/artifact/HkqmHNhBVUWTLHfPoABRm2.

**Branch:** `feat/gerarchia-valigia` da `feat/attesa-wow` (4e78a7a), worktree `/srv/claude/workspaces/PackLog-gerarchia`.

## Global Constraints

- Regole d'ambiente: `/tmp/claude-1001/-srv-claude-workspaces-PackLog/a389a2f8-d273-43c6-b669-b6e7c79291e2/scratchpad/ds-piani/ambiente.md` (con la cartella del worktree di questo piano al posto di `PackLog-giri-dev`).
- Regola dei colori: arancione `colorScheme.primary` = da fare (importanti e azioni); gradiente `PackLogGradientBorder` = viene da PackLog; giallo `colorScheme.tertiary` = proposto; neutro = tuo. Nessun colore nuovo.
- Solo DS, tema e token esistenti (`AppConstants.*BorderWidth`, `AppOpacity`, `ds_*`). Niente colori, spessori, opacità o durate scritti a mano: un valore nuovo diventa un token.
- Widget piccoli a una responsabilità.

## Review Focus

1. Tema chiaro: `primary` chiaro è `0xFFF4801F`; bordo ed etichetta devono restare leggibili anche lì (test di Task 3 in tutti e due i temi).
2. Importante aperto (`_OpenImportantCard`) e importante chiuso devono avere lo stesso bordo: aprire un posto non deve far "saltare" la card.
3. La riga "Importante · Da comprare" (`to_buy_slot_row.dart`) resta spenta com'è: è una riga silenziata per scelta (design Rapid Fire § 5.5), non prende arancione.
4. Con `MediaQuery.disableAnimations` il bordo dei proposti resta fermo e tenue (nessun ticker).
5. La barra delle origini con 0 importanti aperti non va mostrata (comportamento attuale `sorting == false`): nessun segmento arancione vuoto.

---

### Task 1: Componenti condivisi

**Files:**
- Modify: `lib/shared/widgets/ds_text_button.dart`
- Modify: `lib/shared/widgets/packlog_gradient.dart`
- Modify: `lib/shared/theme/app_opacity.dart`
- Test: `test/shared/widgets/ds_text_button_test.dart` (crearlo se non c'è), `test/shared/widgets/packlog_gradient_test.dart` (idem)

**Interfaces:**
- Produces: `DsTextButton({..., bool accent = false})` — testo e icona in `colorScheme.primary` quando `accent` e abilitato; `destructive` vince su `accent`; disabilitato invariato.
- Produces: `PackLogGradientBorder({..., double restingOpacity = AppOpacity.restingGradientBorder})` — l'opacità a riposo del bordo.
- Produces: `AppOpacity.subtleGradientBorder = 0.35` con il commento "Bordo a gradiente dei proposti: sotto l'arancione degli importanti."

- [ ] **Step 1: test che falliscono**
  - `DsTextButton accent usa primary`: pump con `accent: true`, il `Text` ha `style.color == colorScheme.primary`.
  - `DsTextButton destructive vince su accent`: `accent: true, destructive: true` → `colorScheme.error`.
  - `PackLogGradientBorder a riposo usa restingOpacity`: `loops: 0, restingOpacity: AppOpacity.subtleGradientBorder`; il painter (cercarlo con `find.byType(CustomPaint)`) riceve quell'opacità. Se l'opacità non è leggibile dal painter, esporla come campo `@visibleForTesting` del painter.
- [ ] **Step 2:** `flutter test test/shared/widgets/ds_text_button_test.dart test/shared/widgets/packlog_gradient_test.dart` → FAIL.
- [ ] **Step 3:** implementare. In `packlog_gradient.dart` la formula a riposo diventa `1 - (1 - widget.restingOpacity) * rest.value`.
- [ ] **Step 4:** stessi test → PASS; `flutter analyze` pulito.
- [ ] **Step 5:** commit `feat(ds): bottone di testo accentato e opacità del bordo a gradiente`.

### Task 2: Barra delle origini

**Files:**
- Modify: `lib/features/trips/view/widgets/slots/suitcase_progress_header.dart`
- Test: `test/features/trips/view/widgets/slots/suitcase_progress_header_test.dart` (crearlo)

**Interfaces:** nessuna nuova.

- [ ] **Step 1: test che falliscono**
  - `segmento importanti arancione`: progress con `mine: 9, proposed: 3, importantOpen: 2` → nella barra (`Key('trip_detail_ready_progress')`) c'è un `ColoredBox` con `colorScheme.primary`.
  - `pallino importanti pieno arancione`: il pallino della voce `legend_important` è pieno con `primary` (nessun bordo).
  - `senza importanti aperti niente barra delle origini`: `importantOpen: 0` → nessun `Key('trip_detail_ready_progress')`, c'è `Key('trip_detail_progress')`.
- [ ] **Step 2:** run → FAIL (i primi due).
- [ ] **Step 3:** in `_ReadyBar` il terzo segmento usa `cs.primary`; in legenda `_LegendDot(color: cs.primary)`. Aggiornare il commento in testa ("Colori provvisori…") con la regola dei colori.
- [ ] **Step 4:** run → PASS.
- [ ] **Step 5:** commit `feat(valigia): importanti in arancione nella barra e nella legenda`.

### Task 3: Card importante e card dei proposti

**Files:**
- Modify: `lib/features/trips/view/widgets/slots/important_slot_cards.dart`
- Modify: `lib/features/trips/view/widgets/slots/proposed_slots_card.dart`
- Test: `test/features/trips/view/trip_detail_slots_test.dart` (aggiungere), `test/features/trips/view/widgets/slots/proposed_slots_card_test.dart` (aggiungere)

**Interfaces:**
- Consumes: `DsTextButton.accent`, `PackLogGradientBorder.restingOpacity`, `AppOpacity.subtleGradientBorder` (Task 1).

- [ ] **Step 1: test che falliscono**
  - `importante: bordo e etichetta arancioni` (tema scuro e chiaro): la card ha un bordo `primary` largo `AppConstants.selectedBorderWidth`; il testo `trips.slots.important` ha colore `primary`.
  - `importante: Aggiungi accentato, Da comprare neutro`: il `DsTextButton` con `Key('slot_add_<id>')` ha `accent == true`; quello con `Key('slot_to_buy_<id>')` ha `accent == false`.
  - `importante aperto: stesso bordo`: con il posto aperto la card ha lo stesso bordo `primary`.
  - `proposti: bordo sottile e tenue`: il `PackLogGradientBorder` della card ha `width == AppConstants.hairlineBorderWidth` e `restingOpacity == AppOpacity.subtleGradientBorder`.
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** implementare. Il bordo arancione è una `RoundedRectangleBorder(side: BorderSide(color: cs.primary, width: AppConstants.selectedBorderWidth), borderRadius: …cardBorderRadius)` come `shape` del `Material` della card chiusa e di `_OpenImportantCard`; `ImportantLabel(color: cs.primary)` in tutte e due. `to_buy_slot_row.dart` non cambia (Review Focus 3).
- [ ] **Step 4:** run → PASS; poi `flutter test` completo una volta (ci sono test flaky noti: `pack_suitcase_ai_flow_test`, `add_edit_space_sheet_test`, `pack_weather_test` — rilanciarli da soli se falliscono).
- [ ] **Step 5:** commit `feat(valigia): importanti col bordo arancione, proposti col gradiente sottile`.

### Chiusura

- Screenshot della valigia (scuro e chiaro) con un importante, proposti e oggetti tuoi, salvati in `/tmp/claude-1001/-srv-claude-workspaces-PackLog/a389a2f8-d273-43c6-b669-b6e7c79291e2/scratchpad/gerarchia-shots/`, da mostrare a Davide accanto al mockup.
- Testo della PR in `…/scratchpad/ds-piani/pr-gerarchia-valigia.md`. Nessun deploy, nessuna migrazione.

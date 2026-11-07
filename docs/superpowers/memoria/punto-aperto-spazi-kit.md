---
name: punto-aperto-spazi-kit
description: "Kit logici e gerarchia della valigia (2 nov 2026): parte A pushata (PR #96), parte B pushata su feat/kit (PR da aprire dopo #96), worktree PackLog-kit"
metadata:
  node_type: memory
  type: project
  originSessionId: a389a2f8-d273-43c6-b669-b6e7c79291e2
  modified: 2026-11-02T17:40:28.568Z
---

Design del 2 novembre 2026: `/srv/claude/workspaces/PackLog-giri-dev/docs/superpowers/specs/2026-11-02-kit-design.md`. Mockup: https://claude.ai/artifact/HkqmHNhBVUWTLHfPoABRm2.

- Parte A (prima, solo app): gerarchia della valigia. Regola dei colori di Davide: arancione = da fare (importanti, azioni), gradiente = viene da PackLog (meteo, proposti con bordo sottile), giallo `tertiary` = proposto, neutro = tuo (kit compresi).
- Parte B: kit per casa, oggetti sciolti in valigia, 3 strade (pillole d'uso → da solo; soglia metà e almeno 2 → riga con i nomi dei mancanti; a mano), impara dopo 2 sì, pillola mezzo nel viaggio. Migrazione e deploy `pack-trip` li fa Davide.
- Profilo personale/registro modifiche: progetto separato [[idea-profilo-personale]].

**Why:** Leo usava uno spazio "Kit Viaggio" come gruppo; spazi = fisico, kit = logico.
**How to apply:** dopo l'approvazione, piano con writing-plans, esecuzione lean [[feedback-componenti-ds-semplici]].

2026-11-02 sera: parte A = feat/gerarchia-valigia (PR #96, tertiary chiaro portato a FBBF24). Parte B = feat/kit in /srv/claude/workspaces/PackLog-kit, 12 task + revisione finale opus, ledger in scratchpad ds-piani/ledger-kit.md, testo PR pr-kit.md. Restano: verifica su DEV dell'upsert kit_items dopo la migrazione; riallineare catalogo.json nel bench (lavoro mio); X della riga kit non a filo del bordo destro (minore).

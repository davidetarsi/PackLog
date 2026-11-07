---
name: prima-valigia-blocco2
description: "Blocco 2 di Leo (percorso fino alla prima valigia, posti) costruito il 1 novembre 2026 su feat/prima-valigia; stato e cosa resta"
metadata:
  node_type: memory
  type: project
  originSessionId: a389a2f8-d273-43c6-b669-b6e7c79291e2
  modified: 2026-11-01T20:57:27.534Z
---

Branch `feat/prima-valigia` (worktree /srv/claude/workspaces/PackLog-prima-valigia), base feat/catalogo-tag + merge di fix/rifiniture-leo (7dc063f), ultimo commit 7f6d770. Spec e piano in PackLog-giri-dev/docs/superpowers/{specs,plans}/2026-11-01-*prima-valigia* (docs/ non tracciato). Misura posti: specs/2026-11-01-misura-posti.md. PR text: scratchpad ds-piani/pr-prima-valigia.md; ledger con tutte le scelte: ds-piani/ledger-prima-valigia.md.

**Why:** Leo (UX) ha visto una prima valigia fatta di "manca"; l'utente è "attivo" quando vede la prima valigia AI.

**How to apply:**
- Il PR si apre dopo il merge di catalogo-tag e rifiniture-leo; deploy di pack-trip senza migrazione; l'app nuova manda `posti: true`, le vecchie ricevono ancora "Wardrobe is empty" (ordine di rilascio libero).
- Posti in `ai_packing_result.slots` (null = risultato vecchio). Giacca/scarpe del meteo unite in un posto (Task 3b, scelta di Claude da far confermare a Davide).
- Aperti: look della barra Rapid Fire da un posto (sessione dedicata), spazi e kit [[punto-aperto-spazi-kit]], Dogana delle Serate [[dogana-serate-artifact]] per i livelli "via".

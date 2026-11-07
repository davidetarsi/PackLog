---
name: roadmap-29-ottobre
description: Registro problemi PL-01..PL-12 e roadmap a fasi del 29 ott 2026 (quantita' generatore, scheda Rapid Fire, pillole, attivita', cataloghi Supabase); dove sta e cosa e' deciso
metadata:
  type: project
---

Davide ha mandato il 31 ott 2026 il documento "PackLog — Registro dei problemi, decisioni e roadmap" (29 ott, baseline main 1.2.1 f2e6d87 = develop). Copia in `/srv/claude/workspaces/PackLog-giri-dev/docs/superpowers/notes/2026-10-29-roadmap-bug-decisioni.md` (docs/ gitignored).

Ordine: Fase 1 quantita' (PL-07, sei T-shirt: le copie si rispettano in selezione, non nell'uscita) -> Fase 2 scheda/Rapid Fire con unione per campo (PL-03/04/05/12) -> Fase 3 pillole opache (PL-06) -> Fase 4 attivita' e motivi (PL-08..11) -> Fase 5 cataloghi Supabase (PL-01/02).

**Why:** decisioni del 31 ott in [[decisioni-prodotto-bench]] (strada A: bench come specifica; tag con meno responsabilita').
**How to apply:** fasi 1 e 4 partono dal bench (ramo da feat/colori-tavolozza), poi porting + oracoli; i testi dei motivi ora sono anche in inglese (PR feat/testi-inglese); PL-05: la sync oggi sceglie la riga intera per updated_at, l'unione per campo va fatta anche li'; il catalogo deve mappare ogni voce al codice italiano del generatore. Controllo overfitting: [[feedback-controllo-overfitting]].

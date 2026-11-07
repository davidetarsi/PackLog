---
name: revisione-codex-7-novembre
description: "Revisione del 7 nov 2026 delle PR #98-#107 fatte con Codex: generatore staccato dal banco (618/888), #105 contro la decisione del 18 ott, cammino contro le asserzioni, gate di qualità da ripristinare"
metadata:
  type: project
---

Dal 5 al 7 nov 2026 Davide ha lavorato con Codex e unito in develop le PR #98-#106; #107 (quantità mare) aperta. Revisione mia + opus il 7 nov (script in scratchpad review-nov7/: esporta_ts.ts porta le valigie TS nel formato del banco e le fa valutare a packlog_accuracy.py).

- Generatore TS vs banco: 618/888 identiche (prima 888/888). Le "baseline" di Codex (baseline_motore_migliorato.json, refactor_parita.test.ts) confrontano il TS con se stesso: non possono fallire.
- #105 toglie i requisiti trekking alle escursioni leggere: contro la decisione del 18 ott (e del 31 ott, "natura/escursioni tengono la regola del 18 ott"). v3: valigie ok 177 -> 154, asserzioni fallite 16 -> 53.
- #106 cammino compatto (3 mutande/3 calze): coerente con l'idea "modalità cammino" del 19 ott ma contro le asserzioni Cammino 20 gg (>=12 intimo, confermate 26 ott). Holdout30 asserzioni fallite 43 -> 74. Decisione di Davide.
- v4 sigillato (solo totali): severi 108/192 invariato, morbidi 144 -> 133.
- Proposte: giacca impermeabile "importante" in 246 viaggi sopra 28° anche senza pioggia (uscita.ts:194 + posti.ts:33); stivali importanti alle Maldive; scarpette da scoglio senza acqua (41); "5x camicie eleganti" (64); Leggings/Camicie calde.
- #107 applica bene le regole del 3 nov ma solo in TS.
- App: in ordine (DS, token, traduzioni); house_detail_screen 1098 righe.

**Why:** la linea concordata (31 ott, strada A) è banco = specifica, porting TS identico, overfitting controllato col v4.
**How to apply:** proporre a Davide un gate prima di ogni merge (valigie TS valutate con le asserzioni del banco: nessuna asserzione nuova fallita senza sua decisione), riportare #105-#107 nel banco, test-invarianti per le proposte. Vedi [[decisioni-prodotto-bench]], [[generatore-proposte]].

Da sistemare anche (Davide, 7 nov): `house_detail_screen.dart` (1098 righe) e la misurazione dell'altezza della barra del Rapid Fire fatta durante il disegno (`:491`, `:683`, dalla PR #100): spostarla in un widget piccolo a parte; valutare di spezzare la pagina della casa. Anche `rapid_fire_input.dart` è a 557 righe.
Piano deciso il 7 nov: PRIMA allineare il banco (repo GitHub davidetarsi/checklist-script-packlog, lavoro sul ramo feat/catalogo 152 commit avanti a main; le run registrate, 89 MB, non sono in git), poi i punti 2-4.

2026-11-07 sera: casa e Rapid Fire FATTI su refactor/casa-rapid-fire (pushato, PR da aprire); foglio perché su feat/perche-completo.

---
name: generatore-proposte
description: "Generatore delle proposte (strato dei posti di pack-trip): stato del 3 nov 2026, regola D approvata da fare dopo il foglio dei suggeriti"
metadata:
  type: project
---

Nome deciso il 3 nov 2026: "generatore delle proposte" = strato dei posti (`posti.ts`), fratello del generatore delle valigie.

- Fatto: `fix/posti-armadio-vuoto` (copie unite col massimo per tappa anche scarpe, muta mai importante, pantaloni lunghi da sera se tutte le tappe > 24°). PR da aprire.
- Approvato da Davide (3 nov), da fare DOPO `feat/foglio-proposte`: regola D = il nome del posto e' il primo sub chiesto dal modello compatibile con categoria e calore (serve portare l'ordine originale del modello in `richiesti`, generatore invariato 888/888). Prima correggere i 7 peggioramenti (Ginevra jeans in viaggio formale, Praga cappotto vs piumino, Budapest camicia vs maglione, Dolomiti neve maglietta vs maglione, Yakutsk felpa) con filtri di formalita' e calore, poi rimisurare. Indagine e script: scratchpad indagine-proposte/ (e.ts, cp2/).
- Regole dei viaggi caldi al mare da portare nel GENERATORE sul banco: [[decisioni-prodotto-bench]].

**Why:** con l'armadio vuoto i posti perdevano l'identita' tecnica (tutto "Maglione") e sommavano le copie.
**How to apply:** ripartire da qui dopo il foglio; misurare prima/dopo su oracolo_celle_campione.json.

---
name: prova-scan-dev-7-novembre
description: prova a pagamento di item-metadata su DEV (7 nov 2026, ok di Davide): 10 nomi + 3 foto; il prompt della foto ignora i capi non indossati
metadata:
  type: project
---

Script `scratchpad/prova_scan_dev.mjs` (legge da solo il .env di prova, mai stampato), foto pubbliche Wikimedia in `scratchpad/foto-scan/`, risposte in `foto-scan/risultati.json`. Chiamate verso le 23:40 del 7 nov.

- Nomi: 8/10 giusti; ancora sbagliati "muta da sub" (Full Body/Other, il catalogo ha Wetsuit) e "pile leggero" (Casual Jacket, il catalogo ha Fleece). Non so quale versione di item-metadata sia distribuita su DEV.
- Foto: valigia aperta con vestiti → 0 capi; flat lay maglia+sneakers+gonna → solo la maglia; scarponi → giusto. Causa: `promptScan` dice "ALL items WORN by the PRIMARY person... IGNORE clothes on beds, chairs, hangers... single item laid flat". Decisione di prodotto aperta per Davide: cosa fotografa l'utente.
- Prompt: ~2.000 → ~3.450 token dopo la #101 (stima da caratteri), senza cache. I token veri sono nei log delle Edge Functions ("[claude] uso"), che legge Davide.

**How to apply:** prima di ottimizzare il costo, decidere cosa deve riconoscere la foto; poi cache del prompt (statico) e più nomi per chiamata. Vedi [[idea-ui-aggiunta-capi]].

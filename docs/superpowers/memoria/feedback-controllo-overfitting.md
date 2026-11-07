---
name: feedback-controllo-overfitting
description: "Davide vuole che Claude si fermi di sua iniziativa a segnalare quando il lavoro sul bench rischia l'overfitting"
metadata:
  node_type: memory
  type: feedback
  originSessionId: e349a6cc-3bd9-4d6c-af17-65591b818287
  modified: 2026-10-13T10:49:38.661Z
---

Durante il lavoro sul bench (regole, soglie, asserzioni), fermarsi ogni tanto e dire a Davide se si sta andando troppo verso l'overfitting. Lui preferisce fermare i lavori e preparare un nuovo holdout per un test vero piuttosto che accumulare guadagni che non generalizzano.

**Why:** Davide, 13 ottobre 2026: "l'importante e' lavorare in una direzione corretta che ci permetta di trovare risultati validi che pero' non vadano mai troppo in overfitting".

**How to apply:** a ogni blocco di modifiche, separare i guadagni sugli insiemi da cui la regola e' stata ricavata (in-sample) da quelli sugli altri insiemi (pool44, holdout30 come controllo); segnalare soglie tarate su pochi casi; quando i guadagni arrivano quasi solo dagli insiemi usati per ricavare le regole, proporre di fermarsi e scrivere un holdout nuovo. Vedi [[decisioni-prodotto-bench]] e [[coda-lavori-bench]].

2026-10-18: Davide ha chiesto di NON rigiocare piu' il v4 per ora ("sennò si consuma"): dopo i due replay del 18 ottobre, il prossimo uso del v4 va proposto solo dopo un blocco consistente di modifiche, e chiedendo prima.

18 ott 2026, sui minimi di pool44: Davide preferisce criteri coerenti con l'idea di una valigia giusta anche se si perde qualche valigia ("piuttosto che farci condizionare dai risultati e dai limiti"). Quando si rileggono criteri, proporre valori dal buon senso e dalla coerenza fra viaggi, non quelli che alzano il punteggio.

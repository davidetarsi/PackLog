---
name: idea-profilo-personale
description: "Idea di prodotto PackLog (5 ottobre 2026): profilo personale di preferenze di valigia, da valutare DOPO il test dello script (holdout v2)"
metadata:
  node_type: memory
  type: project
  originSessionId: e349a6cc-3bd9-4d6c-af17-65591b818287
  modified: 2026-10-05T11:15:03.607Z
---

Davide vuole valutare, dopo aver testato lo script sul nuovo holdout, un **profilo personale**: preferenze che l'utente imposta una volta e che il sistema rispetta sempre.

Esempi emersi dalle sue abitudini (5 ottobre 2026): porta quasi sempre il costume (anche in citta', per piscina o spa), quasi sempre un K-way, sempre scarpe comode, uno strato leggero di base anche d'inverno, una camicia per le cene nei viaggi in citta'.

**Why:** separare cio' che serve a chiunque per quel viaggio (va nelle asserzioni e nelle regole generali) dalle preferenze personali (vanno nel profilo). Esempio di conflitto: il costume in citta' contraddice la regola di prodotto "niente costume senza attivita' in acqua".
**How to apply:** nelle asserzioni dell'holdout tenere fuori le preferenze personali (o marcarle nel campo "Altro"); riproporre l'idea del profilo quando lo script ha superato il test holdout.

Related: [[bench-quantita-e-casi-guida]]

2026-10-08: seconda preferenza da offrire nel profilo: "preferisco copie uguali" (es. 3 T-shirt nere identiche) invece di capi diversi. Il default di prodotto resta capi diversi (tetto morbido 2). Nel bench equivale a portare il tetto morbido al tetto duro.

2026-10-13: terza impostazione, livello di ABBONDANZA della valigia (essenziale / media / abbondante), da offrire come impostazione generale dell'utente. Guardate le 77 valigie v3 vicino al minimo, Davide le porterebbe cosi' ("sono una persona essenziale, con alta capacita' di adattamento"), ma il default di prodotto e' l'utente MEDIO: con un buon armadio, 3 giorni in citta' = 8-9 pezzi (3 T-shirt, 1-2 pantaloni, scarpe, antipioggia, felpa, cappello), giudicato "perfetto". I minimi che Davide scrive negli holdout sono quindi vicini al suo profilo essenziale, non all'utente medio: non stringerli ne' tararci sopra il default. Elenco delle impostazioni generali proposte: abitudini fisse (costume, K-way, scarpe comode, camicia per le cene), copie uguali vs capi diversi, livello di abbondanza.


2026-10-18: Davide propone di raccogliere le modifiche che l'utente fa alla valigia proposta (aggiunte, rimozioni, quantita') come dati, per il profilo personale e per migliorare il modello generale. Collegato: rendere costruttivi gli avvisi sui capi mancanti o inadatti. Ne vuole ragionare piu' avanti. Esempio dalla revisione alla cieca v3: le T-shirt in piu' sono probabilmente una sua abitudine (va nel profilo), mentre i pantaloni di lino fuori stagione sono un errore generale. Tensione da tenere presente: il 13 ottobre si e' descritto come 'essenziale', ma qui chiede piu' T-shirt.

Soglie di temperatura personali (Davide, 18 ott sera): chi e' freddoloso o soffre il caldo deve poter spostare le soglie (es. pantaloni corti gia' a 20 di massima). Proposta: UN solo scostamento personale (+/- gradi) applicato insieme a tutte le soglie (capi estivi 21, T-shirt 18, pile 18, un capo leggero al giorno sopra 24), non un'impostazione per regola.

Tag di viaggio "cammino" (Davide, 19 ott): da ragionare per l'app un tipo di viaggio esplicito "cammino" (percorso a piedi con zaino, si lava a mano) con regole piu' rigide, la "modalita' cammino": tetti per zona tipo 4 capi sopra, 2 sotto, un capospalla, 7-8 pezzi in tutto (Cammino di Santiago). Le regole restrittive non devono scattare con il solo tag trekking/outdoor.

2026-10-25: PUNTO APERTO A BREVE (Davide): sesso o stile dell'armadio nel profilo, per non proporre gonna/vestito/cravatta a chi non li usa. Per ora il generatore lo deduce dall'armadio (decisione in [[decisioni-prodotto-bench]]); il profilo e' la soluzione vera (app + migrazione, PR a parte).

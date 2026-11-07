---
name: design-valigia-ai
description: "Decisioni di Davide (24 ott 2026) sul design della Valigia con AI nell'app: foglio prima della generazione, attesa, pagina valigia generata; mockup e cosa resta"
metadata:
  node_type: memory
  type: project
  originSessionId: a389a2f8-d273-43c6-b669-b6e7c79291e2
  modified: 2026-10-24T11:33:55.542Z
---

Sessione di design del 24 ott 2026 (documento di progetto scritto: docs/superpowers/specs/2026-10-24-valigia-ai-design.md sul branch docs/valigia-ai-design, pushato, PR da aprire a cura di Davide; design approvato da Davide il 24 ott; PIANO scritto: docs/superpowers/plans/2026-10-24-valigia-ai.md, stesso branch, 13 task, parte da develop dopo il merge della PR #49 (bagagli utente, Drift 11) e porta Drift a 12; in attesa di revisione e scelta del metodo di esecuzione). Mockup: https://claude.ai/artifact/WoZJ5awxkzkFrRj4LeQQX5 (canvas: 1 foglio a stepper, variante a schede scartata, una tappa, 2 attesa, 3 valigia generata).

**Ingresso:** alla fine del passo 1 del nuovo viaggio (opzione A: valigia AI prima del passo 2). L'icona AI della pagina valigia genera solo se vuota, altrimenti chiede di sostituire ("Rigenera"); l'unione con capi gia' scelti NON si fa (pack-trip non accetta capi gia' scelti, servirebbe il bench).

**Foglio (bottom sheet):** in cima, validi per tutto il viaggio, casa da cui prendere i vestiti e bagaglio (bagagli dell'utente). Sotto, stepper per tappa (barra a segmenti, "Tappa 1 di 2 · Islanda", "Avanti: Olanda"): meteo della tappa, attivita', dove dormi, lavatrice. La tappa nuova parte VUOTA con il bottone "Uguale a <tappa prima>" che copia attivita', alloggio e lavatrice (mai copia silenziosa). Avviso finale se una tappa e' vuota ("Uguale a…" / "La compilo io"), mai bloccante. Una tappa sola: niente stepper ne' meteo.
**Pillole:** compatte 32dp, testo 14 (minimo dell'app 12), SENZA spunta; scelta = solo bordo e testo bianchi, non scelta = bordo scuro e testo grigio. Mai arancio (regola "un solo arancio" per schermata: l'arancio e' la CTA).
**Attivita':** elenco chiuso di 16 pillole -> codice del generatore: Citta' e musei (visite in citta), Passeggiate ed escursioni (escursioni leggere), Trekking, Cammino, Alta montagna (escursioni in quota), Mare, Immersioni e snorkeling (immersioni), Sci e neve (sci), Campeggio, Lavoro (riunioni di lavoro), Cena elegante (cena formale), Matrimonio, Luoghi di culto (visite a siti religiosi), Serate e locali (vita notturna), Bicicletta, Terme. Il viaggio salva il codice.
**Lavatrice per tappa -> generatore:** regola dei 5 giorni in pack-trip (ingresso.ts), non nell'app: lavatrice si' solo se non passano mai piu' di 5 giorni consecutivi senza lavatrice. Alloggi per tappa -> testo per il prompt; regole del caso peggiore (asciugamano in appartamento) NON esistono oggi nel generatore: da fare nel bench.

**Attesa:** pagina con tre passi (meteo, armadio, cosa manca), "una decina di secondi", Annulla.
**Valigia generata:** stessa pagina "Prepara la valigia" (non una nuova). Due righe in cima: "Cosa manca a questo viaggio" (icona e numero ambra, avvisi con "Cerca nell'armadio"/"Ok, capito") e "Perche' queste scelte" (motivi del catalogo). Lista SOLO dei capi in valigia (scelta di Davide), ricerca "Aggiungi dal tuo armadio" sui capi non in valigia, riga = PackItemRow allargata (niente casella, x a destra, "Da indossare in partenza"), tocco apre la scheda con il motivo. Selettore casa tolto dalla pagina: la casa si sceglie nel foglio.
**Non vestiti (decisione: variante 3b):** avviso sotto "Cosa porti" ("Ho scelto i vestiti e l'essenziale per l'igiene…") + gruppo chiuso in fondo "Dalla casa · N oggetti" con "+ Aggiungi"; -/+ anche li' solo con >=2 pezzi.
**Dati:** registro modifiche utente, avvisi, motivi e proposta AI salvati su Supabase (decisione di Davide), non solo sul telefono.
**REGOLA di Davide sulle quantita':** -/+ solo se l'oggetto ha almeno 2 pezzi nell'armadio, massimo = pezzi salvati; mai aggiungere quantita' che l'inventario non ha (PackItemRow lo fa gia'). Tetto lato server in pack-trip + avviso "Pochi …" (vedi punto 43 di [[coda-lavori-bench]]).

**Note:** la parola "capospalla" mai nei testi ("Giacche e cappotti"). pack-trip ora usa Claude Haiku 5.5 con ANTHROPIC_API_KEY (PR #45), aggiornare il promemoria segreti di [[produzione-generatore]]. Bagagli dell'utente (non della casa): lavoro locale di Davide non ancora pushato, servono migrazione Drift (schema 10 -> 11) e Supabase (luggages.house_id NOT NULL). Campi nuovi del viaggio (attivita', alloggio, lavatrice per tappa) nella stessa migrazione.

**Stato (24 ott):** implementata su branch locale `feat/valigia-ai` (worktree /srv/claude/workspaces/PackLog-valigia-ai, da develop dopo #49), 13 passi con subagenti Haiku 5.5 (scelta di Davide), test verdi. Testo PR in scratchpad di sessione. Aperte per Davide: Annulla spende comunque il credito; ritocchi di copy degli avvisi ("Servono più copie di…", "non basta" al plurale). Avvisi da mancanti_canonici ora con copy fisso in uscita.ts (mai slot/reason del generatore).

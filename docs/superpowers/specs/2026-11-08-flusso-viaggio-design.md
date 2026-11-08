# Flusso di creazione del viaggio — design

Data: 8 novembre 2026. Decisioni di Davide in chat (punti P1–P4 e unificazione dei componenti). Screenshot di oggi e della proposta: https://claude.ai/artifact/EH3YMTDSAsJVtX64JZQmKa (prova usa e getta sul ramo locale `spike/flusso-viaggio`, worktree `/srv/claude/workspaces/PackLog-spike-flusso`: da guardare, non da unire).

Base: `develop` dell'app (`e0816e5`, con la #108).

## Perché

Il flusso per creare un viaggio e fare la valigia deve essere pulito: nessuna pagina che si confonde con un'altra, nessuno stato a metà. Oggi:

- **P1** la strada AI passa sotto la pagina a mano: "Prepara con AI" salva il viaggio, apre "Prepara la valigia" e sopra il foglio AI; chi chiude il foglio resta nella valigia a mano senza averla scelta.
- **P2** il passo 1 ha tre azioni ("Prepara con AI", "Avanti: prepara la valigia", "Prepara la valigia più tardi"), con nomi diversi nel percorso del tour.
- **P3** la valigia vive in due pagine: quella AI si modifica nel dettaglio, quella a mano in "Prepara la valigia" (e nel dettaglio si legge soltanto).
- **P4** "Rigenera" rifà il giro di P1; e se si cambiano date o tappe di un viaggio con la valigia AI, la valigia resta quella vecchia senza avviso.

## Obiettivi

- Due strade sole dal passo 1, con nomi chiari.
- La strada AI non lascia niente di salvato finché la valigia non arriva.
- Una pagina sola per la valigia: il dettaglio del viaggio, uguale per valigia AI e a mano.
- Un componente per ogni cosa: niente doppioni fra le pagine del flusso.

## Non obiettivi

- Chiave di idempotenza per non perdere la valigia se l'app viene chiusa del tutto durante l'attesa: più avanti, se serve.
- Notifiche push.
- Cambiare il generatore, il foglio AI nei contenuti o la pagina "Cosa manca" (`/needs`).

## Anti-obiettivi

- Un viaggio salvato senza valigia perché il foglio AI è stato chiuso o la richiesta è fallita.
- Un credito AI scalato mentre l'app dice che non lo è.
- Due pagine che mostrano le stesse cose (meteo, bagagli, lista) in modo diverso.

## Vincoli

- Solo componenti del design system (`lib/shared/widgets/ds_*`), token del tema, `AppMotion`/`AppOpacity`, stringhe in `assets/translations` it-IT ed en-US. Widget piccoli a una responsabilità.
- Flutter 3.38.5 (`source /srv/claude/workspaces/.strumenti/flutter338.sh`).
- Offline-first (Drift + SyncService): il salvataggio di viaggio e valigia passa dai provider esistenti.
- Server invariato: `pack-trip` consuma il credito all'inizio e lo restituisce se fallisce.
- Il ramo `feat/modifiche-valigia` (eventi delle modifiche alla proposta) non è ancora in develop: la prima adozione della proposta non deve produrre eventi; chi integra dopo deve tenerne conto.

## Parte A — Passo 1 e strada AI (P1, P2)

### Bottoni del passo 1

Due bottoni, sempre nello stesso ordine:

| | it | en | cosa fa |
|---|---|---|---|
| primario (arancio, icona ✦) | Prepara la valigia con AI | Pack with AI | apre il foglio AI sopra il passo 1 |
| secondario DS (contorno) | Scegli tu cosa portare | Choose what to bring | salva il viaggio e apre "Prepara la valigia" (passo 2, a mano) |

- Spariscono "Avanti: prepara la valigia", "Prepara la valigia più tardi" e "Prepara a mano". Chi vuole solo segnare le date entra in "Scegli tu cosa portare" ed esce con la lista vuota: il viaggio resta salvato.
- Stessi due bottoni nel nuovo viaggio, nel percorso del tour (oggi `aiIntent`) e in **Riusa** (oggi "Avanti" + "più tardi"). In **Modifica viaggio** resta il solo "Salva".
- La fascia in fondo oggi esiste in quattro versioni in `new_trip_screen.dart`: diventano due (creazione/riuso, modifica).
- Spenti finché mancano meta o date; il tocco da spento mostra cosa manca (come oggi).

### Strada AI

1. "Prepara la valigia con AI" apre il foglio AI **sopra il passo 1**, senza salvare niente.
2. Chiudere il foglio senza confermare: si torna al passo 1, compilato, niente salvato.
3. Conferma nel foglio: si apre l'attesa. Il viaggio non è ancora salvato.
4. **Arriva la valigia:** viaggio e valigia si salvano insieme, in una scrittura sola. Se l'utente è ancora nell'attesa, si apre il dettaglio in prima revisione (`?review=1`, CTA "Fatto" → Viaggi), come oggi.
5. **Errore:** niente salvato, si resta nell'uscita d'errore dell'attesa (`AiWaitFailure`), che oggi offre riprova; da lì si torna al passo 1 compilato.
6. **Riusa** con l'AI: DA DECIDERE CON DAVIDE (vedi in fondo).
7. **Risposte del foglio** (`aiSetup`): restano in memoria finché si è nel passo 1 (riaprendo il foglio dopo un errore o una chiusura si ritrovano) e si salvano con il viaggio all'arrivo (scelta mia).

### Un lavoro AI alla volta (scelta mia)

- C'è al massimo un lavoro AI in corso per tutta l'app. Se ce n'è già uno, "Prepara la valigia con AI", Rigenera e "Rifalla con AI" non aprono il foglio e mostrano uno snackbar: "Sto già preparando una valigia: ti avviso quando è pronta." (en "I'm already packing a suitcase: I'll let you know when it's ready."). Questo copre anche il doppio avvio con gli stessi dati.

### L'attesa

- Niente "Annulla".
- Sotto i passi resta "Di solito ci vogliono una decina di secondi." e sotto una riga piccola grigia (`bodySmall`, `onSurfaceVariant`), testo di Davide:
  - it: "Resta qui mentre prepariamo la valigia: non chiudere PackLog e non aprire altre app."
  - en: "Stay here while we pack your suitcase: don't close PackLog or open other apps."
- **Uscire dall'attesa** (indietro) non annulla: si torna dove si era prima del passo 1 (di solito Viaggi) e la richiesta continua. Quando arriva, si salvano viaggio e valigia e compare uno snackbar DS ovunque si sia nell'app (`AppSnackBar.showAction` in `snack_bar_helper.dart`, già usato nella prova): "Valigia pronta per <titolo>" con azione "Apri" (en "Suitcase ready for <title>" · "Open") che apre il dettaglio in prima revisione. Se fallisce: snackbar d'errore, niente salvato.
- **App chiusa del tutto** durante l'attesa: la valigia si perde (limite accettato da Davide).
- La richiesta quindi non può vivere nello stato della pagina d'attesa: serve un lavoro tenuto da un provider che sopravvive alla pagina.

### Crediti

- Il server decide: risposta di errore del server → il credito è restituito; 200 → è scalato. L'app non tocca i crediti.
- Messaggio di errore (scelta mia): "nessun credito scalato" solo quando l'errore viene dal server (eccezioni con risposta: crediti finiti, armadio vuoto o troppo grande, errore di `pack-trip`). Quando la rete cade a richiesta partita (`PackTripNetworkException`), l'app non sa com'è andata: messaggio generico senza parlare di crediti.

### Cose che oggi si fanno al salvataggio e vanno spostate

- `completeFirstTrip()` del tour: oggi al salvataggio del passo 1 e della pagina valigia. Nella strada AI va chiamato quando viaggio e valigia si salvano.
- Evento `first_suitcase_generated` e `_logKitAutoAdded` (oggi in `pack_suitcase_screen.dart`): al salvataggio della valigia AI, ovunque avvenga (anche in background).
- Kit aggiunti in automatico (`carryKitCounted`, oggi in `pack_suitcase_screen.dart`): devono continuare ad applicarsi alla valigia AI salvata.

## Parte B — Il dettaglio è la valigia (P3)

Regola: **il dettaglio del viaggio è la valigia**, per tutte le valigie; **"Prepara la valigia" serve solo ad aggiungere.**

### Dettaglio (`trip_detail_screen.dart`)

- Stesso layout per valigia AI e a mano: riepilogo, meteo, bagagli con `PackLuggageSelector`, lista degli oggetti modificabile (spunta, togli, copie, apri la scheda). Per la valigia a mano mancano solo posti, "Cosa manca" e "Perché queste scelte".
- Bottone fisso in basso "Aggiungi oggetti" (`Icons.add`; en "Add items") per tutte le valigie, anche vuote, che apre la pagina di aggiunta. Nella prima revisione della valigia AI resta "Fatto".
- Viaggio senza oggetti: `EmptySuitcase` + "Aggiungi oggetti".
- Le valigie AI vecchie senza posti (con gli avvisi) si mostrano come una valigia a mano (scelta mia: sono poche e gli avvisi erano della versione vecchia).

### Pagina di aggiunta (`pack_suitcase_screen.dart`)

- Solo **ricerca, Rapid Fire, kit e oggetti della casa** (con il selettore della casa). Via meteo, bagagli, riepilogo e la lista "Cosa porti" con gli stepper: stanno nel dettaglio.
- Via l'icona ✦ in alto: l'AI parte solo dal passo 1 e dal dettaglio (Parte C).
- Titolo: dalla creazione "Prepara la valigia" con i passi (Viaggio ✓ · Valigia); dal dettaglio "Aggiungi alla valigia" (en "Add to suitcase"), senza passi.
- "Fatto · N oggetti" salva e porta al **dettaglio** (dalla creazione con `pushReplacement`, dal dettaglio con `pop`).
- Le parti che la pagina aveva solo per la valigia AI (avvisi, `AiPackRows`, rigenerazione) vanno via.

### Componenti da unificare

| Cosa | Oggi | Dopo |
|---|---|---|
| Fascia dei bottoni del passo 1 | 4 versioni in `new_trip_screen.dart` | 2: creazione/riuso, modifica |
| Riga di un oggetto | `PackItemRow` (pagina valigia, con stepper) e `PackedRow` (dettaglio, "×N") | una riga, nel dettaglio; la pagina di aggiunta usa solo le righe della ricerca (`PackAddRow`) |
| Lista degli oggetti | `PlainItemsSection` (a mano, sola lettura) e `ItemsOnlySection` (AI) | una sola, modificabile |
| Bagagli | `PackLuggages` (solo lettura) e `PackLuggageSelector` | solo il selettore |
| Meteo, bagagli, riepilogo | nella pagina valigia e nel dettaglio | solo nel dettaglio |

Cosa resta di ciascuna riga (stepper o "×N", casella, ×) lo decide il costruttore partendo da quella del dettaglio; il risultato è una riga sola. I componenti che restano senza uso vanno cancellati (dichiararlo nella PR).

Le tre schede del meteo (dettaglio, pagina meteo, attesa) restano diverse: fanno cose diverse.

## Parte C — Rigenera e modifica del viaggio (P4)

### Rigenera

- Dal menu ⋮ del dettaglio (solo con valigia AI), dopo il dialogo di conferma che c'è oggi ("vuoi sostituire?"), il foglio AI si apre **sopra il dettaglio**, senza passare dalla pagina di aggiunta.
- Poi come la strada AI: attesa con la stessa riga, uscita = continua in background, la valigia nuova sostituisce la vecchia **solo quando arriva**; errore = la vecchia resta, con il suo `aiSetup`.
- All'arrivo la valigia nuova si applica al viaggio **com'è in quel momento** (date e tappe correnti, se cambiate nel frattempo comparirà l'avviso qui sotto); se il viaggio è stato cancellato, il risultato si scarta (scelta mia).
- La logica oggi in `pack_suitcase_screen.dart` (dialogo, foglio, `aiSetup`, `PackTripJob`, kit, eventi, `completeFirstTrip`) diventa un servizio condiviso usato da passo 1, Rigenera e avviso; la rotta `edit-items?ai=1` sparisce (scelta mia).

### Avviso dopo una modifica del viaggio

- Quando "Modifica viaggio" salva un cambio di **date, tappe o mezzi** su un viaggio con valigia AI non ancora partito, nel dettaglio compare un avviso sopra la valigia:
  - it: "Hai cambiato il viaggio: la valigia potrebbe non andare più bene." azione "Rifalla con AI"
  - en: "You changed the trip: the suitcase may no longer fit." action "Redo with AI"
- L'azione fa la stessa strada di Rigenera. L'avviso si può chiudere; sparisce anche quando arriva una valigia nuova.
- Deve restare anche dopo aver chiuso e riaperto l'app (scelta mia): `AiPackingResult` riceve un campo nuovo con date, tappe (luoghi e date) e mezzi del viaggio per cui è stata fatta, e un flag per l'avviso chiuso. L'avviso compare quando il viaggio di adesso differisce da quel campo. Le valigie AI già esistenti non hanno il campo: nessun avviso. Il costruttore verifica come `aiResult` viaggia verso Supabase (se è JSON, niente migrazione).
- Cambiare solo il nome non fa comparire l'avviso.

### Date in "Modifica viaggio"

- Il campo "Quando?" mostra le date di **tutto il viaggio** ("18 nov – 23 nov · 5 notti"), non solo della prima tappa, così le tappe non restano tagliate fuori (decisione di Davide). Le date delle singole tappe restano nell'itinerario.

## Verifica

- Test dei widget: passo 1 con due bottoni in creazione, tour e Riusa, "Salva" in modifica; foglio chiuso → passo 1 compilato e nessun viaggio nel provider; errore → nessun viaggio; arrivo → viaggio e valigia insieme; uscita dall'attesa → arrivo in background → snackbar con "Apri".
- Dettaglio: valigia a mano modificabile e "Aggiungi oggetti"; valigia AI uguale; pagina di aggiunta senza meteo, bagagli e ✦.
- Rigenera: la vecchia resta fino all'arrivo; errore → vecchia intatta.
- Avviso dopo modifica: compare per date/tappe/mezzi, non per il nome; resta dopo il riavvio; sparisce con la valigia nuova.
- Gli screenshot (`test/screenshots/ui_screenshots_test.dart` e `store_screenshots_test.dart`) aggiornati; i test che toccano l'icona ✦ (`pack_ai_suitcase`, anche `test/features/trips/view/pack_suitcase_ai_flow_test.dart`) riscritti.
- `flutter analyze` pulito, `flutter test` verde.

## Ordine proposto

Tre PR separate, nell'ordine: **A** (passo 1, strada AI, attesa), **B** (dettaglio = valigia, pagina di aggiunta, componenti), **C** (Rigenera, avviso dopo modifica, date). A e C toccano il foglio e l'attesa: C parte da A unita.

## Lasciato al costruttore

- Dove vive il lavoro AI in corso (provider), come si mostra lo snackbar da ovunque, come si passa il viaggio non salvato al foglio e all'attesa.
- Le rotte (l'attesa può restare `/trips/:id/ai-packing` con un id già scelto ma non salvato, o cambiare).
- La forma esatta della riga unica degli oggetti, purché nata da quella del dettaglio e con componenti DS.
- Come il dettaglio modifica la valigia a mano (riusando `SlotActions` e le mutazioni del dettaglio o no).

## Scelte mie da controllare

- Messaggio sui crediti solo per errori del server, generico per la rete.
- Valigie AI vecchie senza posti mostrate come valigie a mano.
- Avviso dopo modifica persistente, ricavato dal confronto con il viaggio salvato nella proposta.
- Un lavoro AI alla volta, con snackbar se se ne avvia un altro.
- Risposte del foglio tenute in memoria nel passo 1 e salvate all'arrivo.
- Rigenera: la valigia nuova va sul viaggio com'è all'arrivo; viaggio cancellato = risultato scartato.
- Logica AI in un servizio condiviso, via `edit-items?ai=1`.

## Da decidere con Davide

- **Riusa con l'AI.** Oggi Riusa crea subito una copia salvata del viaggio (senza date, con gli oggetti dell'originale non spuntati) e la cancella se si esce senza salvare. Con "Prepara la valigia con AI" la valigia AI sostituisce gli oggetti copiati o si aggiunge? E la copia deve esistere solo quando si sceglie una delle due strade (Riusa = passo 1 precompilato, niente salvato prima)?

# Navigazione: due luoghi + azione contestuale

Data: 2026-10-13 · Stato: approvato in brainstorming, da rivedere come documento

Prima parte della standardizzazione UI (vedi file Figma "PackLog – Design", pagina Inventario). Obiettivo: mettere l'azione più importante dell'app — aggiungere oggetti, soprattutto con la scansione AI — a un tocco da qualunque tab, togliere la scelta Viaggio/Oggetto/Casa a ogni creazione e liberare la barra dal Profilo.

## Decisioni

1. **Barra flottante con due luoghi: Case e Viaggi.** Il Profilo esce dalla barra.
2. **Bottone d'azione tondo, arancio, staccato dalla barra** (a destra, stessa linea). Fa l'azione principale della tab corrente:
   - **Case** → foglio "Aggiungi oggetti" (vedi sotto).
   - **Viaggi** → wizard Nuovo viaggio (`/new-trip`).
   Il bottone non cambia mai significato dentro una tab. **Senza case** il bottone di Case resta "Aggiungi oggetti" ma in aspetto spento (tonale, non arancio), così l'unico elemento arancio è la CTA "Aggiungi la tua prima casa" dello stato vuoto; se lo si tocca comunque, un messaggio breve spiega «Crea prima una casa». Non è un bottone disabilitato muto: risponde al tocco.
   Il bottone ha un + con sotto un'etichetta fissa ("Oggetto" / "Viaggio"), come le voci della barra; TalkBack legge "Aggiungi oggetti" / "Nuovo viaggio". Stile a contorno (bordo e contenuto arancio sullo sfondo della barra), scelto dopo il confronto con pieno e tonale (aggiornamento 13/10, PR #24). Spento: valori di disabilitato M3.
3. **Profilo come avatar in alto a destra** nelle intestazioni di Case e Viaggi. Tocco → `/profile`, aperta sopra la shell con freccia indietro. Avatar: iniziali del nome dell'utente su `primaryContainer`. Se ci sono modifiche non sincronizzate (`totalUnsyncedCountProvider > 0`) compare un pallino sull'avatar.
4. **Intestazione unica per le tab**: titolo a sinistra ("Case", "Viaggi"), avatar a destra. Il titolone "Pronto per la tua prossima avventura?" sparisce (il ridisegno della tab Viaggi è fuori da questo lavoro).
5. **Nuova casa in fondo alla lista delle case**: riga con bordo tratteggiato, testo e icona "+" neutri (`onSurfaceVariant`), stessa altezza e raggio delle card casa. Niente arancio. Nello stato vuoto la stessa riga, in arancio, sostituisce la CTA piena ("Aggiungi la tua prima casa").
6. **Speed-dial "Crea" eliminato**, con overlay e pillole a bordo nero.

## Foglio "Aggiungi oggetti"

Bottom sheet con l'intestazione condivisa (`DsSheetHeader`).
- In cima: **casa di destinazione**, preselezionata sulla casa principale (o la prima, se nessuna è principale); tocco → `DsPickerSheet` per cambiarla.
- Azione grande: **Scansiona con AI** → `/houses/:id/ai-import` della casa scelta.
- Azione secondaria: **Scrivi a mano** → `showAddEditItemSheet(houseId: …)`.

Nel dettaglio casa non cambia nulla: resta la barra "Aggiungi oggetto…" con il bottone AI.

## Effetto vetro (Liquid Glass)

Barra e bottone d'azione su superficie semitrasparente con sfocatura dello sfondo (`BackdropFilter`). Va verificato sul telefono con l'app di prova: se scatta in scorrimento, si passa a superficie tonale piena (`surfaceContainer`) senza sfocatura. La scelta finale si annota nella PR.

## Routing

- `StatefulShellRoute` con due rami: 0 = `/` (Case), 1 = `/trips` (Viaggi).
- `/profile` diventa una `GoRoute` sul navigator radice, aperta con `push`; `ProfileScreen` usa uno scaffold con AppBar e freccia indietro invece di `ShellTabScaffold`.
- Aggiornare la mappa dei rami in CLAUDE.md (oggi 0 = profilo, 1 = case, 2 = viaggi).

## Tour guidato

Due suggerimenti puntano oggi al "+" della barra:
- **`houseTooltip`** ("Crea la tua prima casa"): punta alla riga **Nuova casa** in fondo alla lista (nuova chiave del tour). Testo: «Tocca "Nuova casa" in fondo all'elenco per aggiungere la tua prima casa.»
- **`createTripTooltip`** ("Crea il tuo primo viaggio"): punta alla tab **Viaggi**. Testo: «Apri Viaggi e tocca + per creare il tuo primo viaggio.» Al tocco sul bersaglio la shell passa alla tab Viaggi.
- La chiave `houseFab` diventa la chiave del bottone d'azione; `profileTab` si elimina. Le stringhe in `it-IT.json` ed `en-US.json` si aggiornano entrambe.

## Analytics

- Nuovo evento `primary_action_tapped` con proprietà `tab` (`houses`/`trips`), `action` (`add_items`/`new_trip`) e `enabled` (`false` quando si tocca il bottone spento senza case).
- Nel foglio: `add_items_sheet_choice` con `choice` (`ai_scan`/`manual`).
- Entrambi passano da `CoreAnalyticsService` (metodi tipati).
- L'apertura del profilo è già tracciata dall'observer delle rotte.

## Fuori da questo lavoro

Colori, card e liste, ridisegno della tab Viaggi, analisi dei flussi con troppi passaggi.

## Verifica

- Test di widget della shell: due voci nella barra; il bottone d'azione cambia funzione ed etichetta con la tab; con zero case è spento e al tocco mostra «Crea prima una casa»; l'avatar apre `/profile`; il pallino compare con modifiche in attesa.
- Test del foglio "Aggiungi oggetti": casa preselezionata, cambio casa, le due azioni portano alla rotta / al foglio giusti.
- Test del tour aggiornati per le nuove chiavi.
- Screenshot del test UI rigenerati (flussi Case, Viaggi, Profilo) e caricati in Figma.
- `dart analyze` pulito e suite completa verde; prova manuale sull'app.

## Aggiornamento 13/10 pomeriggio: Crea dentro la barra

Dopo la prova del bottone separato (pillola con scritta, poi cerchio con la scritta fuori) si è scelta, dai mock, la **barra Case · Crea · Viaggi** con Crea al centro, allineato alle altre voci (cerchio a contorno da 32 dp + scritta "Crea"). Crea è uguale in ogni tab e apre il **foglio Crea**:
- card "Scansiona con AI" in primo piano, arancio più deciso in chiaro, con la casa di destinazione come testo + freccia (senza pillola);
- link "Non sono vestiti? Scrivili a mano →": apre la casa con il rapid fire già attivo (`/houses/:id?add=manual`). Non c'è più la voce "Nuovo oggetto": l'inserimento a mano passa dal rapid fire;
- poi Nuova casa e Nuovo viaggio; aperto da Viaggi, Nuovo viaggio va prima;
- senza case: card AI spenta («Crea prima una casa…»), niente link, Nuova casa in arancio; scansioni esaurite: card spenta, il link resta.
Eventi: `create_tapped` (`tab`) e `create_sheet_choice` (`choice`, `tab`), al posto di `primary_action_tapped`/`add_items_sheet_choice`. Il tip "Crea il tuo primo viaggio" punta a Crea. Stato vuoto delle case: riga tratteggiata arancio "Aggiungi la tua prima casa".

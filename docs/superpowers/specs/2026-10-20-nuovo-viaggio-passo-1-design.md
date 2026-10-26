# Nuovo viaggio · Passo 1 "Viaggio" · Design

Data: 20/10/2026 · Stato: approvato dall'utente (20/10/2026) · Riferimenti visivi in `docs/superpowers/mock/viaggi/`:
- `nuovo-viaggio-due-passi-chiaro.png` / `-scuro.png`: struttura generale e passo 2;
- `nuovo-viaggio-tappe-e-foglio-crea.png`: tappe e foglio Crea;
- `nuovo-viaggio-bottone-ai-e-dati-mancanti.png`: posizione 2 del bottone AI e stato con i dati mancanti.

Il codice del mock è in `new_trip_mock.dart.txt` (usa e getta). Questa descrizione copre il passo 1; il passo 2 (pagina valigia) avrà la sua.

## 1. Perché

Oggi il nuovo viaggio è un wizard in due passi:
- **passo 1:** nome, scelta "Altra località / Casa", meta, date, "Altre tappe";
- **passo 2:** scelta degli oggetti e dei bagagli.

Il viaggio si salva solo alla fine, quindi chi esce a metà del passo 2 perde tutto. L'ordine è da modulo e non segue l'itinerario della cartolina. L'arancio è usato su pillole, barra dei passi e snackbar, fuori dalle regole del kit. Nel frattempo è arrivato il generatore della valigia con meteo (PR #35): ha bisogno di un viaggio salvato con luoghi e date giusti, anche per tappa.

Il nuovo flusso è **Viaggio → Valigia**: il passo 1 raccoglie i dati nell'ordine della cartolina e **salva** il viaggio; il passo 2 è la pagina valigia, la stessa che si apre da "Prepara la valigia" della cartolina.

## 2. Obiettivi, non obiettivi, anti-obiettivi

**Obiettivi**
- Passo 1 nell'ordine dell'itinerario:
  - dove;
  - quando;
  - tappe, ciascuna con le sue date, e ritorno calcolato da solo;
  - nome, già proposto.
- Salvataggio alla fine del passo 1. Tutte le uscite rispettano gli stessi dati obbligatori.
- Coordinate salvate per ogni luogo, così il meteo funziona per tappa.
- Predisposizione della strada "con l'AI" (posizione e regole decise), senza costruirla ora.

**Non obiettivi**
- La pagina valigia (passo 2): descrizione separata. Qui si fissa solo come ci si arriva.
- La chiamata all'AI, la sua pagina dei risultati e la visualizzazione del meteo.
- "Modifica informazioni" del viaggio: va riallineata a questo passo in un lavoro successivo. Qui solo ciò che serve perché non si rompa.
- Ritorno diverso dalla fine dell'ultima tappa (per esempio un viaggio notturno): fuori per ora.

**Anti-obiettivi**
- Uscire dal passo 1 senza meta o senza date.
- Snackbar di errore al posto degli aiuti vicino ai campi.
- Arancio fuori dall'azione principale. Unica eccezione ammessa: il tono tenue delle funzioni AI.
- Testi scritti nel codice o valori fuori dal design system. Valgono le stesse regole della tab Viaggi: dizionari it/en, token, componenti esistenti.

## 3. Ingressi

- **Foglio Crea, voce "Nuovo viaggio":** finché la valigia AI non è pronta, resta com'è oggi (titolo e sottotitolo attuali).
- **Stati vuoti della tab Viaggi:** il CTA "Nuovo viaggio" porta qui, come oggi.
- **Rotta:** resta `/new-trip`, con il tooltip dell'onboarding esistente intorno.

Quando l'AI sarà pronta (fuori da questo lavoro):
- il foglio Crea avrà la card "Prepara un viaggio con l'AI", nello stesso stile della scansione, per prima nella tab Viaggi e dopo la scansione nella tab Case;
- la voce attuale diventerà "Nuovo viaggio a mano".

## 4. Il passo 1

### 4.1 Struttura (dall'alto)

1. **AppBar:** "Nuovo viaggio" con la freccia indietro.
2. **Indicatore dei passi:** "1 Viaggio — 2 Valigia", neutro. Il passo attivo ha il cerchio pieno `onSurface`; il successivo ha solo il contorno; un passo fatto mostra la spunta. È un componente nuovo del design system (`DsSteps` o simile), perché lo userà anche il passo 2. Non ha arancio.
3. **Posto del bottone AI:** riservato sotto l'indicatore (posizione "2" del mock). Ora non si costruisce; vedi 4.7.
4. **"Dove vai?"** (vedi 4.2).
5. **"Quando?"** (vedi 4.3).
6. **"Itinerario"** (vedi 4.4).
7. **"Nome del viaggio":** campo già riempito con la meta. Sotto, "L'abbiamo preso dalla meta: cambialo se vuoi". Se l'utente cambia la meta e non ha mai toccato il nome, il nome segue la meta.
8. **In basso, fisso:**
   - `DsButton` primario "Avanti: prepara la valigia" (icona freccia);
   - sotto, `DsLinkButton` "Prepara la valigia più tardi".

I titoli di sezione sono domande in grande e grassetto, come nel mock. I campi usano la superficie dei gruppi (`context.groupSurface`) con bordo sottile.

### 4.2 "Dove vai?"

- **Un solo campo**, segnaposto "Una tua casa o una città". Spariscono la scelta "Altra località / Casa" e la sua spiegazione.
- **Toccandolo:**
  - compaiono subito "Le tue case" (tutte, in un gruppo, con l'icona di ciascuna);
  - scrivendo, sotto compaiono i luoghi della ricerca esistente (Geoapify, come `LocationAutocompleteField`);
  - scrivendo, anche le case si filtrano per nome.
- **Scelta una casa:** il viaggio ha `destinationHouseId`.
- **Scelto un luogo:** il viaggio ha `destinationLocation`, con nome, paese, latitudine e longitudine.
- **Dopo la scelta:** il campo mostra il nome con l'icona del luogo o della casa e una X per toglierlo.

### 4.3 "Quando?"

- **La domanda è sempre "Quando?",** sia qui sia nel foglio della tappa.
- **Senza altre tappe**, le date scelte sono andata e ritorno del viaggio.
- **Con altre tappe**, sono le date della prima tappa: la partenza è la partenza del viaggio, la fine è l'inizio della tappa successiva.
- **Il campo** mostra "gio 29 ott – dom 1 nov" e a destra le notti ("3 notti").
- **Il calendario** si apre in un **foglio dal basso** alto quasi quanto lo schermo, con "Conferma date" in fondo. Il contenuto è il calendario attuale di `TripDateRangeScreen` (scorrimento verticale dei mesi, selezione di un intervallo), estratto in un widget riusabile: non si riscrive. Lo stesso foglio serve nella tappa, dove si sceglie solo la fine e i giorni prima dell'inizio sono spenti. *(Deciso il 20/10: coerente con la ricerca e con il foglio della tappa, che restano sulla stessa schermata.)*

### 4.4 Itinerario e tappe

- **Prima di meta e date** c'è una riga di testo: "Scegli meta e date: qui compare il tuo itinerario."
- **Dopo**, in un blocco sulla superficie dei gruppi:
  - l'itinerario della cartolina (`TripItineraryView` con `buildItinerary`): Andata, luoghi con notti e periodo, Spostamento, Ritorno;
  - sotto, `DsLinkButton` "Aggiungi tappa";
  - sotto ancora, l'aiuto: "Visiti più città? Aggiungi una tappa per ognuna: avrai il meteo di ogni tappa."
- **Il ritorno si calcola da solo:** è la fine dell'ultima tappa. Non si sceglie e non si modifica a parte.
- **Ogni tappa parte dove finisce la precedente.** Il foglio "Nuova tappa" (che sostituisce il foglio attuale) chiede:
  - "Dove?": **la stessa ricerca di "Dove vai?"**. Al tocco mostra "Le tue case", poi scrivendo i luoghi. Una tappa può essere una casa o un luogo con coordinate. *(Deciso dall'utente il 20/10; da verificare a schermo se il foglio con l'elenco delle case rende bene.)*
  - "Quando?": l'inizio è fisso, la fine della tappa precedente; l'utente sceglie solo la fine.
  - Un aiuto calcolato: "Parti da Lisbona dom 1 nov. Il ritorno diventa mar 3 nov."
  - `DsButton` "Aggiungi tappa", attivo solo con luogo e fine scelti.
- **Ordine:** le tappe si aggiungono in coda. Toccando una tappa nell'itinerario si apre lo stesso foglio per modificarla o eliminarla (esiste già nel foglio attuale).
- **Coerenza delle date:** modificare la fine di una tappa sposta l'inizio della tappa successiva, che parte sempre dove finisce la precedente. Se una tappa resta con la fine non successiva all'inizio (zero o meno notti), sotto quella tappa compare un avviso in colore errore ("Sintra finisce prima di iniziare: controlla le date"). Finché c'è un avviso, le uscite sono bloccate come per i dati mancanti.

### 4.5 Dati obbligatori e uscite

- **Obbligatori:** meta (casa o luogo scelto dalla ricerca) e date. Il nome no: se vuoto, si salva la meta.
- **Le tre uscite** si comportano allo stesso modo:
  - "Avanti: prepara la valigia";
  - "Prepara la valigia più tardi";
  - in futuro, "Crea la valigia con l'AI".

  Salvano solo se i dati obbligatori ci sono e non ci sono avvisi sulle tappe.
- **Se manca qualcosa:**
  - il bottone principale appare spento e il link pure;
  - un tocco su uno dei due (`DsButton.onDisabledTap` e l'equivalente per il link) colora di errore i campi mancanti, con il messaggio sotto: "Scegli dove vai: serve anche per il meteo." e "Scegli andata e ritorno.";
  - lo scorrimento porta al primo campo mancante;
  - niente snackbar.
- **Il foglio "Nuova tappa"** ha la stessa regola: "Aggiungi tappa" solo con luogo e fine.

### 4.6 Salvataggio e dove si arriva

Il viaggio si salva come oggi (`TripNotifier.addTrip`, con `departureDateTime`, `returnDateTime`, meta, `legs`, nome, nessun oggetto, nessun bagaglio).

- **"Avanti: prepara la valigia":** salva e apre la pagina valigia del viaggio appena creato.
  - Finché la pagina nuova non esiste (descrizione del passo 2), apre `/trips/<id>/edit-items`, la pagina oggetti attuale.
  - Il passo 1 esce dallo stack: Indietro dalla pagina valigia porta alla tab Viaggi, sulla cartolina del viaggio nuovo, non al modulo.
- **"Prepara la valigia più tardi":** salva e porta alla tab Viaggi, sulla cartolina del viaggio nuovo (Prossimi, con la pila posizionata su quel viaggio).
- **Errore di salvataggio:** dialogo di errore con riprova esistente (`ErrorRetryDialog`). Il modulo resta compilato.
- **Uscita dal passo 1 senza salvare:** i dati si perdono, come oggi. Se il modulo ha dati, chiede conferma prima di uscire. *(Scelta mia: c'è già un dialogo di conferma del genere nel progetto? Altrimenti va aggiunto con i componenti esistenti.)*

### 4.7 Strada "con l'AI": posto e regole (non si costruisce ora)

- **Viaggio a mano:** sotto l'indicatore dei passi, un bottone sottile a tutta larghezza, nel tono tenue delle funzioni AI (lo stesso della card "Scansiona con AI"), con "Crea la valigia con l'AI ›". È la terza uscita: stessi dati obbligatori; salva il viaggio e avvia la valigia AI.
- **Viaggio con AI** (dal foglio Crea):
  - stesso passo 1;
  - indicatore "Viaggio — Valigia AI";
  - niente bottone in alto;
  - bottone principale "Prepara la valigia con l'AI" e link "Preferisco prepararla io".
- **Finché l'AI non è disponibile** per l'utente (funzione non attiva, quota esaurita, niente rete), il bottone in alto non c'è e il flusso con AI non è raggiungibile.

Il codice di questa parte arriverà con la valigia AI. Qui serve solo che il layout lasci il posto senza dover essere rifatto.

## 5. Dati

- **`TripLeg`** riceve quattro campi facoltativi:
  - `lat`, `lon` (double) e `country` (string), riempiti quando la tappa è un luogo scelto dalla ricerca;
  - `houseId` (string), quando la tappa è una casa. In questo caso `locationDisplayName` è il nome della casa al momento della scelta; il nome mostrato e le coordinate si leggono dalla casa al momento, come per `destinationHouseId`. Se la casa non esiste più, si usa `locationDisplayName`.

  Altri effetti di `houseId`:
  - `buildItinerary` e la cartolina devono risolvere il nome delle tappe-casa: una mappa id → nome, come fa già la tab Viaggi per la meta;
  - la logica "gli oggetti che porti compaiono come temporanei nella casa di destinazione" oggi vale solo per la meta: per le tappe-casa resta fuori da questo lavoro.
  - Le tappe sono già salvate come JSON nella colonna `legs` e viaggiano nella sincronizzazione così come sono, quindi niente modifica allo schema del database né al payload.
  - Le tappe vecchie, senza coordinate, restano valide: il meteo per loro mancherà.
  - Serve `build_runner` e un test di andata e ritorno JSON con e senza i campi nuovi.
- **La meta** salva già le coordinate in `destinationLocation` (`LocationSuggestionModel`, con `lat` e `lon`). Per una casa, le coordinate sono quelle della località della casa.
- **Case senza località:** il modulo della casa rende la località obbligatoria, ma la casa creata in automatico durante l'onboarding con l'AI nasce senza (`ai_import_notifier.dart`, `saveItemsOnboarding`). Un viaggio verso una casa così si crea lo stesso; il meteo per quella tappa non ci sarà.
- **Nessuna modifica** a `TripModel`, alle tabelle o alla sincronizzazione oltre a quanto sopra.

## 6. Cosa sparisce

- La scelta "Altra località / Casa" e il suo testo esplicativo.
- La barra arancio "1 di 2".
- Lo snackbar "Dai un nome al viaggio o scegli una destinazione".
- Il passo 2 attuale dentro il wizard (oggetti e bagagli), compreso il bottone "Crea viaggio (N)". La scelta degli oggetti si fa nella pagina valigia.
- In `add_trip_screen.dart` restano solo i pezzi riusati. `trip_info_form.dart` va ridotto o sostituito: lo usa anche "Modifica informazioni", che deve continuare a funzionare (vedi non obiettivi).

## 7. Verifica

- **Screenshot** (flusso `08-nuovo-viaggio`, chiaro e scuro):
  - vuoto;
  - tocco su "Dove vai?" con le case;
  - compilato con una tappa;
  - foglio "Nuova tappa" vuoto e compilato;
  - due tappe;
  - dati mancanti dopo il tocco sul bottone;
  - avviso su una tappa.

  Aggiornare `docs/ui-flows.md`.
- **Test:**
  - composizione di partenza, ritorno e tappe dai dati inseriti (prima tappa, tappe successive, ritorno uguale alla fine dell'ultima);
  - una modifica della fine di una tappa che sposta l'inizio della successiva;
  - avviso e blocco con zero notti;
  - blocco delle uscite senza meta o date, con i messaggi;
  - il nome che segue la meta finché non è toccato;
  - il salvataggio con coordinate di meta e tappe;
  - la navigazione dopo "Avanti" e dopo "più tardi";
  - il JSON di `TripLeg` con e senza coordinate.

## 8. Lasciato a chi costruisce

- Nomi e posizione dei file e dei widget nuovi.
- Come riusare o ridurre `trip_info_form.dart` mantenendo "Modifica informazioni" funzionante.
- Come la tab Viaggi si posiziona sulla cartolina del viaggio appena creato (indice iniziale della pila).

## 9. Scelte mie da controllare

1. Calendario in un foglio dal basso, con il contenuto del calendario attuale (deciso il 20/10).
2. Le tappe possono essere case o luoghi, con la stessa ricerca della meta (deciso dall'utente il 20/10).
3. Modificare la fine di una tappa sposta l'inizio della successiva; l'avviso compare se una tappa resta con zero notti.
4. Uscendo dal passo 1 con dati compilati si chiede conferma.
5. Finché non c'è la pagina valigia nuova, "Avanti" apre la pagina oggetti attuale.

## 10. Precisazioni (dopo la revisione)

1. **Il foglio "Nuova tappa" nuovo vale solo per il passo 1.** "Modifica informazioni" continua a usare `TripLegsSection` e il foglio attuale, invariati, finché non verrà riallineata. *(Scelta mia.)*
2. **Le date sono una catena.** Lo stato del modulo è la data di partenza più l'elenco ordinato delle tappe, ciascuna con luogo e fine. La prima tappa è la meta.
   - **Regole:**
     - la tappa *i* inizia alla fine della tappa *i-1* (la prima alla partenza);
     - il ritorno è la fine dell'ultima;
     - "Quando?" imposta partenza e fine della prima tappa.
   - **Aggiungere una tappa:** parte dalla fine dell'ultima, e il ritorno diventa la sua fine.
   - **Eliminare una tappa:** la successiva parte dalla fine della precedente e tiene la sua fine. Se era l'ultima, il ritorno torna alla fine della precedente.
   - **Cambiare una fine:** sposta solo l'inizio della tappa dopo. Se una tappa resta con zero notti o meno, compare l'avviso.
   - **Al salvataggio:**
     - `departureDateTime` è la partenza;
     - la meta è la prima tappa;
     - `legs` sono le tappe dalla seconda in poi, con `from` uguale alla fine della precedente e `to` uguale alla propria fine;
     - `returnDateTime` è la fine dell'ultima.

     È la stessa forma che `buildItinerary` legge già. La logica sta in funzioni pure, testate.
3. **Arrivo alla pagina valigia:** dopo il salvataggio si fa `context.go('/trips')` e poi `context.push('/trips/<id>/edit-items?from=new')`. Il parametro fa comparire l'indicatore dei passi nella pagina valigia. Indietro (o il salvataggio, che fa `pop`) riporta alla tab Viaggi. Vale anche partendo dalla tab Case: dopo aver creato un viaggio si finisce nei Viaggi, che è voluto. `EditTripItemsScreen` non si tocca.
4. **Il nome proposto è `tripDestinationName`:** nome intero della casa, altrimenti città, altrimenti il testo prima della virgola. È lo stesso della cartolina.
5. **Coordinate di una casa:** non si copiano nel viaggio. Il meteo le leggerà dalla casa al momento. Il test sul salvataggio delle coordinate riguarda luoghi e tappe.
6. **`TripLeg.locationDisplayName` resta il nome completo della ricerca,** come ora. `country`, `lat` e `lon` sono solo in più.
7. **Conferma d'uscita:** vale per la freccia dell'AppBar e per l'Indietro di sistema. Il modulo conta come compilato se c'è una meta, delle date, una tappa, oppure un nome cambiato a mano (il nome proposto non conta). Si usa il dialogo di conferma esistente del progetto, se c'è (`dialog_helpers.dart`).

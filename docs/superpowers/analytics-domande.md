# Analytics e Sentry: a quali domande devono rispondere

Decise con Davide l'8 novembre 2026. L'app è in produzione ma la usano al
massimo due persone. Il documento serve a scegliere cosa registrare prima che
arrivino utenti veri, e a non perdere il ragionamento dietro le scelte.

## Stato dei log (develop, #108)

- **Analytics:** ogni evento va a Amplitude e a Telegram Analytics
  (`tgram_analytics`), solo dopo il consenso (privacy e statistiche attive dal
  Profilo). Il gate sta in `lib/core/analytics/analytics_service.dart`.
- Il livello tipato è `lib/core/analytics/core_analytics_service.dart`, ma
  circa 30 eventi lo scavalcano con `logEvent('...')` diretto: login, tour,
  pagina valigia, kit, posti. Non esiste un elenco unico degli eventi.
- **Sentry** è attivo anche senza consenso (solo crash ed errori). Copre bene
  sincronizzazione, scan AI e generazione della valigia.

Cosa è rimasto indietro:

1. **Generazione della valigia AI quasi invisibile.** C'è solo
   `first_suitcase_generated` (una volta per dispositivo) più
   `kit_auto_added`. Non si contano valigie generate, durata e fallimenti.
2. **Casi previsti senza traccia.** Crediti finiti (429), armadio vuoto e
   armadio troppo grande sono esclusi da Sentry di proposito
   (`ai_packing_wait_screen.dart`), ma non diventano nemmeno un evento.
3. **Parti senza log:** meteo del viaggio (anche il tetto giornaliero), codici
   promo, scheda del capo dal nome (`item-metadata`), backfill dei metadati.
   Gli errori vanno solo in `debugPrint`, invisibili in produzione.
4. **Pagine viste solo per schermate, non per bottom sheet.** Col redesign
   molte cose sono passate in un foglio. Sentry non ha
   `SentryNavigatorObserver`, quindi nei report manca il percorso di
   navigazione.
5. **Eventi morti:** `bulk_template_toggled`, `bulk_gender_set`,
   `bulk_session_saved` sono definiti ma nessuno li chiama.
6. **Scan AI:** si contano i capi salvati, non quelli scartati, rinominati o
   collegati a "C'è già?".

Nota: `item_details_edited` manda una lista di stringhe (`fields`).
Telegram Analytics la accetta (ammesse liste di valori semplici), quindi è a
posto.

## Premessa: con due utenti le percentuali non dicono niente

Oggi i dati servono a tre cose:

1. **Accorgersi subito quando qualcosa si rompe.** Con pochi utenti ogni
   errore conta, e nessuno lo segnala.
2. **Ricostruire cosa ha fatto una persona.** Dopo il login la sessione è
   collegata all'utente: la storia di un singolo utente si legge, e con due
   tester vale più di qualsiasi grafico.
3. **Preparare il terreno per gli utenti veri.** I dati non si recuperano a
   posteriori: il percorso principale va strumentato adesso.

## Domande

Giudizi: **tenere**, **rimandare**, **scartare**. Tutte le "tenere" sono
approvate da Davide. Il nucleo sono le 6 segnate con ★.

### A. Il percorso principale: la gente arriva alla valigia?

| # | Domanda | Con cosa si risponde | Oggi | Giudizio |
|---|---|---|---|---|
| 1 ★ | Di chi apre l'app, quanti arrivano alla prima valigia, e dove si fermano? | Passi: apertura → login → consenso → prima casa → primi capi (scan o a mano) → primo viaggio → valigia generata → valigia salvata | Mancano "valigia generata" e "salvata" ogni volta | Tenere |
| 2 | Quanto tempo ci mette? (dall'apertura alla prima valigia) | Le date degli stessi eventi | Si ricava, niente da aggiungere | Tenere |
| 3 | Quanti capi ci sono nell'armadio quando si genera la valigia? | Proprietà sull'evento di generazione: numero di capi e quanti hanno metadati | Manca | Tenere |

La 3 conta perché dal bench sappiamo che con pochi capi, o capi senza
metadati, la valigia peggiora molto.

### B. La valigia AI è buona?

| # | Domanda | Con cosa si risponde | Oggi | Giudizio |
|---|---|---|---|---|
| 4 ★ | L'utente si fida della valigia, o la rifà? | Evento al salvataggio con i conteggi rispetto alla proposta: capi tolti, aggiunti dall'armadio, quantità cambiate (mai i nomi) | Manca | Tenere, priorità alta |
| 5 ★ | Quanto spesso la generazione fallisce, perché, e quanto dura? | Evento di fine generazione con esito (ok, crediti, armadio vuoto, armadio troppo grande, rete, errore) e durata | Errori veri in Sentry, il resto niente; durata solo come media sul telefono | Tenere |
| 6 | Gli avvisi "cosa manca" servono? | `slot_filled`, `slot_marked_to_buy`, `slot_bought`, eventi dei kit | C'è | Tenere; ricontrollare dopo #108 |
| 7 | La valigia viene usata davvero quando si parte? | Tracker della preparazione (`packing_progress_tracker.dart`) | C'è | Tenere |
| 8 | "Perché queste scelte" viene aperto? | Evento all'apertura del foglio | Manca | Rimandare: non cambia decisioni finché non c'è volume |

La 4 è il bench in produzione: il bench dice "valigia giusta" secondo i
giudizi di Davide, questo lo dice secondo le persone vere.

### C. Lo scan e l'armadio

| # | Domanda | Con cosa si risponde | Oggi | Giudizio |
|---|---|---|---|---|
| 9 ★ | Lo scan riconosce bene? | Al salvataggio: capi trovati, tenuti, scartati, rinominati, collegati a "C'è già?"; con l'editor dei tag anche i campi corretti | Solo "capi salvati" | Tenere |
| 10 | Si aggiungono capi con lo scan o a mano? | `create_sheet_choice` | C'è | Tenere |
| 11 | Quanti capi sono rimasti senza metadati? | Query sul database Supabase, non un evento | — | Scartata come evento; gli errori del backfill vanno in Sentry (F) |

Nella 9 un capo scartato è un errore dell'AI, uno rinominato un nome sbagliato.

### D. Costi e crediti

| # | Domanda | Con cosa si risponde | Oggi | Giudizio |
|---|---|---|---|---|
| 12 ★ | Quanti utenti finiscono i crediti, e dopo quanto? | Evento quando la generazione, lo scan o il meteo ricevono 429 | Manca | Tenere |
| 13 | Quanto costa un utente in AI? | Il conteggio dell'uso sul server | — | Scartata lato app |
| 14 | I codici promo vengono usati? | Evento di attivazione con esito (valido, già usato, scaduto, errore), mai il codice | Manca | **Tenere, decisione di Davide** |

La 12 conta perché chi finisce i crediti vuole usare l'app più di quanto gli
diamo: è il segnale più diretto per prezzi e tetti. La 14 era "rimandare";
Davide la vuole adesso per non dimenticarla.

### E. Gli utenti tornano?

| # | Domanda | Con cosa si risponde | Oggi | Giudizio |
|---|---|---|---|---|
| 15 | Chi ha fatto un viaggio ne crea un secondo? | Numero d'ordine del viaggio su `trip_created` | Solo `is_first_trip` | Tenere |
| 16 | Quanti utenti attivi al giorno o alla settimana? | — | — | Scartata |

La 16 è scartata perché un'app di viaggi si apre a ogni viaggio, non ogni
giorno. Con questa metrica un utente soddisfatto che viaggia quattro volte
l'anno sembra "perso" per mesi, e spinge ad aggiungere notifiche e motivi per
aprire l'app che non servono.

### F. Affidabilità (Sentry)

| # | Domanda | Con cosa si risponde | Oggi | Giudizio |
|---|---|---|---|---|
| 17 ★ | Quando qualcosa si rompe, me ne accorgo prima dell'utente? | In Sentry gli errori di meteo, `item-metadata`, promo, backfill; `SentryNavigatorObserver` per il percorso nei report | Falliscono in silenzio | Tenere, priorità alta |
| 18 | La sincronizzazione perde dati? | Sentry | C'è | Tenere |
| 19 | L'app è lenta? | Durata della generazione (domanda 5); avvio già misurato da Sentry sul 10% delle sessioni in prod | In parte | Rimandare il resto |

### Altre domande scartate

- **Quali schermate sono le più viste?** Col redesign metà delle cose sono in
  un foglio, quindi il dato è incompleto, e non porta a decisioni. Le pagine
  viste restano perché non costano nulla; non si investe per farci entrare i
  fogli.
- **Dove vanno in viaggio?** La destinazione è un dato sulla posizione. Se
  servirà, si usa il **tipo** di viaggio calcolato da Jev (mare, neve, città,
  trekking), mai il luogo. Rimandata.
- **Che capi hanno negli armadi?** Dato personale, già nel database. Nessun
  evento.
- **Il tour iniziale funziona?** Già misurato passo per passo; i tester
  conoscono già l'app, quindi oggi la risposta non sarebbe vera.
- **Ricerca, spazi, bagagli funzionano?** Funzioni secondarie, già con un
  minimo di eventi.
- **Età, genere, paese.** Il paese c'è già dalla lingua del telefono; il
  resto non serve e complica la privacy.

## Regole per gli eventi nuovi

- Mai nomi di capi, case, viaggi, luoghi o testo scritto dall'utente: solo
  conteggi, esiti, id generati dal client.
- Ogni evento nuovo passa dal livello tipato (`CoreAnalyticsService`), non
  da `logEvent` diretto.
- Valori ammessi da Telegram Analytics: stringhe, numeri, booleani e liste di
  questi. Niente mappe annidate.

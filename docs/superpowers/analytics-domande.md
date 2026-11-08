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

## Catalogo degli eventi (approvato da Davide, 8 nov 2026)

Il percorso di un utente nell'app, momento per momento. Sigle:

- **NUOVO**: evento che oggi non esiste.
- **ARRICCHITO**: esiste, si aggiungono proprietà.
- **C'È GIÀ**: resta com'è.
- **SPOSTATO**: oggi parte con `logEvent` diretto, passa al livello tipato
  con nome e proprietà identici (le serie storiche non si spezzano).

Decisione di Davide: **tutti** i ~30 `logEvent` diretti passano al livello
tipato in questo stesso lavoro, non dopo. Fase senza utenti: si raccoglie
tutto quello che segue, al massimo poi si spegne qualcosa.

### 1. Prima apertura, prima del login
- `app_opened` {trigger} — SPOSTATO. Inizio del percorso principale.
- `onboarding_started`, `onboarding_completed` — C'È GIÀ.
- `onboarding_page_viewed` {page_index, page_name}, `onboarding_skipped`
  {page_index} — SPOSTATO.
- `login_screen_viewed` — SPOSTATO.

Tutti dietro il gate del consenso, come oggi.

### 2. Login e consenso
- `consent_given` {policy_version} — SPOSTATO.
- `login_attempted` {method}, `login_completed` {method}, `login_failed`
  {method, reason | error_type} — SPOSTATO.
- `analytics_opt_in` / `analytics_opt_out` {enabled} — SPOSTATO.
- `logout` — C'È GIÀ.

### 3. Tour guidato
- `onboarding_step_viewed`, `onboarding_step_advanced`, `onboarding_closed`
  {step_name, step_index} — SPOSTATO (oggi in due file: orchestrator e
  trigger wrapper).
- `ai_onboarding_started`, `ai_onboarding_skipped` — SPOSTATO.
- `tour_completed` {skipped_ai, last_step_index} — SPOSTATO.
- `tour_relaunched` — SPOSTATO.

### 4. Casa e armadio
- `house_created` {house_id, is_first_house} — C'È GIÀ.
- `create_tapped` {tab}, `create_sheet_choice` {choice, tab} — C'È GIÀ.
  Domanda 10.
- `item_added` {item_id, house_id, item_category, is_first_item} — C'È GIÀ.
- `item_updated`, `item_deleted`, `item_bulk_deleted`, `item_bulk_moved`,
  `search_*`, `add_existing_match_tapped`, `space_created`,
  `luggage_created` — C'È GIÀ.
- `item_details_edited` {source: scan | house, fields} — C'È GIÀ.

Scan:
- `ai_input_submitted`, `ai_input_failed` {error_type} — C'È GIÀ.
- `ai_input_completed` {item_count, **photos**} — ARRICCHITO (K: foto per
  scan e capi per foto).
- `already_here_opened` — C'È GIÀ.
- `ai_items_saved` — ARRICCHITO (domanda 9, H). Proprietà:
  - `count` (salvati nuovi, c'è già), `is_onboarding`;
  - `found`, `excluded`, `linked`, `renamed`, `details_edited`;
  - `excluded_types`, `renamed_types`: sottocategorie dei capi scartati e
    rinominati.
- `ai_scan_doubt_resolved` — NUOVO (I, J). Uno per capo salvato con
  correzioni o con "?":
  - `doubt_fields`: campi col "?";
  - `chose_jev`: campi in cui l'utente ha preso la proposta di Jev;
  - `kept_gpt`: campi in cui ha tenuto GPT;
  - `other_value`: campi cambiati con un terzo valore;
  - `corrected_without_doubt`: campi corretti senza "?" (errori sfuggiti a
    GPT e Jev);
  - `sub_category`.

  Solo nomi di campi, mai valori. Da verificare dove la scheda dello scan
  mostra il "?" nel codice di oggi.

### 5. Viaggio
- `first_trip_started` — SPOSTATO.
- `trip_created` {trip_id, is_first_trip, **trip_number**,
  **days_to_departure**} — ARRICCHITO (domanda 15, L).
- `trip_updated`, `trip_deleted`, `trip_duplicated`, `trip_saved_toggled`
  — C'È GIÀ.

### 6. Valigia AI: generazione
`ai_suitcase_finished` — NUOVO. Parte alla fine dell'attesa, sempre.
Domande 1, 3, 5, 12; E, F, L, M.
- `outcome`: ok | credits | empty_wardrobe | wardrobe_too_large | network |
  error | cancelled. `error` va anche in Sentry come oggi.
- `duration_ms`
- `trip_id`, `nights`, `stops`, `is_regeneration`, `days_to_departure`
- `wardrobe_items`, `wardrobe_with_metadata`
- `wardrobe_by_category`: conteggi per categoria come proprietà piatte
  (`wardrobe_upper`, `wardrobe_lower`, `wardrobe_outerwear`,
  `wardrobe_shoes`…). Mappe annidate non ammesse da tgram.
- `proposal_items`, `slots_count` (valigie sospette anche se "ok")
- `setup_changed`: risposte cambiate dal giro precedente (activities,
  stays, washer, luggage), solo per le rigenerazioni.
- Contesto del viaggio (vedi sotto).

- `first_suitcase_generated` {slots_important, slots_proposed,
  slots_total, trip_items, from_first_run} — SPOSTATO. Resta: Amplitude lo
  usa per il ritorno a 1 e 7 giorni.
- `kit_auto_added` {kits, items} — SPOSTATO.

**Contesto del viaggio**, su `ai_suitcase_finished` e su
`ai_suitcase_changed` (idea di Davide: segmentare gli errori del generatore
per attività e clima; i tool filtrano bene per proprietà dello stesso
evento, male unendo due eventi):
- `activities`: id delle attività, uniti su tutte le tappe;
- `stays`: id degli alloggi;
- `washer`: lavatrice sì/no;
- `luggage_size`;
- `transports`;
- `temp_max_band`: fascia della massima più alta (<5, 5-15, 15-21, 21-26,
  >26). Il 21 è la soglia dei capi estivi, scelta dubbia da verificare;
- `temp_min_band`: fascia della minima più bassa;
- `rain_days`;
- `weather_source`: previsione | storico.

Mai la destinazione.

### 7. Valigia AI: l'utente la sistema
`ai_suitcase_changed` — NUOVO. Emesso dal provider dei viaggi
(`TripNotifier`), così copre tutte le pagine che modificano la valigia. Parte
solo se un conteggio cambia rispetto alla versione precedente. Domanda 4; A,
B. Proprietà:
- `trip_id`, `proposed`, `kept`, `removed`, `added`, `added_from_slots`,
  `quantity_changed`;
- `removed_types`, `added_types`: sottocategorie dei capi tolti e aggiunti;
- `quantity_up_types`, `quantity_down_types`: in che direzione cambiano le
  quantità (verifica la regola lavatrice 4+1);
- contesto del viaggio.

L'ultimo evento di un viaggio dice com'è finita.

- `ai_warning_dismissed` {code, level} — NUOVO (C). Avviso "cosa manca"
  scartato.
- `ai_slot_removed` {type, level} — NUOVO (D). Posto tolto senza
  riempirlo.
- `ai_item_reason_opened` {reason_code, sub_category} — NUOVO (G). L'utente
  apre il motivo di un capo: segnale di dubbio.
- `slot_filled` {level, copies}, `slot_marked_to_buy` {level, from},
  `slot_bought` {level} — SPOSTATO. Domanda 6.
- `kit_suggestion_accepted` {missing}, `kit_suggestion_dismissed`,
  `kit_use_learned` {kind}, `kit_created` {items, uses} — SPOSTATO.
- `items_added_to_trip` — C'È GIÀ.

### 8. Partenza
- `packing_started`, `packing_progress` {threshold}, `packing_completed`
  {trip_id, total_items, days_to_departure} — SPOSTATO. Domanda 7.

### 9. Tetti e crediti
- `ai_limit_reached` {feature: suitcase | scan | weather | item_name} —
  NUOVO. Domanda 12.
- `promo_code_redeemed` {outcome: redeemed | invalid_code | expired |
  exhausted | already_redeemed | too_late | too_many_attempts | failed,
  credits} — NUOVO. Domanda 14. Mai il codice.

### 10. Navigazione
- Pagine viste — C'È GIÀ. I fogli restano fuori.

### Sentry (domanda 17)
- `SentryNavigatorObserver` nel router: le ultime schermate in ogni errore.
- `captureException` per meteo, `item-metadata`, codici promo, backfill.
  Esclusi offline e tetti raggiunti (vanno solo nell'analytics).
- Sincronizzazione, scan, generazione — C'È GIÀ.

### Pulizia
- Tolti `bulk_template_toggled`, `bulk_gender_set`, `bulk_session_saved`.
- `CoreAnalyticsService` diventa l'elenco completo di cosa l'app registra,
  utile anche per la scheda privacy del Play Store.

## Avvisi su Telegram

tgram-analytics manda un messaggio quando arriva un evento scelto. Oggi
Davide ha l'avviso solo su `login_completed`. Avvisi utili in questa fase
(da impostare a mano da Davide nel pannello):
- `ai_suitcase_finished` con `outcome` = error (e forse anche gli altri
  esiti non ok);
- `ai_limit_reached`;
- `promo_code_redeemed`;
- `ai_input_failed`.

## Idee di prodotto nate da qui (non sono log, da discutere a parte)

- **Domanda dopo il viaggio** (N): al ritorno l'app chiede "Cosa non hai
  usato? Cosa ti è mancato?" spuntando dalla lista della valigia. Sarebbe la
  verità sul campo per il generatore.
- **Pollice su/giù sulla valigia** (O): voto rapido con motivi da elenco
  chiuso. Rimandato: prima vedere cosa dicono i fatti (A, B).
- **Promemoria meteo:** se si scopre (L) che la valigia si genera settimane
  prima, avvisare quando il meteo cambia.
- **Invito a completare l'armadio:** se si scopre (M) che le valigie
  brutte vengono da armadi incompleti.

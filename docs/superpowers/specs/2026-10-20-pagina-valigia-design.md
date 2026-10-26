# Pagina valigia (passo 2) · Design

Data: 20/10/2026 · Stato: approvato dall'utente (20/10/2026). **Il meteo (§4.2 e §5) passa alla PR successiva**, insieme alle fasce orarie: l'utente vuole prima discutere la gestione delle chiamate. In questa PR la pagina esce senza blocco Meteo. · Riferimenti visivi in `docs/superpowers/mock/viaggi/`:
- `valigia-meteo-chiaro.png` / `-scuro.png`: meteo nei quattro casi;
- `nuovo-viaggio-due-passi-chiaro.png`: bagagli e oggetti, ultime due schermate.

Il codice del mock (usa e getta) è in `new_trip_mock.dart.txt`: `PackMock`, `_WeatherSection`, `_WeatherDaysSheet`, `_TripSummaryLine`.

Va insieme a `2026-10-20-nuovo-viaggio-passo-1-design.md` (stessa PR).

## 1. Perché

Oggi la scelta degli oggetti di un viaggio vive in due posti:
- il passo 2 del vecchio wizard;
- "Modifica oggetti" (`edit_trip_items_screen.dart` con `trip_items_selector.dart`): pillole arancio delle case, filtri categoria, righe dense.

I bagagli si scelgono solo alla creazione. Il meteo, che ora arriva dal server (PR #35), non si vede da nessuna parte.

La pagina valigia è **una sola pagina** per preparare la valigia di un viaggio. Ci si arriva:
- subito dopo il passo 1 ("Avanti: prepara la valigia");
- dalla cartolina ("Prepara la valigia");
- dal dettaglio del viaggio ("Modifica oggetti").

In futuro sarà anche il punto d'arrivo della valigia AI. Mostra il meteo di ogni tappa, perché aiuta a scegliere cosa portare.

## 2. Obiettivi, non obiettivi, anti-obiettivi

**Obiettivi**
- Una pagina che sostituisce "Modifica oggetti", con riepilogo, meteo per tappa, bagagli e oggetti.
- Meteo per tappa: minima e massima medie e pioggia con il suo significato, da previsione o da storico. Per le previsioni, i giorni della tappa in un foglio.
- Salvataggio esplicito con "Fatto" e conferma se si esce con modifiche non salvate.

**Non obiettivi**
- **Fasce orarie del meteo:** PR successiva, con il suo mock.
- **La valigia AI:** chiamata, proposta, pagina dei risultati. Qui si riserva solo il posto.
- **Il dettaglio del viaggio:** checklist, intestazione, barra in basso. Resta com'è; cambia solo dove porta "Modifica oggetti".
- **Bagagli:** peso, capienza, gestione. Restano come sono.

**Anti-obiettivi**
- Arancio fuori da "Fatto" e dalle spunte di selezione (le spunte sono stati di selezione, ammessi dal kit).
- Un meteo che blocca la pagina: se non arriva, la pagina si usa lo stesso.
- Testi nel codice, valori fuori dal design system. Valgono le regole di sempre: dizionari it/en, token, componenti esistenti.

## 3. Ingressi e rotta

- **Rotta:** resta `/trips/:id/edit-items`, così chi la usa già non cambia. Il costruttore mostra la pagina nuova, e la vecchia `EditTripItemsScreen` sparisce.
- **Dal passo 1:** con `?from=new`, la pagina mostra l'indicatore dei passi "✓ Viaggio — 2 Valigia". Senza il parametro, l'indicatore non c'è.
- **Uscita:**
  - "Fatto" salva e fa `pop`;
  - Indietro con modifiche non salvate chiede conferma (dialogo esistente, `dialog_helpers.dart`);
  - dal passo 1 si torna alla tab Viaggi, come già fissato nel passo 1.

## 4. La pagina

### 4.1 Struttura (dall'alto)

1. **AppBar:** "Prepara la valigia".
2. **Indicatore dei passi:** solo con `from=new`; è il componente creato nel passo 1.
3. **Posto riservato alla valigia AI:** ora non si costruisce. Quando ci sarà, chi è nel flusso a mano vedrà in cima un invito a farsi proporre la valigia.
4. **Riepilogo in una riga** (non una card):
   - nome del viaggio in grande;
   - sotto "29 ott – 3 nov · 5 notti · Lisbona, Sintra";
   - a destra i giorni alla partenza ("-9 giorni") oppure "in viaggio", come il francobollo.
5. **"Meteo"** (4.2).
6. **"Bagagli"** (4.3).
7. **"Cosa porti"** (4.4).
8. **In basso, fisso:** `DsButton` primario "Fatto", che diventa "Fatto · 12 oggetti" quando ci sono oggetti scelti.

### 4.2 Meteo

**Il blocco**
- Un blocco sulla superficie dei gruppi, con una riga per tappa: la meta, poi le altre tappe in ordine.
- Ogni riga ha:
  - un'icona del tempo;
  - "Lisbona · 3 notti";
  - sotto, la pioggia;
  - a destra "16° – 23°" (minima e massima medie, arrotondate).
- Sotto il blocco, una riga che dice la fonte.

**I testi**
- **Previsione:**
  - pioggia: "Pioggia prevista 1 giorno su 3", oppure "Niente pioggia prevista";
  - fonte: "Previsioni di oggi, minima e massima medie. Tocca una tappa per i giorni.";
  - righe toccabili, con la freccia.
- **Storico:**
  - pioggia: "Di solito piove 1 giorno su 3", oppure "Di solito non piove";
  - fonte: "Media degli ultimi 5 anni in questi giorni. Le previsioni arrivano dal <data>.";
  - righe non toccabili.
  - La data è quella in cui la fine della prima tappa ancora su storico entra nell'orizzonte delle previsioni (`FORECAST_HORIZON_DAYS` del server).
- **Fonti diverse:** se alcune tappe sono a previsione e altre a storico, ogni riga usa il testo della sua fonte. Sotto il blocco si mostrano le due righe di fonte che servono.
- **Tappa senza meteo:**
  - casi: casa senza località, tappa vecchia senza coordinate, errore del server, limite giornaliero raggiunto;
  - icona barrata e "Meteo non disponibile per ora". La riga non è toccabile.
- **Caricamento:** le righe mostrano lo scheletro (componenti `skeleton` esistenti). Il resto della pagina è subito usabile.

**L'icona**
- Previsione: il gruppo di codice del tempo più frequente nei giorni della tappa (sole, poco nuvoloso, nuvoloso, nebbia, pioggia, temporale, neve). La mappa codice → icona e descrizione sta in un posto solo.
- Storico: dalla quota di giorni di pioggia. Sotto 0,2 sole; da 0,2 a 0,4 poco nuvoloso; sopra, pioggia. *(Scelta mia: lo storico non ha un codice del tempo affidabile.)*

**Foglio dei giorni** (solo previsione)
- Al tocco su una riga: titolo "Lisbona · meteo".
- Una riga per giorno della tappa: giorno ("gio 29 ott"), icona, "pioggia 20%", massima in grassetto, minima in secondario.
- In fondo: "Previsioni di oggi da Open-Meteo. Si aggiornano ogni giorno fino alla partenza."
- Se la tappa supera i 7 giorni dalla data di oggi, una riga avvisa che le previsioni lontane sono meno affidabili.

### 4.3 Bagagli

- Le pillole neutre del mock: contorno `outlineVariant`; quando scelte, superficie `surfaceContainerHigh`, contorno `onSurface` e spunta.
- Dati da `allLuggagesProvider`, come il vecchio passo 2.
- Senza bagagli registrati, una riga: "Non hai ancora bagagli" con il link "Aggiungi bagagli". Il link apre il foglio di gestione esistente (`showLuggagesManagementSheet`) per la casa mostrata in "Cosa porti". Al ritorno l'elenco si aggiorna, perché `allLuggagesProvider` viene già invalidato dal notifier dei bagagli.
- La scelta si salva con "Fatto", nel viaggio (`luggages`).

### 4.4 Cosa porti

- **Ricerca:** "Cerca negli oggetti" filtra per nome gli oggetti della casa mostrata.
- **"Da Casa Milano ▾":** apre `DsPickerSheet` con le case.
  - Predefinita: la casa principale (`defaultDestinationHouse`).
  - Se la principale è la meta del viaggio, la prima altra casa.
  - Se l'utente ha una casa sola, il selettore non apre niente e resta solo l'etichetta.
- **Gli oggetti:** quelli della casa, divisi per categoria, ciascuna con `DsGroupHeader` ("Vestiti · 7") e un blocco sulla superficie dei gruppi. Ogni riga ha la casella e il nome. Se l'oggetto è scelto, a destra c'è `QuantityStepper` con minimo 1 e massimo la quantità disponibile in casa.
- **Le scelte restano** quando si cambia casa: la selezione è del viaggio, non della casa mostrata. "Fatto · N" conta tutti gli oggetti scelti.
- **Oggetti già nel viaggio** (si arriva dalla cartolina o dal dettaglio):
  - partono spuntati con le loro quantità;
  - togliere la spunta li toglie dal viaggio al salvataggio;
  - quelli che vengono da una casa diversa da quella mostrata restano scelti e si vedono quando si passa a quella casa.
  - Un oggetto del viaggio che non esiste più in nessuna casa resta nel viaggio così com'è (snapshot) e non compare nell'elenco.
- **Casa senza oggetti:** `DsEmptyState` "Nessun oggetto in questa casa", con le stesse azioni dello stato vuoto attuale ("Scansiona con AI" e "Aggiungi a mano" per quella casa).
- **Casa proposta:** se l'utente ha una casa sola ed è la meta, si mostra quella.
- **Quantità:** lo stepper compare solo per gli oggetti con quantità disponibile maggiore di 1, come oggi. Per gli altri basta la casella.
- **Oggetti già in un altro viaggio:** nessuna differenza, come oggi (il selettore attuale non li distingue).

### 4.5 Salvataggio

- "Fatto" salva in un colpo solo oggetti (`items`, con quantità e `originHouseId`) e bagagli (`luggages`) con `TripNotifier.updateTrip`.
- Gli oggetti che erano già nel viaggio mantengono il loro snapshot, compreso `isChecked` (la checklist già avanzata non si perde): cambia solo la quantità, se modificata. Gli oggetti nuovi entrano con `isChecked` falso.
- Prima del salvataggio, gli oggetti vecchi senza `originHouseId` si normalizzano come fa oggi `edit_trip_items_screen` (`_normalizeItemOrigins`).
- Errori: `ErrorRetryDialog.executeWithRetry`, come oggi.
- "Fatto" senza oggetti è permesso: salva i bagagli e la cartolina resta su "Prepara la valigia".

## 5. Meteo: dati e chiamate

### 5.1 Server (`supabase/functions`)

- **`meteo()`, `CAMPI_PREVISIONE`, la cache e gli oracoli di `_shared/clima` non si toccano.** Il loro risultato finisce nel prompt di `pack-trip` ed è confrontato con gli oracoli generati dal bench. *(Scelta mia.)*
- **Solo `trip-weather`,** quando la fonte della tappa è la previsione, fa una seconda richiesta leggera al forecast di Open-Meteo con `weather_code`, `temperature_2m_max`, `temperature_2m_min` e `precipitation_probability_max` giornalieri. Ha una sua cache del giorno, con chiave e versione proprie.
- **La risposta di `trip-weather`** aggiunge `giorni_dettaglio: [{data, temp_max, temp_min, prob_pioggia, codice}]` e `codice_prevalente`. Costo: una chiamata in più per tappa al giorno verso Open-Meteo, solo per le previsioni e una volta al giorno grazie alla cache.
- **Compatibilità:** `pack-trip` e i suoi test non cambiano. I test esistenti devono passare così come sono; i nuovi test coprono la richiesta di dettaglio e la sua cache.
- **Pubblicazione:** la funzione aggiornata va ripubblicata a mano dall'utente. L'app deve funzionare anche con la funzione vecchia: senza `giorni_dettaglio`, righe non toccabili e icona dalla pioggia.

### 5.2 App

- **Chiamata:** `trip-weather` via HTTP, con lo stesso schema di `geocode-proxy`: JWT dell'utente e `apikey`. Una chiamata **per tappa** in modalità destinazione singola, con:
  - `data_inizio`: inizio della tappa;
  - `giorni`: dall'inizio alla fine della tappa, estremi compresi;
  - `destinazione`: nome, paese, latitudine, longitudine.

  *(Scelta mia: la modalità a tappe del server calcola le date in sequenza e non permette di saltare una tappa senza coordinate; le chiamate singole sì.)*
- **Coordinate:**
  - meta-luogo: da `destinationLocation`;
  - meta-casa e tappe-casa: dalla località della casa, letta al momento;
  - tappe-luogo: dai campi nuovi di `TripLeg` (passo 1).

  Senza coordinate, niente chiamata e riga "non disponibile".
- **Cache giornaliera:** l'app tiene il risultato di ogni tappa **per la giornata**, con chiave su coordinate, inizio, giorni e data di oggi, e richiama solo se la chiave cambia. Basta la memoria della sessione, senza tabelle né colonne nuove. *(Scelta mia: la persistenza tra un avvio e l'altro non serve per ora.)*
- **Riprova:** una riga "non disponibile" per errore di rete si può toccare per riprovare. Per il limite giornaliero raggiunto no.
- **Errori:**
  - rete o 5xx: riga "non disponibile";
  - 429 (limite giornaliero): stessa riga;
  - nessun messaggio bloccante.
- **Viaggi iniziati o finiti** (si arriva anche da "Modifica oggetti" del dettaglio):
  - una tappa già iniziata parte da oggi (meno giorni);
  - una tappa già finita non fa chiamate e non ha riga;
  - se nessuna tappa è nel futuro o in corso, il blocco Meteo non c'è.
- **Tappe fuori dai limiti del server** (più di 60 giorni, oltre i 730 da oggi, date mancanti): niente chiamata, riga "non disponibile".

## 6. Cosa sparisce

- `EditTripItemsScreen` e `TripItemsSelector`, insieme a quello che resta del passo 2 del vecchio wizard. Prima di eliminarli bisogna controllare chi altro li usa.
- Chiavi di traduzione non più usate: si tolgono se nessuno le usa più.

## 7. Verifica

- **Screenshot** (flusso `09-dettaglio-viaggio` per "Modifica oggetti", più il flusso del nuovo viaggio per il passo 2; chiaro e scuro):
  - pagina con il meteo a previsione;
  - foglio dei giorni;
  - meteo da storico;
  - una tappa senza meteo;
  - meteo in caricamento;
  - oggetti con scelte e quantità;
  - cambio casa con le scelte mantenute;
  - pagina aperta dal passo 1 con l'indicatore.

  Gli screenshot usano un meteo finto, senza rete. Aggiornare `docs/ui-flows.md`.
- **Test app:**
  - costruzione della richiesta per tappa (date, giorni, coordinate da luogo o da casa, tappa senza coordinate);
  - testi della pioggia e della fonte;
  - scelta dell'icona (previsione e storico);
  - foglio dei giorni solo con la previsione;
  - selezione mantenuta al cambio casa;
  - oggetti già nel viaggio spuntati;
  - quantità limitata dal disponibile;
  - salvataggio di oggetti e bagagli;
  - conferma d'uscita con modifiche;
  - funzione vecchia senza `giorni_dettaglio`.
- **Test server:** i campi nuovi presenti con la previsione e assenti con lo storico, la versione della cache aumentata, gli oracoli aggiornati.

## 8. Lasciato a chi costruisce

- Struttura di file, provider, repository e servizio del meteo, seguendo i pattern del progetto.
- Come mostrare gli oggetti già "in viaggio" e le quantità: la logica attuale va mantenuta.
- I gruppi esatti di codici del tempo per le icone, purché siano una mappa unica, con testi nei dizionari.

## 9. Scelte mie da controllare

1. La rotta resta `/trips/:id/edit-items`, e la vecchia pagina sparisce. "Modifica oggetti" del dettaglio apre la pagina nuova.
2. Una chiamata meteo per tappa, non una sola per tutto il viaggio. L'app tiene il risultato per la giornata, per non ripetere le chiamate.
2b. Il dettaglio dei giorni arriva da una richiesta separata della sola `trip-weather`, per non cambiare il generatore della valigia né i suoi test.
3. I giorni di una tappa vanno dall'inizio alla fine, estremi compresi: contano anche i giorni di viaggio.
4. Icona da storico calcolata dalla quota di pioggia.
5. La casa proposta per gli oggetti è la principale, o un'altra se la principale è la meta.
6. "Fatto" senza oggetti è permesso.
7. Avviso di affidabilità nel foglio dei giorni oltre i 7 giorni da oggi.

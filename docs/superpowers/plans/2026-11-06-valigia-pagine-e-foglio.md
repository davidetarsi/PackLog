# Valigia: pagine e foglio — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementare il flusso e i testi approvati della valigia, senza perdere dati, funzionalità o coerenza con l'app.

**Architecture:** `/trips/:id` resta la valigia canonica. La pagina delle necessità riusa azioni e componenti esistenti; la prima apertura dalla creazione ha un contesto di navigazione senza checkbox. Scritture nel provider attuale, senza nuovi stati persistiti né migrazioni DB.

**Tech Stack:** Flutter, Riverpod, Freezed, GoRouter, easy_localization; TypeScript solo per l'etichetta grammaticale di acquisto.

**Spec:** sezione Design concordato di questo documento, basata sui due mockup approvati. Piano e CTA iniziale Fatto approvati da Davide il 6 novembre 2026. Il precedente `docs/superpowers/valigia-ui-contratto.md` è marcato superato.

## Global Constraints

- Metodo già richiesto: un agente GPT-6 Luna alla volta per implementare un blocco, review del coordinatore prima del successivo; nessuna scrittura parallela.
- Un solo worktree. Branch corrente `codex/valigia-ui-coerente`, HEAD `329cc4f`, 17 file applicativi/test modificati prima del piano e non committati. Non cambiare branch o azzerare indiscriminatamente i file.
- Provider → Repository → DAO, un solo provider del viaggio. Snapshot TripItem e collegamento diretto dei bagagli come `ARCHITECTURE.md`, senza deviazioni.
- Nessun cambiamento di prompt, criteri, quantità o adeguatezza del generatore; niente nuove dipendenze o migrazioni. PR107 e gli altri punti della roadmap restano separati.
- IT/EN, token del design system, test corrispondenti quando esistono. Niente merge, deploy PROD o invii Telegram impliciti.

## Design concordato

**Mockup:** `/Users/davide/.codex/visualizations/2026/10/22/01a163d2-b523-7f23-9b96-4d1d998ed246/valigia-componenti-attuali.html` e `bottom-sheet-inventario.html` nella stessa directory. Sono riferimenti di design, non prove Flutter/device o inventari reali.

1. **Pagina principale:** riepilogo viaggio; card Cosa manca a questo viaggio con conteggi separati; Perché queste scelte; meteo; bagagli; I tuoi oggetti con ricerca e categorie. Riusare AiPackRows, relativo foglio dei motivi, PackWeatherSection con bordo PackLog/footer, PackPill, Gestisci bagagli, DsSearchField e aggiunta contestuale. Niente Dal tuo inventario ripetuto, selettore Rivedi/Checklist, o N di M pronti che includa le proposte.
2. **Prima apertura:** dopo la creazione AI il risultato è già salvato, niente checkbox e X per togliere gli oggetti. **CTA approvata:** Fatto con ritorno ai Viaggi, senza nuovo salvataggio o credito. Dalla cartolina l'esistente Continua a preparare apre poi la valigia con checkbox solo sui propri oggetti. La fase non va persistita nel DB; conservare tutte le spunte già salvate.
3. **Necessità:** la card apre una pagina dedicata, con tutte le categorie effettive, incluse Igiene/Elettronica quando presenti. Importanti con motivazione completa e azioni attuali. Suggerimenti con stella solo nel titolo, X a sinistra, nome, quantità/freccia a destra. X e apertura hanno hit area separate. Nessuna checkbox su proposte/acquisti.
4. **Da comprare:** dentro le rispettive categorie della pagina dedicata; nella principale resta solo il conteggio nella card. Conservare anche la vista generale della tab Viaggi. Riga X/nome/quantità/pulsante Comprato, Comprata, Comprati o Comprate secondo la fonte grammaticale esistente; fallback neutro Ho comprato se le informazioni non sono affidabili. Il pulsante apre il foglio per indicare l'oggetto reale; non inventa un oggetto né lo segna fisicamente nel bagaglio.
5. **Foglio:** conservare DsFormSheet, titolo con residuo, X, Da comprare, RapidFireInput e SlotWrittenRow. Ricerca secondaria inizialmente chiusa. Aprendola copiare il nome scritto nel Rapid Fire, separando le copie tramite il parser già presente, e mostrare subito i risultati. La ricerca è poi modificabile indipendentemente. Non presentare le corrispondenze come approvate dal generatore.
6. **Creazione e collegamento:** l'avviso sul nome esistente non blocca la creazione di un nuovo ID e non unisce record automaticamente. Collegare un esistente usa il suo ID, senza creare o modificare il record sorgente e senza contare nuovamente copie già nel viaggio. Riempimenti parziali scalano solo le copie aggiunte. Nessun secondo motore di adeguatezza o nuova chiamata AI.
7. **Completamento:** niente chiusura automatica. Restano le righe aggiunte, compare la conferma e i controlli sono sostituiti dalla CTA Chiudi; X sempre disponibile. Nessun secondo foglio Riapri. Chiusura anticipata conserva le aggiunte riuscite; un errore non scala copie e non dichiara successo.
8. **Integrità:** rimuovere dalla valigia non cancella dall'inventario; rimozione annullabile. Copie mancanti da comprare restano tali anche aprendo/chiudendo il foglio o dopo aggiunta parziale. Kit, quantità, motivi e rigenerazione esplicita devono restare utilizzabili eliminando la vecchia navigazione duplicata.

### Stringhe italiane esatte

| Posizione | Testo |
|---|---|
| Introduzione | La quantità che aggiungi viene scalata da quella richiesta. Puoi segnare da comprare ciò che manca. |
| Sopra il Rapid Fire | Aggiungi un nuovo oggetto. Verrà salvato nell’inventario e aggiunto alla valigia. |
| Sotto il Rapid Fire | Nessun testo permanente. |
| Accesso ricerca | Cerca nel tuo inventario |
| Spiegazione | Assicurati che l’oggetto sia adatto al viaggio. |
| Risultati / azione | Oggetti trovati / Aggiungi |
| Nessun risultato | Nessun oggetto con questo nome nell’inventario. |
| Avviso informativo | Attenzione, nell’inventario c’è già un oggetto con questo nome. |
| Esempio | Es. 2 t-shirt nere |
| Aggiunte | Aggiunte alla valigia |
| Completamento / CTA | Hai aggiunto tutte le copie richieste. / Chiudi |

Traduzioni in IT/EN, numeri con placeholder e plurali. Non concatenare frasi né dedurre il genere dall'ultima lettera del nome.

## Review Focus

1. Due viste sullo stesso trip: rimozioni/Annulla/kit/salvataggi ravvicinati non si sovrascrivono (Task 1 e 3).
2. Copie già nel viaggio o inventario modificato: nessuna seconda allocazione della stessa disponibilità (Task 2).
3. Nome già presente e quantità nel testo: avviso non bloccante, precompilazione e creazione con nuovo ID (Task 2).
4. Acquisto parziale, chiusura senza aggiunte, JSON vecchio: residuo e dati non si perdono (Task 2 e 4).
5. 320×640, testo 160%, tastiera/back: ultima riga raggiungibile, navigazione senza alterare le spunte (Task 3 e 5).

---

### Task 1: Recupero delle patch utili e salvataggi condivisi

**Files:** `lib/features/trips/view/trip_detail_screen.dart`; file modificati sotto `view/widgets/slots/`; `lib/features/trips/providers/trip_provider.dart`; test provider, `trip_detail_slots_test.dart` e `kit_suggestion_row_test.dart` sotto `test/features/trips/`.

**Interface:** `TripNotifier.serializeEdit(String tripId, Future<void> Function() operation) → Future<void>`. Le viste delegano runSuitcaseMutation a questa coda; i metodi di scrittura chiamati non vi rientrano. Nessun nuovo provider.

- [x] Salvare la patch precedente in build/recovery e rivedere gli hunk: recuperare scroll, freccia e salvataggi; togliere tab Rivedi/Checklist, titolo inventario e test che li impongono. Non usare restore indiscriminati.
- [x] Test RED: due chiamanti condividono il turno sullo stesso trip; un errore non blocca l'edit successivo. Conservare i casi Annulla→X, X oggetto→X proposta, rimozione→kit già riprodotti localmente.
- [x] Implementare la coda condivisa nel notifier; ogni modifica completa legge il trip corrente. Conservare bump updatedAt di rimozione/Undo e ricalcolo del piano kit prima del salvataggio.
- [x] GREEN: `flutter test test/features/trips/providers/ test/features/trips/view/trip_detail_slots_test.dart test/features/trips/view/kit_suggestion_row_test.dart`, format e analyze senza nuove segnalazioni.
- [x] Review del coordinatore e commit del blocco verde, escludendo file personali e patch di altri lavori.

### Task 2: Bottom sheet approvato

**Files:** `lib/features/trips/view/widgets/slots/{slot_fill_sheet,slot_fill_flow,slot_written_row}.dart`; `lib/features/trips/providers/trip_provider.dart` per i controlli di disponibilità; traduzioni. RapidFireInput solo se manca una callback necessaria.

**Interface:** conservare `onFill: Future<void> Function(TripItem)` per la creazione; aggiungere `onLinkInventory: Future<int> Function(TripItem)` per il numero di copie effettivamente collegate. Conservare `onToBuy: VoidCallback`. Usare il provider inventario della casa esistente, RapidFireInput.onTextChanged, parseCopies e matchesSearch; nessuna nuova classificazione.

- [x] Test RED in `test/features/trips/view/widgets/slots/slot_fill_sheet_test.dart`: ricerca chiusa; scrivere `2 T-shirt bianca`, aprirla e trovare il nome senza copie con risultati visibili; ricerca poi modificabile. Coprire anche la sintassi copie in coda già supportata dall'app.
- [x] Test RED: stesso nome mostra l'avviso esatto, invio ancora consentito e nuovo ID senza merge. Un esistente selezionato mantiene ID/record sorgente; copie già nel trip non riutilizzabili. Residuo 3 + aggiunta 2 → residuo 1.
- [x] Test RED: ultima aggiunta lascia aperto il foglio con conferma e Chiudi, senza timer o Riapri; chiudere prima/dopo conserva le scritture riuscite. Un errore di salvataggio non scala copie né mostra completamento.
- [x] Applicare struttura e testi dello Spec; ricerca facoltativa con selezione manuale, nessuna promessa di adeguatezza. Conservare il percorso Rapid Fire inventario→viaggio e la quantità reale creata; non tagliare silenziosamente copie eccedenti il residuo.
- [x] Rimuovere la scrittura anticipata che toglie toBuy in openSlot. Aprire/chiudere non modifica lo stato; aggiunta parziale conserva il residuo da comprare.
- [x] GREEN: test del foglio, `trip_detail_slot_fill_test.dart`, provider trip/to-buy; test Rapid Fire se modificato. Analyze/format, review e commit.

### Task 3: Pagina principale e necessità dedicate

**Modify:** `lib/core/routing/app_router.dart`; `lib/features/trips/view/{trip_detail_screen,pack_suitcase_screen}.dart`; `widgets/slots/{slots_section,trip_items_card}.dart`; `widgets/ai/ai_pack_rows.dart`; traduzioni.

**Extract to reuse:** `lib/features/trips/view/widgets/pack/pack_luggage_selector.dart` e `pack_inventory_search.dart`, spostando i componenti attuali senza ridisegnarli.

**Interfaces:** TripDetailScreen aggiunge `bool showNeeds = false` e `bool firstReview = false`; conservare tripId/initialSlotId. Nuova rotta `/trips/:id/needs`; parametro `review=1` per il primo risultato. PackLuggageSelector riceve selectedIds, onToggle(LuggageModel), onCreated(List<LuggageModel>); PackInventorySearch riceve houseId, excludedItemIds, onAdd(ItemModel, int copies) asincrono. Le callback rileggono il trip corrente nella coda Task 1.

- [x] Test RED: creazione AI porta a risultato con X e senza checkbox; Fatto torna ai Viaggi. Apertura normale dalla cartolina mostra checkbox solo sui propri oggetti e conserva isChecked. Nessun tab di modalità. Viaggi manuali, risultati legacy con slots null e valigia vuota conservano un percorso utilizzabile, senza accessi null o regressioni.
- [x] Test RED: card→necessità→ritorno conserva dati e modifiche. I deep link esistenti `?slot=<id>` da Da comprare aprono il foglio nella vista necessità. Chiudere e riaprire ritrova gli slot pendenti.
- [x] Realizzare ordine e componenti dello Spec. Estendere AiPackRows con callback/conteggi delle necessità riusando la presentazione e il foglio motivi. Conteggi per righe, non copie; acquisti non contati due volte.
- [x] Estrarre ricerca e selettore bagagli dalla pagina manuale per riusarli nella principale. Conservare quantità, creazione contestuale e accesso al foglio oggetto esistente; non perdere funzioni togliendo la CTA Modifica valigia nel flusso AI.
- [x] SlotsSection mostra solo importanti, suggerimenti e acquisti nelle categorie, senza propri oggetti, checkbox o barra dei pronti. Riusare lo stato vuoto esistente quando non resta nulla.
- [x] _adoptResult apre `/trips/:id?review=1` soltanto nel nuovo viaggio AI. Nessun nuovo salvataggio, credito o rigenerazione al passaggio di pagina/date. Flusso manuale e rigenerazione esplicita restano disponibili.
- [x] Test scroll a 320×640, 390×844 e 320×640 al 160%: ultima riga Igiene/Elettronica interamente sopra il footer; foglio con tastiera e stato completato. Conservare Builder sotto lo scope CTA, niente padding magici.
- [x] GREEN: `trip_detail_slots_test`, `pack_suitcase_screen_test`, `pack_suitcase_ai_mode_test`, `pack_suitcase_ai_flow_test`, `to_buy_screen_test`, `widgets/pack_weather_test` e test dei componenti estratti. Analyze, review e commit.

### Task 4: Righe e grammatica degli acquisti

**Files:** `widgets/slots/{proposed_slot_row,proposed_slots_card,to_buy_slot_row,trip_items_card}.dart`; `lib/features/trips/view/to_buy_screen.dart`; `lib/features/trips/model/ai_packing.dart`; `lib/features/trips/services/pack_trip_service.dart`; `supabase/functions/_shared/valigia/posti.ts`; traduzioni e test corrispondenti.

**Interfaces:** campo server additivo `comprato?: string`; AiSlot `String? boughtLabel`; parser compatibile se assente. Helper server `compratoPosto(capo, copie, lingua): string` usa la stessa voce di posti_nomi.ts usata da nomePosto, che mantiene la firma attuale. Cambia solo presentazione.

- [x] Test RED: X prima del nome, quantità/freccia a destra, nessuna stella sulle righe; X non apre il foglio. Acquisti con pulsante invece della freccia, anche con nomi lunghi a 320px.
- [x] Mostrare gli acquisti tramite `isOpen && toBuy` separati dalle proposte da valutare, qualunque sia il livello. Conservare la vista generale della tab Viaggi, con gli stessi dati.
- [x] Test grammatica: Costume→Comprato, Giacca→Comprata, Calzini→Comprati, Scarpe→Comprate; nomi invariabili/plurali obbligati dalla tabella esistente; EN Bought. Nessuna AI o deduzione dal nome libero.
- [x] Parser e round-trip JSON mantengono campo, residuo e stato di acquisto. Vecchi viaggi senza boughtLabel restano leggibili con fallback Ho comprato/Bought; dichiarare questo limite. Eseguire build_runner per il modello Freezed.
- [x] GREEN: `node --test supabase/functions/_shared/valigia/test/posti.test.ts`; test Dart modello/servizio, to-buy e card. Confrontare output di packing prima/dopo escludendo solo comprato: stessi ID, nomi, livelli, copie e selezioni; non rigenerare baseline per assorbire differenze inattese.
- [x] Analyze/format, review e commit. Pack-trip sarà la funzione da distribuire per il nuovo campo, con deploy separato autorizzato: nessun deploy automatico nel blocco.

### Task 5: Verifica integrata e consegna

**Files:** test già indicati; scenari pertinenti sotto `test/screenshots/`; stato del piano.

- [x] Provare creazione→risultato senza checkbox→necessità→collegamento/creazione/acquisto parziale→Chiudi→ritorno→Fatto→Viaggi→Continua a preparare→checkbox. Nessuna AI o consumo crediti per la navigazione.
- [x] Riprodurre salvataggi ravvicinati dalle due viste, Annulla e kit; riapertura dopo persistenza e parsing JSON. Tutte le spunte conservate, nessun oggetto sorgente cancellato.
- [x] Gate sequenziale: `dart format --set-exit-if-changed lib/ test/` → `dart analyze` → `flutter test` → `flutter test test/features/trips/`. Ogni fallimento interrompe il gate; niente successo dichiarato con nuove segnalazioni.
- [x] Screenshot del rendering Flutter in IT, light/dark e formato stretto. Android reale con tastiera/back e sync a due telefoni restano collaudi separati, non sostituibili con screenshot o test widget.
- [x] Committare solo file intended e documenti richiesti; se ignorati da *.md, forzare solo piano e contratto. Push feature e PR develop, verifica CI; nessun merge o avvio pipeline Telegram implicito.

## Handoff

Esecuzione autorizzata da Davide il 6 novembre 2026, inclusa CTA iniziale Fatto. Procedere per blocchi con Luna → review del coordinatore, conservando i punti di roadmap fuori scope. Stato e risultati di esecuzione nel ledger `.superpowers/sdd/2026-11-06-valigia-pagine-e-foglio/progress.md`.


## Decisioni di integrazione e limiti (7 novembre 2026)

- Collegamento dall’inventario: aggiungere al massimo il minimo fra copie richieste, disponibilità corrente e residuo corrente della necessità, riletti dentro la coda del viaggio. La ricevuta restituisce il numero effettivamente salvato. Le nuove creazioni Rapid Fire conservano invece tutta la quantità esplicita, purché ancora disponibile nella sorgente al turno di scrittura; se la disponibilità è cambiata, il collegamento fallisce senza troncarla e senza cancellare l’oggetto creato. Il costo è dover riprovare con la nuova quantità corrente. Se il dato cambia durante l’attesa, il collegamento può aggiungere meno copie di quelle inizialmente mostrate; le righe e il residuo devono riflettere il risultato reale. Le copie extra restano modificabili dal foglio dell’oggetto.
- Il primo rimedio contro una disponibilità obsoleta era rifiutare il collegamento. È superato dalla ricevuta delle copie effettive, che permette un collegamento parziale sicuro. Nessuna nuova logica di adeguatezza dei capi.
- In altezza molto ridotta, se il footer lascerebbe al contenuto meno di un target interattivo minimo, contenuto e footer scorrono insieme. Il titolo occupa al massimo due righe e la X resta nella testata. Testo e focus del draft sopravvivono al cambio di layout. Il costo è dover scorrere per raggiungere i controlli del footer nei fogli più stretti.
- Il residuo viene pubblicato dopo il salvataggio riuscito; la quantità modificata dal foglio attende l’esito e torna all’ultimo valore confermato in caso di errore. Il costo è un feedback subordinato al salvataggio locale. Aumentare le copie riapre soltanto la spunta della riga aumentata; aprire o cambiare vista non modifica le spunte.
- I salvataggi avviati dal Rapid Fire conservano container, identificativi e messenger dell’app: chiudere foglio e pagina non deve perdere il collegamento al viaggio. Se viaggio, richiesta o sorgente sono stati eliminati, mostrare l’errore e conservare l’oggetto già creato, senza ripristinare entità cancellate.

Collaudi ancora aperti: tastiera/back su Android reale e sincronizzazione fra due telefoni. Il rendering Flutter con inset simulato non li sostituisce. La postcard della lista Viaggi presenta overflow preesistenti a 320×640 con testo 160% (`postcard_parts.dart:157`, `trip_postcard.dart:51`): entrambi i sorgenti sono invariati rispetto alla base `329cc4f` e il difetto resta fuori da questa modifica.

Il campo grammaticale `comprato` richiede un successivo deploy di `pack-trip`, da autorizzare separatamente. Nel frattempo e per i vecchi risultati rimane il fallback neutro. Qualità del generatore, scansione di vestiti e precedenti punti di roadmap restano fuori da questa PR.

Review conclusa: la revisione indipendente ha riscontrato e fatto correggere sei difetti nel salvataggio/feedback. L’unico riesame ha confermato questi sei punti e trovato due delta circoscritti: controllo stock della nuova creazione e analytics del collegamento da Comprato. Il coordinatore li ha riprodotti con due test fallenti e corretti senza un altro giro di agenti. I due file completi interessati passano 69 test; 14 screenshot Flutter light/dark aggiornati passano. Nessuna variazione del design approvato.

Gate finale locale sulla versione consegnata: `dart format --set-exit-if-changed lib/ test/` (669 file, nessuna modifica), `dart analyze` (0 issues), `flutter test` (2.353 passati, 299 scenari opzionali saltati), conferma `test/features/trips/` (777 passati) e `test/features/items/` (373 passati). Tutti i comandi terminati con exit 0, in sequenza; nessun test disabilitato per assorbire un errore. Screenshot mirati: 14 passati, con viewport stretto e tastiera simulata dichiarati nel manifest.

Parità del packing: 150 configurazioni registrate (50 casi × 3 guardaroba), 1.317 etichette grammaticali aggiunte, output identico prima/dopo escludendo soltanto `comprato`; hash della proiezione `336a0736dbe9f3b47cf9768aa5e7f6080555b31d1378bd673c7435822ba92b23`. I 101 test Node del blocco grammaticale erano già verdi e quel backend non è stato modificato dalle correzioni finali. Questa prova non certifica una nuova qualità semantica del generatore e non sostituisce i precedenti benchmark ancora aperti.

Consegna sul branch `codex/valigia-ui-coerente`, PR verso `develop`. Esito live della CI da verificare sul commit pubblicato e riportare nella PR/consegna; nessun merge, deploy o invio Telegram incluso.

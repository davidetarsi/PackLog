# Valigia con AI: dal viaggio alla valigia generata

Data: 24 ottobre 2026. Decisioni di Davide prese in una sessione di design;
dove una scelta è di Claude è scritto "(scelta di Claude)".

Mockup interattivo: https://claude.ai/artifact/WoZJ5awxkzkFrRj4LeQQX5
(prima fila: il foglio; seconda fila: attesa e valigia generata). La variante
"a schede" del foglio è scartata.

## Perché

Il generatore di valigie è in produzione come Edge Function (`pack-trip`,
porting identico al bench), ma l'app non lo chiama: nel foglio Crea c'è la
riga spenta "Valigia con AI · In arrivo" e nella pagina valigia un'icona AI
grigia che mostra una snackbar. Questo progetto collega il generatore all'app.

Il generatore ha bisogno di dati che il viaggio normale non raccoglie
(attività, alloggio, lavatrice, bagaglio) e restituisce più di una lista
(avvisi su cosa manca, un motivo per ogni capo). La sfida è chiedere quei dati
con poco attrito e mostrare il risultato senza trasformare la valigia in un
report: la valigia deve restare "come fatta a mano".

## Obiettivi

1. Dal passo 1 del nuovo viaggio, l'utente può farsi preparare la valigia.
2. Le informazioni extra si chiedono in un solo bottom sheet, tappa per tappa
   quando le tappe sono più di una, perché le attività vanno legate al meteo
   della loro tappa.
3. La valigia generata arriva nella stessa pagina "Prepara la valigia" di oggi,
   modificabile come sempre, con due ingressi in più: "Cosa manca a questo
   viaggio" e "Perché queste scelte".
4. L'app non propone mai più pezzi di un oggetto di quelli salvati
   nell'armadio.

## Non obiettivi

- Unire la generazione a una valigia già iniziata ("completa quello che ho
  scelto"): `pack-trip` non accetta capi già scelti. È un'idea per dopo, da
  provare prima nel bench.
- Le etichette con "?" sui capi in dubbio (scan e aggiunta manuale): progetto
  separato, dopo questo.
- Regole del "caso peggiore" sull'alloggio (asciugamano in appartamento):
  il generatore oggi passa l'alloggio solo come testo a Claude; le regole vanno
  scritte prima nel bench.
- Contare le righe con quantità > 1 come più pezzi nel generatore
  ("T-shirt bianca ×3" = 3 pezzi): essenziale, ma lavoro del bench subito dopo
  questo progetto.
- Attività suggerite in automatico dal meteo o da Jev.

## Cose da non sbagliare (anti-obiettivi)

- **Mai quantità inventate.** I −/+ compaiono solo se l'oggetto ha almeno 2
  pezzi nell'armadio, e il massimo è il numero salvato. Vale nella pagina e
  nella scheda dell'oggetto, e vale per quello che arriva dal server.
- **Mai copiare in silenzio** le scelte di una tappa sulla successiva: una tappa
  nuova parte vuota.
- **Un solo arancio per schermata** (regola delle PR #26, #27, #48): nel
  foglio è "Prepara la valigia", nella pagina valigia è "Fatto". Pillole,
  interruttori e avvisi non sono arancio.
- La parola "capospalla" non compare mai nei testi per l'utente ("Giacche e
  cappotti", "giacca").
- Mai testo libero del modello nei motivi: solo il catalogo chiuso
  (`motivi.ts`), che `pack-trip` restituisce già.

## Il flusso

1. Passo 1 del nuovo viaggio, compilato (meta, date, tappe).
2. Alla fine del passo 1, accanto alla strada manuale, c'è "Prepara con AI".
   Apre il **foglio Valigia con AI**.
3. "Prepara la valigia" nel foglio salva le risposte sul viaggio e apre la
   **pagina d'attesa**, che chiama `pack-trip`.
4. Alla risposta si apre la **pagina valigia** (la stessa del passo 2) con la
   valigia già compilata.

Altri ingressi:
- **Foglio Crea**: la riga "Valigia con AI" si accende e porta al passo 1 del
  nuovo viaggio con l'intenzione AI già scelta (scelta di Claude: il builder
  può proporre altro se il passo 1 lo rende scomodo).
- **Icona AI della pagina valigia** (oggi grigia): diventa "Rigenera". Se la
  valigia è vuota genera; se no chiede "Vuoi sostituire la valigia?" e poi
  riapre il foglio con le risposte salvate.

### 1. Il foglio "Valigia con AI"

Bottom sheet con `StandardBottomSheetLayout`, come gli altri dell'app.

**In cima, valido per tutto il viaggio:**
- **Da quale casa prendi i vestiti**: pillole con le case dell'utente,
  preselezionata la casa di partenza se il viaggio la conosce, altrimenti la
  prima. `pack-trip` sceglie da una sola casa.
- **Con che bagaglio parti**: pillole con i bagagli dell'utente (vedi
  "Dipendenze": i bagagli diventano dell'utente, non della casa). Una sola
  scelta.

**Sotto, una tappa alla volta** (solo se le tappe sono 2 o più):
- Riga "Tappa 1 di 2 · Islanda" e barra a segmenti.
- Scheda meteo della tappa (icona, luogo, date, pioggia, minima/massima), dagli
  stessi dati di `trip-weather` già usati nella pagina valigia.
- **Cosa farai in <tappa>?**: 16 pillole a scelta multipla (elenco sotto).
- **Dove dormi in <tappa>**: Hotel, Appartamento, Ostello, Campeggio, Da amici
  o parenti. Una scelta.
- **C'è una lavatrice**: interruttore neutro, con sotto "Se c'è, porti meno
  vestiti".
- Dalla seconda tappa in poi, se la tappa è ancora intatta, c'è il bottone
  "Uguale a <tappa precedente>" (bordo tratteggiato) che copia attività,
  alloggio e lavatrice. Non c'è copia automatica.
- Il bottone in fondo è "Avanti: <prossima tappa>" e, nell'ultima tappa,
  "Prepara la valigia" (arancio, con l'icona AI). "Indietro" a sinistra dalla
  seconda tappa.

**Viaggio con una tappa sola**: niente stepper e niente scheda meteo; casa,
bagaglio, attività, alloggio e lavatrice in una sola pagina del foglio.

**Avviso finale, mai bloccante**: se al tocco di "Prepara la valigia" una tappa
non ha attività o alloggio, sopra il bottone compare "<Tappa> è ancora da
compilare. Ha un meteo diverso: vale la pena dirci cosa farai e dove dormi",
con "Uguale a <tappa compilata>" e "La compilo io" (porta a quella tappa). Un
secondo tocco su "Prepara la valigia" genera comunque.

**Pillole**: compatte, 32 dp di altezza, testo 14 (`labelLarge`), niente spunta.
Scelta = bordo e testo `onSurface` (bianco nel tema scuro), sfondo
trasparente; non scelta = bordo `outlineVariant`, testo grigio. Il contrasto del
testo non scelto resta sopra 4,5:1. L'area toccabile resta 48 dp
(`materialTapTargetSize` padded). La stessa regola (niente spunta) va estesa
alle pillole dei bagagli della pagina valigia, che oggi hanno la spunta.

**Le 16 attività** (etichetta → codice inviato al generatore; il viaggio salva
il codice):

| Pillola | Codice |
|---|---|
| Città e musei | `visite in citta` |
| Passeggiate ed escursioni | `escursioni leggere` |
| Trekking | `trekking` |
| Cammino | `cammino` |
| Alta montagna | `escursioni in quota` |
| Mare | `mare` |
| Immersioni e snorkeling | `immersioni` |
| Sci e neve | `sci` |
| Campeggio | `campeggio` |
| Lavoro | `riunioni di lavoro` |
| Cena elegante | `cena formale` |
| Matrimonio | `matrimonio` |
| Luoghi di culto | `visite a siti religiosi` |
| Serate e locali | `vita notturna` |
| Bicicletta | `bicicletta` |
| Terme | `terme` |

Una pillola può mandare più codici (scelta di Claude). "Immersioni e
snorkeling" manda `immersioni` **e** `mare`: `immersioni` da solo non è
riconosciuto come attività in acqua (`RADICI_ACQUA`), quindi il generatore
toglierebbe il costume; nel bench `immersioni` compare sempre insieme a `mare`
(Messico ed Egitto del v2/v3). "Cena elegante" e "Matrimonio" non stanno in
`ATTIVITA_FORMALI`, ma le regole formali li riconoscono per radice
(`RADICI_OCCASIONE_FORMALE`: "formal", "matrimon"; `RADICI_CERIMONIA`), quindi
vanno bene come sono. Il viaggio salva la pillola (un codice nostro), e la
traduzione in codici del generatore sta in un solo posto.

Elenco chiuso: l'utente non crea attività. Le regole fisse del generatore
scattano solo sulle parole esatte (`costanti.ts`: `ATTIVITA_ALL_APERTO`,
`ATTIVITA_FORMALI`, `ATTIVITA_CODICE_ABBIGLIAMENTO`, `ATTIVITA_RIVERBERO`;
"cammino" in `regole_capi.ts`), e tutte queste parole vengono dal vocabolario
del bench.

### 2. La pagina d'attesa

Pagina intera (la generazione dura 6-13 s). Icona AI, "Preparo la valigia",
"<Tappe> · N notti", tre passi che avanzano ("Guardo il meteo di …",
"Scelgo dal tuo armadio", "Controllo cosa manca"), "Di solito ci vogliono una
decina di secondi", "Annulla" in fondo. I passi sono a tempo, non legati a
eventi reali del server (scelta di Claude).

Errori di `pack-trip`, ognuno con il suo messaggio e un'uscita:
- 429: crediti AI finiti → spiega e rimanda al Profilo (codice promo).
- 422 "Wardrobe is empty" → "Questa casa non ha vestiti" con link
  all'aggiunta/scan.
- 422 "Wardrobe too large" → messaggio esplicito (max 400 capi).
- 502/503/rete → "Riprova", il credito è già restituito dal server sul 502.
- "Annulla" abbandona la richiesta; il viaggio resta con valigia vuota.

### 3. La pagina valigia generata

È `PackSuitcaseScreen`, non una pagina nuova. Cambia così quando il viaggio ha
una valigia generata:

1. **Sotto il titolo del viaggio, un gruppo di due righe:**
   - **Cosa manca a questo viaggio**: icona di avviso e numero degli avvisi in
     ambra (`warning` del tema, non `primary`), sottotitolo con i titoli degli
     avvisi. Se non ci sono avvisi la riga diventa "Non manca niente", grigia.
     Apre un foglio con un riquadro per avviso: livello (Importante/Utile),
     titolo, perché è legato al viaggio, cosa fare; bottoni "Cerca
     nell'armadio" (chiude il foglio e scrive la ricerca) quando ha senso, e
     "Ok, capito" (toglie l'avviso).
   - **Perché queste scelte**: neutra. Apre un foglio con un punto per motivo
     (titolo, frase, capi), dati di `perche` di `pack-trip`, nell'ordine del
     catalogo ("Tutti i giorni" per primo).
2. **Meteo**: com'è oggi.
3. **Bagagli**: com'è oggi, con il bagaglio scelto nel foglio già selezionato.
4. **Cosa porti**: la lista mostra **solo i capi in valigia** (decisione di
   Davide). La barra di ricerca diventa "Aggiungi dal tuo armadio" e cerca fra
   gli oggetti della casa che non sono in valigia; in fondo ai risultati
   "Nuovo oggetto". Il selettore "Da <casa>" non c'è: la casa è quella scelta
   nel foglio.
   - Riga: `PackItemRow` allargata con una modalità "solo in valigia"
     (niente casella; × a destra come nella PR #43; sotto il nome "Da indossare
     in partenza" quando il generatore lo dice; −/+ con `QuantityStepper` solo
     se l'oggetto ha almeno 2 pezzi, massimo i pezzi salvati, come fa già
     `PackItemRow`). Niente riga nuova da zero: la base resta
     `UniversalItemTile`/`PackItemRow`.
   - Tocco sul nome: la scheda dell'oggetto con in cima "Perché è in valigia"
     (etichetta e frase del motivo), la nota "Da indossare in partenza", la
     quantità con "Ne hai N nell'armadio" e "Togli dalla valigia".
   - Togliere (× o − sotto 1) mostra una snackbar con "Annulla".
   - **Avviso sotto "Cosa porti"** (riga grigia con icona "i", neutra):
     "Ho scelto i vestiti e l'essenziale per l'igiene. Il resto lo scegli tu:
     lo trovi in fondo alla valigia." Dice "e l'essenziale per l'igiene"
     perché il generatore aggiunge già da solo per nome spazzolino,
     dentifricio, deodorante, beauty case, ciabatte (`RADICI_SEMPRE`).
   - **Gruppo "Dalla casa · N oggetti"** in fondo alla lista (decisione di
     Davide, variante 3b del mockup): riquadro **chiuso di partenza**, con
     sottotitolo "Toiletries, elettronica e varie: li scegli tu". Aperto,
     elenca gli oggetti della casa che non sono vestiti e non sono già in
     valigia, ciascuno con "+ Aggiungi"; aggiunto, passa nella lista sopra
     (snackbar con "Annulla") e il gruppo cala di uno. Anche qui −/+ solo se
     l'oggetto ha almeno 2 pezzi nella casa, massimo i pezzi salvati (stessa
     regola dei vestiti). Se il gruppo è vuoto, sparisce.
5. **"Fatto · N oggetti"** arancio, come oggi.

Ogni capo tolto o aggiunto e ogni cambio di quantità rispetto alla proposta va
salvato come dato (servirà al profilo personale): cosa ha proposto l'AI, cosa
ha fatto l'utente. **Va su Supabase** (decisione di Davide), non solo sul
telefono: Drift in locale e sync come il resto. Formato e tabella al builder;
basta che sia legato al viaggio e al capo e che non blocchi il salvataggio.

**Valigia manuale**: la modalità "solo in valigia" vale per la valigia generata.
Per la valigia fatta a mano resta la lista di oggi con tutta la casa (scelta di
Claude, per non cambiare il flusso manuale in questo progetto; Davide ha detto
che la lista con solo i capi in valigia è "molto meno caotica", quindi
estenderla anche al manuale è un candidato per dopo).

## Lato server: `pack-trip`

Il generatore (`_shared/valigia/genera.ts` e il resto del porting) **non
cambia**: resta identico al bench e gli oracoli devono restare verdi. Le novità
stanno prima (ingresso) e dopo (uscita).

### Ingresso (`_shared/valigia/ingresso.ts`)

Ogni tappa può portare `alloggio` (testo) e `lavatrice` (bool) oltre a
`attivita` e `giorni`; vale anche per il viaggio a una tappa (che oggi usa
`destinazione` + `attivita` di viaggio). `bagaglio` resta di viaggio.
L'ingresso traduce in quello che il generatore conosce:

- **Lavatrice — regola dei 5 giorni**: `lavatrice = true` solo se nel viaggio
  non passano mai più di 5 giorni consecutivi senza una lavatrice, contando
  dall'inizio alla fine e usando i giorni delle tappe. Motivo: con la lavatrice
  il generatore porta vestiti per 4 giorni più un ricambio. Esempi: Islanda 5 gg
  hotel + Olanda 4 gg con lavatrice → sì; Islanda 7 gg + Olanda con lavatrice →
  no; una tappa sola con lavatrice → sì. Il 5 è una costante con un nome.
  "4+1" è nelle scelte dubbie del bench: la costante deve poter cambiare.
- **Alloggio**: una tappa → il suo valore; più tappe con lo stesso → quel
  valore; diversi → testo "hotel (Islanda), appartamento (Olanda)" per il
  prompt.
- Il formato vecchio (`lavatrice`/`alloggio` di viaggio) resta accettato.
- La regola dei 5 giorni va in un modulo con i suoi test `node --test`.

### Uscita

- `pack-trip` legge anche `items.quantity` (oggi seleziona
  `id, name, category, house_id, ai_metadata`).
- **Tetto**: dopo il generatore, nessun capo in valigia supera la quantità
  salvata (`null` = 1). Se il generatore ne chiedeva di più, nasce un avviso
  "Pochi <capo> per questo viaggio" negli avvisi della valigia, con quanti ne
  servirebbero e quanti ce ne sono. Il testo segue il tono degli avvisi
  esistenti; il codice dell'avviso è nuovo.
- La risposta resta compatibile: la UI legge `valigia` (ideali, essenziali,
  mancanti, …), `motivi.capi[i].motivo` e `perche`, senza ricalcolarli.

Il porting nel bench non va toccato per queste due cose: sono regole
dell'Edge Function, non del generatore. Il punto 43 della coda del bench
(quantità come pezzi multipli) resta separato.

## Dati

**Il viaggio salva le risposte del foglio**, così "Rigenera" non le richiede:
casa scelta, bagaglio scelto, e per ogni tappa attività (codici), alloggio,
lavatrice. Dove salvarle è del builder; due strade possibili:
- campi facoltativi nel blob JSON delle tappe (`trips.legs`, `TripLeg`: per
  scelta del progetto i campi facoltativi lì "non richiedono migrazione") più
  campi per la destinazione principale, che non è una `TripLeg`;
- una colonna JSON unica sul viaggio con tutto il "profilo valigia AI".

In ogni caso: Drift (oggi schema 10) e Supabase (`public.trips`) restano
allineati, la sync li porta, e le righe vecchie senza dati restano leggibili.

**La valigia generata** sopravvive alla chiusura dell'app: avvisi ("Cosa
manca", con quelli già chiusi con "Ok, capito"), motivi e proposta dell'AI si
salvano col viaggio e vanno **su Supabase** con la sync (decisione di Davide),
così si vedono anche su un altro telefono e restano per il profilo personale.

## Dipendenze

- **Bagagli dell'utente**: Davide ha in locale un lavoro che lega i bagagli
  all'utente e non più alla casa. Oggi `public.luggages.house_id` è
  `NOT NULL ... ON DELETE CASCADE` e Drift è allo schema 10: servono una
  migrazione Drift e una Supabase. Conviene fare in un solo passaggio di schema
  le migrazioni dei bagagli e quelle dei dati del foglio. Il codice di Davide
  sarà integrato prima dell'implementazione; il piano parte da lì.
- **Litri del bagaglio**: `pack-trip` vuole il bagaglio come testo; la
  capienza riconosce solo poche parole (`CAPIENZA`: tracolla, cabina, bagaglio a
  mano, zaino, trolley, valigia) più "N litri", e le regole del cammino leggono
  i litri. Con i tipi di oggi (scelta di Claude, da rivedere sul codice dei
  bagagli di Davide): `small_backpack` → "zaino da N litri" (o "zaino" senza
  litri), `cabin_baggage` → "trolley cabina", `hold_baggage` → "valigia
  grande", `custom` → nome del bagaglio più "da N litri" se noti. Se il lavoro
  sui bagagli porta tipi nuovi (per esempio zaino grande), la tabella va
  aggiornata.
- **Segreti e migrazioni (azioni di Davide)**: `pack-trip` usa
  `ANTHROPIC_API_KEY` (Claude Haiku 5.5, PR #45), `TYPESAFE_API_KEY` (Jev,
  facoltativo) e `OPEN_METEO_API_KEY` (piano commerciale da scegliere). La
  migrazione `20261020090000_generatore_valigie.sql` e quelle nuove vanno
  applicate al progetto Supabase.

## Lasciato al builder

- Struttura dei widget e dei provider, nomi dei file, chiavi delle traduzioni
  (IT ed EN, come il resto).
- Dove salvare le risposte del foglio (vedi "Dati"), purché sincronizzate.
- Formato del registro delle modifiche dell'utente alla valigia (su Supabase,
  vedi "Dati").
- Come mappare le zone/categorie del generatore sui gruppi della lista
  (l'app oggi raggruppa per categoria: Vestiti, Toiletries, Elettronica, Varie).
- Test: widget test per foglio e pagina, `node --test` per regola dei 5 giorni
  e tetto, scenari nuovi negli screenshot (`test/screenshots`).

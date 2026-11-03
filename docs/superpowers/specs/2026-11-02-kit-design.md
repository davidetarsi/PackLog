# I kit e la gerarchia della valigia — design

Data: 2 novembre 2026. Riprende il punto aperto "spazi e kit" (feedback di Leo, 1 novembre). Mockup: https://claude.ai/artifact/HkqmHNhBVUWTLHfPoABRm2 (schermate 1, 2, 2b, 3, 4, 5).

Due parti, in due rami separati:
- **Parte A, gerarchia della valigia:** piccola e solo nell'app. Va fatta per prima.
- **Parte B, i kit:** migrazione, app e funzione `pack-trip`.

## 1. Perché

- **Il bisogno di Leo.** Leo usa uno spazio chiamato "Kit Viaggio" (cuscino da aereo, coperta di seta, aux bt, power bank) per tenere insieme cose che partono insieme, e chiede "gli spazi sono tipo i gruppi?". Il bisogno è reale, ma gli spazi rispondono a un'altra domanda: dove sta una cosa.
- **La regola.** Uno **spazio** è un luogo fisico. Un **kit** è un gruppo logico di cose che vanno insieme, e un oggetto può stare in più kit.
- **Il premio.** La valigia mette il kit da sola quando il viaggio lo richiede, per esempio il kit Sci per un viaggio con l'attività sci.
- **La gerarchia.** Guardando i mockup, Davide ha visto che oggi la card dei proposti, col bordo a gradiente, richiama l'occhio più degli importanti. Deve valere il contrario.

## 2. Parte A — gerarchia della valigia

### 2.1 La regola dei colori (Davide, 2 novembre)

| Colore | Significato | Dove |
|---|---|---|
| Arancione (`primary`) | da fare | importanti e azioni |
| Gradiente (`PackLogGradientBorder`) | viene da PackLog | meteo, proposti, attesa |
| Giallo (`tertiary`) | proposto da PackLog | barra, legenda, scintilla |
| Neutro | tuo | oggetti dell'utente, kit compresi |

Nessun colore nuovo.

### 2.2 Cosa cambia (schermata 5 del mockup)

- **Barra delle origini** (`SuitcaseProgressHeader`): il segmento degli importanti da sistemare diventa arancione pieno, invece del fondo vuoto. Anche il pallino "N importanti da sistemare" della legenda diventa arancione pieno, invece del contorno grigio.
  - La barra sparisce come oggi, quando non restano importanti aperti, e torna "N di M in valigia". Davide l'ha confermato: le proposte non sono vincolanti, gli importanti sì.
- **Card importante:**
  - bordo sottile arancione;
  - etichetta "Importante" in arancione, invece di `onPrimaryContainer`;
  - "Aggiungi le tue" (l'etichetta del posto) resta un tasto di solo testo arancione;
  - "Da comprare" diventa un tasto di solo testo neutro (`onSurface`), con lo stesso peso.
  - Vale anche per la card aperta e per la riga "Importante · Da comprare".
- **Card dei proposti:** il bordo a gradiente resta, ma più sottile e più tenue di quello arancione dell'importante. La gerarchia deve leggersi così: prima l'importante arancione, poi i proposti. La scintilla gialla del titolo resta.
- **Meteo:** nessun cambiamento, il bordo a gradiente resta.

### 2.3 Vincoli

- Solo componenti, token e tema esistenti (`ds_*`, `design_system.dart`, `AppOpacity`, `AppMotion`). Niente colori, spessori o durate scritti a mano: se serve uno spessore di bordo nuovo, diventa un token.
- Widget piccoli e a una responsabilità, come in tutto il lavoro sui posti.

## 3. Parte B — i kit

### 3.1 Che cos'è un kit

- **Appartenenza:** un kit appartiene a **una casa** e contiene solo oggetti di quella casa.
- **Gli oggetti:** restano dove sono, nel loro spazio. Il kit li tiene insieme, e un oggetto può stare in più kit.
- **Le copie:** ogni oggetto del kit può avere un numero di copie ("Calzamaglia ×2"). Di base è 1.
- **Le pillole d'uso** dicono quando il kit entra da solo in valigia. Sono attività e mezzi di trasporto. Sono facoltative, e un kit senza pillole funziona lo stesso.
  - **Le attività** sono le stesse pillole del viaggio: stessi id del catalogo delle attività, niente tag solo per i kit.
  - **I mezzi** sono quelli nuovi del § 3.6.
- **Un oggetto cancellato dalla casa** esce anche dai suoi kit.

### 3.2 Nella casa (schermate 1, 2, 2b, 3, 4)

- **La riga dei kit** (schermata 1). Sotto le pillole degli spazi c'è una riga a parte, intitolata "Kit · cose che partono insieme".
  - Le card sono piccole, circa la metà di quelle del primo mockup: nome, numero di oggetti e pillole d'uso.
  - In fondo alla riga c'è "+ Kit".
  - La forma delle card deve essere diversa dalle pillole degli spazi, così non si confondono.
- **Dalla selezione** (schermate 2 e 2b). La barra della selezione diventa Sposta · **In un kit** · In viaggio · Elimina. "In un kit" **non** sta dentro "Sposta": spostare cambia dove sta una cosa, il kit no.
  - Il tasto apre un foglio dello stesso tipo di quello delle case, con il titolo "Metti N oggetti in un kit" e la frase "Restano dove sono: il kit li tiene insieme."
  - Sotto ci sono "Nuovo kit" e poi i kit della casa.
- **Nuovo kit** (schermata 3):
  - il nome;
  - la riga "Lo aggiungo da solo ai viaggi con… (facoltativo)", con le pillole delle attività e dei mezzi;
  - l'elenco "Nel kit", dove ogni oggetto ha le sue copie e una X per toglierlo.
  
  **Le pillole proposte dal nome:** mentre scrivi il nome, PackLog preseleziona le pillole che riconosce ("Sci" → sci, "Aereo" → in aereo), con la frase "«sci» l'ho scelto io dal nome: toccalo per toglierlo." Il riconoscimento avviene solo qui, una volta: il collegamento si salva nel kit, e la valigia non indovina più niente dal nome.
- **Aggiungere oggetti:** è lo stesso schema della pagina "aggiungi" della casa, non quello del viaggio. Il campo è il Rapid Fire ("Es. 2 t-shirt nere"), quindi scrivere vuol dire **aggiungere**.
  - Con invio, l'oggetto nasce nella casa ed entra nel kit, con le copie lette dal Rapid Fire.
  - Mentre scrivi, sotto "Già in casa" compaiono gli oggetti che corrispondono. Toccandone uno entra nel kit senza crearne uno nuovo.
- **Kit aperto** (schermata 4):
  - le pillole d'uso, con la provenienza di quelle imparate (§ 3.5);
  - gli oggetti, con le copie e lo spazio dove stanno;
  - "Aggiungi oggetti";
  - "Metti in valigia…", che sceglie un viaggio e aggiunge il kit a mano;
  - modifica del nome e delle pillole, e cancellazione del kit, che non cancella gli oggetti.

### 3.3 In valigia: come entra un kit

Gli oggetti del kit entrano **sciolti**: ognuno nel suo gruppo di categoria, come oggetti dell'utente, con le copie del kit. Nella lista non compare nessun gruppo "Sci". Contano come oggetti già scelti dall'utente, quindi riempiono i posti che l'AI avrebbe proposto e non generano proposte doppie.

Le strade sono tre:
1. **Da solo.** Il viaggio ha un'attività o un mezzo fra le pillole d'uso del kit. Il kit entra quando la valigia AI viene generata, in silenzio: niente riga, niente messaggio.
2. **Con una domanda.** Il generatore ha già preso almeno **metà** degli oggetti del kit, e comunque **almeno 2**, ma non tutti. Allora compare la riga del kit (§ 3.4). Se gli oggetti sono già tutti presi, non si chiede niente.
3. **A mano.** Con "Metti in valigia…" dal kit aperto, in qualsiasi viaggio.

**Più case:** un viaggio usa solo i kit della casa da cui parte.

### 3.4 La riga del kit in valigia (schermata 5)

**Posizione:** fra la barra e i gruppi. È una riga, non una card: niente sfondo, solo una linea sotto. Il colore è neutro, perché i kit sono dell'utente.

**Contenuto, su tre livelli:**
1. una pillola neutra con l'icona della scatola, "Kit Montagna"; accanto "3 su 5 già in valigia"; all'angolo una X ("No, grazie");
2. "Mancano K-way e Calzetti merino ×2", con i **nomi** degli oggetti che mancano. Davide li vuole esplicitamente, non "Aggiungi 2";
3. il tasto di solo testo arancione "Aggiungili in valigia".

**Comportamento:**
- Se più kit superano la soglia, la riga ne mostra uno solo, quello con più oggetti già presi. Il successivo compare dopo la risposta.
- **Aggiungi:** gli oggetti mancanti entrano in valigia, con lo stesso volo del Rapid Fire verso i loro gruppi, e la riga sparisce.
- **X:** la riga sparisce e per quel viaggio quel kit non viene più chiesto.
- La risposta si salva con il viaggio, così non si ripete dopo una sincronizzazione.

### 3.5 PackLog impara

Dopo **2 sì** alla domanda per lo stesso kit e la stessa attività o mezzo, nella stessa riga compare: "La prossima volta lo aggiungo da solo per il trekking?".
- **Sì:** la pillola si aggiunge al kit, e nel kit aperto si legge che è nata dall'uso.
- **No:** non si chiede più per quella coppia di kit e attività.

I conteggi si salvano **nel kit**, non in una tabella di preferenze dell'utente.

### 3.6 Il mezzo nel viaggio

Nel modulo del viaggio si aggiunge una domanda facoltativa con pillole a scelta multipla: **Aereo, Treno, Auto, Nave, Bus**. Vale per il viaggio intero, non per ogni tappa. Per ora serve solo ai kit. Il generatore non la riceve.

### 3.7 Testi

Tutti i testi nuovi vanno nei file di traduzione, in italiano e inglese. Quelli italiani sono le frasi citate in questo documento. Quelli inglesi li scrive chi costruisce, con lo stesso tono.

## 4. Non obiettivi

- **Profilo personale e registro delle modifiche dell'utente** (cosa toglie o aggiunge alla valigia): progetto separato, con il consenso da considerare.
- **Il generatore e il banco di prova:** il generatore non cambia e il confronto 888/888 deve restare identico.
- **Tag solo per i kit,** come "arrampicata". Se servono, si aggiungono come attività del viaggio, con un lavoro a parte sul generatore.
- **Trasformare da soli gli spazi in kit,** per esempio lo spazio "Kit Viaggio" di Leo: bastano tre tocchi con "In un kit".

## 5. Anti-obiettivi

- **Un gruppo "Kit" nella valigia:** gli oggetti entrano sciolti.
- **Kit nel foglio di "Sposta",** o kit che sembrano spazi.
- **Un quarto colore per i kit** (rosa, giallo o arancione): restano neutri.
- **Dialog per la domanda del kit,** e card pesanti che affollano la valigia.
- **Widget grandi che fanno tutto,** e colori, durate o testi scritti a mano.

## 6. Vincoli

- Flutter 3.38.5, Supabase. Le regole d'ambiente degli agenti sono in `/tmp/claude-1001/-srv-claude-workspaces-PackLog/a389a2f8-d273-43c6-b669-b6e7c79291e2/scratchpad/ds-piani/ambiente.md`.
- Nel codice non esiste ancora niente sui kit: modello, tabelle e pagine nascono da zero, sul modello di `spaces`.
- **La migrazione per i kit e il deploy di `pack-trip` li applica Davide.** Chi costruisce prepara il file e lo segnala.
- Le build vecchie dell'app non devono rompersi: `pack-trip` riceve i kit solo se l'app li manda.
- La sincronizzazione segue lo schema delle altre tabelle della casa, per esempio `spaces`: `user_id`, `house_id`, `is_deleted`, `sync_status`, `updated_at` e le regole di accesso (RLS).

## 7. Scelte di Claude (Davide può cambiarle)

1. **I dati:**
   - una tabella `kits` (nome, casa, pillole d'uso: attività e mezzi, conteggi imparati, risposte "no" alla domanda di imparare);
   - una tabella `kit_items` (kit, oggetto, copie).
   
   Il mezzo del viaggio si salva insieme alle altre risposte del viaggio, senza tabella nuova.
2. **Dove si decide quale kit entra:** in `pack-trip`, in un passo **dopo** il generatore e **prima** dei posti.
   - L'app manda i kit della casa di partenza.
   - La funzione aggiunge gli oggetti dei kit collegati (strada 1), così i posti li vedono come già scelti.
   - Calcola anche i kit sopra soglia (strada 2) e li restituisce con gli oggetti mancanti.
   
   Il generatore resta identico, mentre l'uscita di `pack-trip` cambia, quindi serve il deploy.
3. **I sì per imparare:**
   - si contano quando l'utente tocca "Aggiungili in valigia", una volta per kit e per viaggio, anche se la valigia viene rigenerata;
   - il conteggio va a ogni attività e mezzo del viaggio che il kit non ha già;
   - la domanda "La prossima volta…" però propone **una sola** pillola alla volta, la prima coppia che arriva a 2;
   - la X sulla riga del kit non conta come "no" per imparare: solo il "No" alla domanda "La prossima volta…" blocca quella coppia.
4. **Copie in valigia:** sono quelle del kit. Se l'oggetto è già in valigia con meno copie, si sale al numero del kit, senza sommare.
5. **Come gli oggetti del kit riempiono i posti:**
   - il passo dei kit sta in `pack-trip` dopo `generaValigia`;
   - `postiApp` riceve come ingresso nuovo gli oggetti aggiunti dai kit;
   - un oggetto del kit riempie un posto aperto con la stessa `sub_category`, oppure, se manca, con la stessa categoria e lo stesso tipo, e ne fa scendere le copie come fa il Rapid Fire;
   - `posti.ts` cambia, `generaValigia` no: il confronto 888/888 riguarda il generatore e resta identico;
   - la misura dei posti (`misura_posti.ts`) va rifatta, per vedere che senza kit non cambia nulla.
6. **Gli oggetti del kit in valigia:**
   - entrano come oggetti normali del viaggio, quelli dell'utente, non come oggetti AI con un motivo;
   - se il generatore aveva già preso lo stesso oggetto, resta una riga sola;
   - la risposta di `pack-trip` dice quali oggetti sono arrivati dai kit (strada 1) e quali kit sono sopra soglia con i loro mancanti (strada 2); l'app non ricalcola niente.
7. **La soglia:** conta gli oggetti distinti del kit, non le copie. Un oggetto conta come "preso" se è in valigia, anche con meno copie. Nella frase "Mancano…" compaiono solo gli oggetti assenti. Le copie si allineano da sole quando si accetta (scelta 4).
8. **Dove si salvano le risposte:**
   - la risposta alla riga del kit (aggiunto o X) vive nei dati della valigia AI del viaggio (`ai_packing_result`), come lo stato "tolto" dei posti;
   - una rigenerazione la azzera, come per i posti tolti: un kit rifiutato può essere richiesto di nuovo, e uno accettato rientra dalla strada 1 o 2.
9. **Il mezzo del viaggio:** è una colonna nuova di `trips`, con lista di valori, nella stessa migrazione dei kit, e si sincronizza con il viaggio. La richiesta a `pack-trip` riceve il campo `mezzi`, il generatore no.
10. **Sincronizzazione:**
    - `kit_items` ha anche lui `user_id`, `is_deleted`, `sync_status` e `updated_at`;
    - la cancellazione a cascata (oggetto o kit cancellato) la fa l'app, come per le altre tabelle;
    - per la coppia kit e oggetto c'è una sola riga: se un oggetto viene rimesso nel kit, la riga cancellata torna attiva.
11. **Limiti:** al massimo 50 kit per casa e 50 oggetti per kit. `pack-trip` scarta quello che li supera, come fa con `MAX_CAPI`.

## 8. Cosa resta a chi costruisce

- Come riconoscere le pillole dal nome del kit: sinonimi in italiano e inglese, sul catalogo delle attività e sui mezzi.
- Lo schema esatto delle tabelle e degli indici, e la forma JSON di kit in ingresso e in uscita da `pack-trip`.
- La struttura dei widget, purché piccoli e separati.
- Nomi degli eventi di analytics: kit creato, kit aggiunto da solo, domanda accettata o rifiutata, pillola imparata.

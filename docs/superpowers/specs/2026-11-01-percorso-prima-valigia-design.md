# Il percorso fino alla prima valigia — design

Data: 1 novembre 2026. Nasce dal feedback di Leo (sviluppatore e UX designer, ha provato l'app il 31 ottobre) e dal brainstorming con Davide del 1 novembre.

Mockup: https://claude.ai/artifact/UZm7aHL5nhL8T6YfPrssBN (tre schermate: la valigia di Leo a Seul con armadio quasi vuoto; il Rapid Fire toccando un posto proposto; la stima del meteo animata).

## 1. Perché

PackLog si vende come "l'app che ti prepara la valigia". Un utente è **attivo** quando ha visto una valigia generata per un suo viaggio: da lì ha capito il valore dell'app, e se dopo non torna c'è un problema.

Oggi la strada fino a quel momento passa dall'inventario, che è la parte più lenta e faticosa:

- dopo il login, il tour porta a importare oggetti con le foto, e molti utenti (Leo, e quelli che Davide ha osservato) le foto non le fanno;
- con un armadio vuoto o povero la valigia generata non mostra quasi nulla. Leo, viaggio a Seul a dicembre: nessun bagaglio, 17 avvisi "manca" su un'icona arancione, "Perché queste scelte" vuoto. Il momento "wow" diventa un elenco di mancanze.

L'onboarding si fa spesso da distratti, in treno o facendo altro. Ogni passo deve essere breve, capirsi da solo e potersi interrompere e riprendere.

## 2. Obiettivi

1. Dall'installazione alla prima valigia generata con il minor numero di passi, anche con l'inventario vuoto.
2. La prima valigia è **pronta da subito**: si vede piena e ordinata, non piena di buchi.
3. L'inventario si riempie **mentre si sistema la valigia**, con le cose vere dell'utente scritte da lui (Rapid Fire), non con oggetti inventati.
4. L'informazione che l'app dà non si perde: quello che serve e non si ha si può segnare "da comprare".
5. Le cose che fa PackLog (stima del meteo, proposte) sono riconoscibili e valorizzate, senza scavalcare le cose importanti.

## 3. Non obiettivi

- Ridisegnare l'import con le foto: resta com'è, solo non è più il primo passo.
- Spazi e kit logici ("Kit aereo"): punto aperto, si riprende dopo (vedi § 10).
- Oggetti a griglia con icone (blocco 4 del feedback di Leo).
- Il ridisegno completo dell'attesa "Preparo la valigia": qui entra solo il bordo animato (§ 6.4); il resto è del blocco 3.

## 4. Anti-obiettivi (sarebbe un fallimento anche se funziona)

- **Inventario sporcato:** oggetti generici ("Magliette") salvati nell'inventario senza che l'utente li abbia nominati. Davide non li vuole.
- **Valigia allarme:** una prima valigia fatta soprattutto di "manca", come quella di Leo.
- **Gerarchia invertita:** le proposte o il meteo più vistosi delle cose importanti.
- **Percorso obbligatorio lungo:** passi che l'utente deve completare prima di vedere una valigia, oltre a quelli del § 5.
- **Domande tolte che contano:** le attività e l'alloggio restano obbligatori, perché cambiano la valigia (decisione di Davide).

## 5. Il primo avvio

Ordine nuovo: onboarding (le slide di oggi) → login → **"Dove vai?"** → foglio della valigia AI → attesa → valigia.

- **Il tour delle foto esce dal primo avvio.** L'import con le foto resta dov'è nella casa, come uno dei modi per riempire l'inventario.
- **"Dove vai?"** è il passo 1 del wizard del viaggio di oggi (destinazione e date), presentato come prima schermata dopo il login.
- **Foglio della valigia AI:** quello di oggi (stepper per tappa).
  - **Attività:** obbligatorie come ora, senza "Salta".
  - **Alloggio:** si chiede sempre. Se la destinazione è una casa dell'utente, parte preselezionato su "Appartamento" (resta modificabile).
  - **Casa di partenza:** se l'utente non ha ancora **nessun oggetto** salvato, il foglio offre di crearla lì, con il nome già scritto ("Casa") e modificabile. Chi ha già una casa con almeno un oggetto la sceglie come oggi; per lui la creazione qui non c'è.
- Il resto del tour di oggi (i tip su casa e viaggio) si adatta a questo ordine o si toglie: decide chi costruisce, purché non aggiunga passi obbligatori prima della valigia.

## 6. La valigia fatta di posti

### 6.1 Il modello

La valigia generata è fatta di **posti**. Ogni posto è un bisogno del viaggio (per esempio "Maglioni caldi ×3", "Giacca invernale") e ha:

- **un livello**, che non cambia mai: **importante** o **utile**;
- **un contenuto**, uno di tre:
  - **tuo**: un oggetto vero dell'inventario (oggi: un capo in valigia);
  - **proposto da PackLog**: un oggetto generico con nome e copie ("Magliette ×5"). **Conta come pronto** ma **non entra nell'inventario**: vive solo nel viaggio;
  - **mancante**: nessun oggetto;
- **la segnatura "da comprare"**, facoltativa e indipendente dal livello.

Regole:

- **Chi diventa proposto e chi mancante:** un posto **utile** senza oggetti dell'utente diventa **proposto**; un posto **importante** senza oggetti diventa **mancante** (card, § 6.3). Gli importanti non si "danno per scontati".
- **Niente soglia sull'inventario:** un posto compare come proposto o mancante solo se nell'inventario non c'è nessun oggetto adatto. Con un inventario completo il generatore sceglie le cose dell'utente e i posti non compaiono; con uno vuoto compaiono ovunque; con uno a metà solo dove serve.
- **Da comprare:** si può segnare su un posto importante mancante o su un proposto. Il posto **resta del suo livello** (un cappello importante segnato da comprare resta importante), scende in fondo al suo gruppo con meno enfasi e compare nella vista "Da comprare" (§ 7). L'azione "Presa" apre il Rapid Fire come "Aggiungi il tuo".
- **Riempire un posto:** l'oggetto scritto dall'utente nasce nell'inventario della casa di partenza, **entra subito in valigia** con le sue copie, e il posto scende di quelle copie; a zero sparisce. Esempio: "Magliette ×5", l'utente scrive "2 t-shirt nere": nasce "T-shirt nera ×2", resta "Magliette ×3".
- **Persistenza:** i posti sono dati del viaggio, salvati su Supabase come gli altri dati della valigia (decisione del 24 ottobre: avvisi, motivi e proposta su Supabase), così si ritrovano su un altro telefono e dopo una pausa.

Scelte di Claude dopo la revisione (Davide può cambiarle):

- **Pezzi insufficienti:** se l'utente ha 2 magliette e ne servono 5, le sue 2 sono "tue" e nasce un posto per le 3 che mancano, proposto se utile, mancante se importante. Prende il posto dell'avviso "Ti servono più pezzi di…". Non viola la regola delle quantità del 24 ottobre: le copie proposte non stanno nell'inventario.
- **Rigenerare la valigia:** i posti proposti e mancanti si rifanno da capo. La segnatura "da comprare" sopravvive se nella valigia nuova c'è un posto dello stesso tipo, così la lista della spesa non si svuota per una rigenerazione. Gli oggetti nati riempiendo un posto sono oggetti veri e seguono le regole di oggi per i capi del viaggio.
- **Avvisi che non sono oggetti** (per esempio "Prevedi una lavanderia"): non diventano posti. Restano come una riga informativa sotto "Cosa porti", con il testo di oggi.

### 6.2 Cosa cambia nel generatore

Il bench è la specifica (regola di sempre): prima il bench, poi il porting in TypeScript con gli oracoli, 888/888 identici per i casi che non devono cambiare, misura prima/dopo, v4 sigillato solo aggregati, occhio all'overfitting.

- Oggi il generatore dà i capi scelti (`ideali`, `ripieghi`, `essenziali`) e i mancanti (`mancanti`, da cui l'app fa gli avvisi con testo fisso in `uscita.ts`). Deve dare, per ogni bisogno non coperto: livello, tipo, nome da mostrare, copie, motivo breve.
- **Proposte specifiche:** "Scarpe invernali", non "Scarpe". Se l'utente ha oggetti del tipo ma non adatti (scarpe da corsa a -7°), il motivo lo dice: "Hai le Scarpe da corsa, ma non tengono freddo e neve".
- **Livelli (Davide, 1 novembre):** è **importante** solo ciò che dipende da *questo* viaggio: freddo, pioggia, attività, occasioni (giacca invernale, guanti, K-way, scarponi, l'abito per il matrimonio). Le cose che servono in ogni viaggio (magliette, pantaloni, intimo, calzini, pigiama, igiene di base) sono **sempre utili**, quindi diventano proposte anche quando il generatore le dà per necessarie. Oggi `uscita.ts` segna importante ogni mancante "necessario" e ogni essenziale per freddo o acqua: con l'armadio vuoto quasi tutto sarebbe una card, cioè la "valigia allarme". Con la regola nuova un armadio vuoto dà poche card vere (4-5 nel caso di Leo a Seul) e il resto proposto.
- **Dogana delle Serate:** la revisione (livelli importante/utile/via degli avvisi) è un ingresso di questo lavoro. Scelta di Claude: un avviso segnato "via" non diventa un posto, né proposto né mancante.
- Il bench ha già `_ideali_mancanti_capo` (strumento del bench, non portato): da valutare come base.
- **Dove sta la regola (scelta di Claude):** la scelta dei capi non cambia, e gli 888 casi devono restare identici. I posti sono uno strato d'uscita come gli avvisi di oggi (`supabase/functions/pack-trip/uscita.ts`, che esiste solo in TypeScript), quindi si costruiscono e si provano in TypeScript. Il bench si usa per **misurare**: si aggiungono armadi vuoti e a metà, e si guarda quanti posti, di che livello e con che nomi escono sui viaggi di sviluppo. Se una regola dei posti richiedesse di cambiare la scelta dei capi, quella parte passa prima dal bench, come sempre.

### 6.3 Come si vede (mockup, prima schermata)

Gerarchia in tre altezze, ottenuta con peso, spazio e contrasto, **non con più arancio**:

1. **Importante mancante:** una card per posto, sopra nel suo gruppo. Piccola etichetta "Importante" con bandierina, nome, motivo in una riga, due azioni **testuali** "Aggiungi il tuo/la tua/i tuoi" e "Da comprare". Niente bottoni pieni.
2. **Fatto da PackLog:** la stima del meteo e le proposte. Bordo sottile con il **gradiente di PackLog** (arancio dell'app, ambra del tema, rosa caldo; niente blu e viola) e la scintilla piena dello stesso gradiente. Le proposte di un gruppo stanno in **una card** con l'intestazione "Proposti da PackLog · tocca per mettere i tuoi"; ogni riga ha scintilla, nome, copie e freccina. Nessuna etichetta per riga.
3. **Tuo:** la riga di oggi, con la casella.

- **"Cosa porti" (Davide, 1 novembre):** la barra ha due fasi, prima si organizza e poi si fa la valigia.
  - **Finché c'è almeno un importante da sistemare**, la barra conta i posti **pronti**: "13 di 18 pronti" (tue + proposte), con una legenda di tre voci: "4 tue", "9 proposte da PackLog", "5 importanti da sistemare". "Da comprare" non è una voce della legenda.
  - **Quando non ce ne sono più**, torna la barra di oggi: conta le **spunte** ("4 di 11 in valigia").
  - **Un proposto si può spuntare** (chi mette in valigia "Magliette ×5" senza nominarle deve poterlo segnare). La spunta resta nel viaggio e non lo porta nell'inventario.
  - **Un importante segnato "da comprare" resta da sistemare** finché non è preso: la barra resta su "pronti" finché c'è.
- **Meteo:** la scritta diventa "Stima" in grigio con la scintilla a gradiente; la card ha il bordo a gradiente.
- **"Perché queste scelte":** compare solo se ci sono motivi (già fatto nelle rifiniture, ramo `fix/rifiniture-leo`).
- **"Cosa manca a questo viaggio":** la riga separata in cima sparisce: gli avvisi diventano posti nella lista.
- Le etichette "Rendilo tuo" e simili non si usano (Davide).
- I colori sono provvisori; i valori finali li decide il design system.

### 6.4 Il movimento

Il bordo a gradiente **scorre** (un giro ogni ~6 s) e la scintilla "respira" **solo in due momenti**:

- quando la stima del meteo appare per la prima volta;
- durante la generazione della valigia (l'attesa "Preparo la valigia").

Dopo un paio di giri si ferma e resta colorato. Con le animazioni di sistema disattivate tutto è fermo. Le proposte non si muovono mai.

## 7. La vista "Da comprare"

Raccoglie i posti segnati "da comprare" di tutti i viaggi, con il viaggio di provenienza e il livello ("Importante" resta visibile). "Presa" apre il Rapid Fire e riempie il posto nel suo viaggio. L'inventario non contiene questi oggetti finché non vengono presi.

## 8. Rapid Fire: copie con il numero

Vale per ogni Rapid Fire (casa e posti):

- un numero **all'inizio** è il numero di copie: "2 t-shirt nere" → "T-shirt nere" ×2;
- in alternativa, numero **dopo una virgola**: "t-shirt nera, 2";
- niente "x2" (nomi di elettronica con la x, decisione di Davide) né "n";
- prima dell'invio compare la pillola "×2", che si tocca per annullarla (copre i casi come "2 in 1 caricatore");
- si scopre dal testo d'esempio del campo ("Es. 2 t-shirt nere") e da un suggerimento la prima volta che la pillola appare;
- un oggetto con N copie è **un** oggetto con N copie (regola delle copie del 29 ottobre).

**Dal posto:** toccando un posto proposto o "Aggiungi il tuo" si apre la barra del Rapid Fire in basso (quella che l'utente conosce, niente foglio nuovo) con un chip di contesto ("Magliette · 3 da personalizzare", con X per chiudere) e "Da comprare" a lato. Ogni invio stacca copie dal posto; la riga in lista si aggiorna sotto gli occhi. La chiamata per i dettagli (item-metadata) parte come per ogni oggetto del Rapid Fire. **La forma visiva di questa schermata va ancora sistemata con Davide** (§ 10): il comportamento sopra è deciso, l'aspetto no.

## 9. Misurare

L'app ha già Amplitude (`lib/core/analytics/`, con il gate del consenso). Eventi minimi:

- primo viaggio iniziato da "Dove vai?";
- prima valigia generata (il momento "attivo"), con il numero di posti per contenuto e livello;
- posto riempito, posto segnato da comprare, posto preso;
- ritorno nell'app dopo la prima valigia (giorno 1 e giorno 7).

Prima e dopo il lavoro: contare i tap dall'installazione alla prima valigia, con inventario vuoto.

## 10. Punti aperti (decisi di non deciderli qui)

- **La schermata del Rapid Fire da un posto proposto:** aspetto da sistemare in un giro dedicato con Davide.
- **Spazi e kit logici** ("Kit aereo"): dopo questo lavoro.

## 11. Cosa resta a chi costruisce

- Lo schema dati dei posti (tabelle Supabase e Drift, migrazioni) e come si collegano ai capi del viaggio.
- Come il tour attuale si adatta al nuovo ordine (§ 5), purché non aggiunga passi.
- I nomi degli eventi di analytics.
- I valori esatti dei colori, dentro il design system.

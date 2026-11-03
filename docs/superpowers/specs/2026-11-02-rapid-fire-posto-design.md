# Il Rapid Fire da un posto: aspetto e movimento — design

Data: 2 novembre 2026. È il punto aperto § 10 del design "Il percorso fino alla prima valigia" (`2026-11-01-percorso-prima-valigia-design.md`). Il comportamento di base è già costruito sul ramo `feat/prima-valigia`, ma l'aspetto non era ancora deciso. Mockup approvato: https://claude.ai/artifact/UZm7aHL5nhL8T6YfPrssBN, variante **B** ("Il posto sale in cima ai Proposti, il resto si spegne").

## 1. Perché

Toccando "Magliette ×5", oggi si apre in basso una barra con il chip "Magliette · 5 da personalizzare", e la valigia resta uguale. Davide si aspetta altro:
- vedere il posto che sta riempiendo e quante copie mancano;
- leggere una frase che dica cosa fare, cioè sostituire quelle copie con le magliette che ha davvero, scrivendole col Rapid Fire;
- vedere il numero scendere mentre scrive: "il riferimento a quelle 5 magliette diventa 3 magliette".

## 2. Obiettivi

1. Il posto che si sta riempiendo è il centro della schermata: si vede, si capisce cosa fare e il numero scende a ogni invio.
2. Il resto della valigia resta presente, ma non distrae.
3. I passaggi di stato (aprire, finire, chiudere) si vedono con un movimento breve, non con un cambio di colpo.
4. Gli importanti restano in vista finché l'utente non li sistema. Toglierli si può, ma mai per sbaglio.

## 3. Non obiettivi

- Spazi e kit logici: progetto successivo.
- Cambiare il generatore o la funzione `pack-trip`: questo lavoro è solo nell'app.
- Cambiare il Rapid Fire della casa: il campo resta lo stesso widget, `RapidFireInput`.

## 4. Anti-obiettivi

- **Disegni o emoji degli oggetti:** Davide ha scartato le sagome delle magliette, il riferimento sono il nome e le copie.
- **Componenti nuovi che duplicano quelli del design system,** e colori, durate o testi scritti a mano. Vale per ogni riga di questo lavoro (Davide, più volte): si usano DS, tema, `AppMotion`, `AppOpacity` e le stringhe in `assets/translations`.
- **Widget grandi che fanno tutto:** ogni pezzo deve essere piccolo e con una sola responsabilità, così che cambiare un'animazione dopo sia una modifica piccola e in un punto solo.
- **Gesti seguiti da un dialog.** Un gesto è per un'azione semplice, al massimo con "Annulla" nel messaggio.

## 5. La schermata (variante B)

### 5.1 Aprire un posto

L'utente tocca una proposta, per esempio "Magliette ×5", nella card "Proposti da PackLog" del dettaglio del viaggio.
- **Il posto sale e si apre.** La pagina scorre finché la card "Proposti da PackLog" del suo gruppo è in cima. La riga del posto sale in prima posizione dentro quella card e si apre, diventando un riquadro un po' più chiaro. Il riquadro contiene:
  - nome e copie che mancano ("Magliette ×3");
  - la frase: "PackLog ne propone 5. Scrivi qui sotto quelle che hai davvero, anche più di una insieme («2 t-shirt nere»): prendono il loro posto." Il numero è quello delle copie proposte all'inizio;
  - sotto, gli oggetti che l'utente ha già scritto per questo posto, con la loro riga e la casella.
- **Il resto si spegne:** tutto il resto della pagina resta visibile ma spento (`AppOpacity`). Sono spente anche le altre proposte della stessa card, la testata del gruppo, le altre card e le altre sezioni.
- **In basso** c'è la barra del Rapid Fire che esiste già, con il chip di contesto ("Magliette · 3" e la X) e "Da comprare" a lato.
- **Movimento:** scorrimento, salita, apertura e spegnimento sono un solo movimento breve, con le durate e le curve di `AppMotion`. Con le animazioni di sistema disattivate lo stato cambia senza movimento.
- Lo stesso succede per "Aggiungi il tuo" su una card importante e per "Presa". Un importante si apre nello stesso modo, ma resta nella sua posizione fra gli importanti del gruppo, non sale fra le proposte.

### 5.2 Mentre si scrive

Ogni invio del Rapid Fire:
- crea l'oggetto nella casa di partenza e lo mette in valigia, come già succede;
- fa scendere le copie del posto;
- fa comparire l'oggetto nella lista dentro il riquadro aperto.

Il numero cambia sotto gli occhi.

### 5.3 Copie finite, o "Da comprare"

- **La bolla:** il riquadro aperto "scoppia" e sparisce dai "Proposti da PackLog". È un'animazione breve di scala e dissolvenza, fatta con `AppMotion`.
- **Gli oggetti volano:** gli oggetti scritti dall'utente si staccano dal riquadro e scivolano fino agli oggetti dell'utente del loro gruppo, dove restano come righe normali.
- **Il resto si riaccende** e la barra del Rapid Fire si chiude.

Vale sia quando le copie arrivano a zero, sia quando l'utente tocca "Da comprare" su una proposta.

### 5.4 Chiudere con copie ancora da sistemare

Con la X del chip, con il tasto indietro o toccando fuori, quando restano copie, per esempio "Magliette ×3":
- **niente bolla:** il riquadro si richiude e la riga torna al suo posto fra le proposte, con le copie che mancano;
- **gli oggetti scritti** nel frattempo fanno lo stesso volo verso gli oggetti dell'utente, come in § 5.3;
- **il resto si riaccende** nello stesso movimento.

### 5.5 "Da comprare"

- **Proposta segnata da comprare:** esce dalla valigia, con la bolla, e vive solo nella vista "Da comprare". Non conta più nella barra, né fra i "pronti" né fra gli oggetti "in valigia". "Presa" nella vista "Da comprare" la riporta nella valigia per riempirla (§ 5.1).
- **Importante segnato da comprare:** resta in valigia come riga spenta ("Importante · Da comprare · nome", con "Presa"), come oggi. Resta "da sistemare" nella barra, secondo la regola di Davide del 1 novembre.

Questo cambia una regola del design del 1 novembre: là una proposta segnata da comprare restava in fondo alla sua card.

### 5.6 Togliere

- **Importante:** una piccola X in alto a destra della card, accanto all'etichetta "Importante". Toccandola si apre un dialog di conferma, con il dialog di conferma che il design system ha già:
  - titolo "Togli {nome}?";
  - testo "PackLog la considera importante per questo viaggio.", seguito dal motivo del posto se c'è;
  - azioni "Annulla" e "Togli".

  Dopo "Togli", il posto sparisce dalla valigia, dalla barra e dalla vista "Da comprare".
- **Proposta:** si toglie scorrendo la riga verso sinistra, senza dialog. In basso compare il messaggio "Tolta {nome}" con "Annulla", come quando si elimina un oggetto.
- **Rigenerare:** una rigenerazione rifà i posti da capo. Un posto tolto può ricomparire, perché la nuova valigia rifà i suoi conti.

## 6. Cosa cambia nei dati

- Un posto ha un nuovo stato, "tolto". Si salva con il viaggio come gli altri campi del posto, così l'"Annulla" e la sincronizzazione funzionano.
- **Barra e conteggi:** non contano più né i posti tolti né le proposte segnate da comprare. Gli importanti segnati da comprare restano "da sistemare".
- **Vista "Da comprare":** esclude i posti tolti.

## 7. Testi

Testi nuovi in italiano e inglese, nei file di traduzione, come stringhe dell'app:
- la frase del riquadro aperto;
- il dialog per togliere un importante;
- il messaggio "Tolta {nome}".

I testi esatti in italiano sono quelli di § 5.1 e § 5.6. Quelli in inglese li scrive chi costruisce, con lo stesso tono.

## 8. Scelte di Claude dopo la revisione (Davide può cambiarle)

1. **Gli oggetti nel riquadro aperto:**
   - sono quelli scritti durante questa apertura: è uno stato della schermata, non si salva;
   - mentre il riquadro è aperto non compaiono anche fra gli oggetti dell'utente (niente doppioni);
   - riaprendo il posto più tardi, la lista parte vuota, perché gli oggetti di prima sono già fra quelli dell'utente.
2. **"Presa" su una proposta da comprare:**
   - toglie il segno "da comprare" e apre il riquadro in cima ai proposti, come in § 5.1;
   - se si chiude con copie che restano, il posto resta fra le proposte della valigia e non torna nella vista "Da comprare".
3. **Lo stato "tolto":**
   - è un campo nuovo del posto, salvato dentro i dati della valigia AI del viaggio, senza migrazioni;
   - un posto tolto non è più "aperto" per nessun conteggio o elenco;
   - "Annulla" toglie solo questo segno: copie e "da comprare" restano com'erano;
   - con una rigenerazione un posto tolto può tornare, perché il segno non passa alla valigia nuova.
4. **Mentre il riquadro è aperto, il resto spento non si tocca:**
   - un tocco fuori dal riquadro chiude soltanto, senza aprire altro;
   - scorrere le altre righe non toglie nulla;
   - per portare in cima anche l'ultimo gruppo della pagina, la lista può aggiungere spazio in fondo.
5. **Dove vanno gli oggetti scritti:**
   - ognuno va nel gruppo della sua categoria, quella che il Rapid Fire gli ha dato, anche se è diversa da quella del posto;
   - se il gruppo non c'è ancora, compare;
   - un oggetto sommato a uno già presente vola una volta sola.
6. **Importante aperto con "Aggiungi il tuo":**
   - si apre la sua stessa card, nella sua posizione;
   - il contenuto del riquadro aperto è un solo widget, usato dentro la card dell'importante e dentro la card delle proposte;
   - mentre è aperta, la X per togliere è nascosta.
7. **Conteggi:**
   - la barra, la legenda, il numero nella testata dei gruppi e la vista "Da comprare" escludono i posti tolti;
   - la barra, la legenda e il numero nella testata dei gruppi escludono anche le proposte segnate da comprare.

## 9. Cosa resta a chi costruisce

- Come strutturare i widget, purché piccoli e separati: il riquadro aperto, la riga proposta, la bolla, il volo, lo spegnimento.
- Le durate e le curve esatte, prese da `AppMotion`.
- Come calcolare il punto d'arrivo del volo degli oggetti.
- I nomi degli eventi di analytics per "tolto", se servono.

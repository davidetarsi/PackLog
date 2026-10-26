# Scansione AI: ingresso più corto e risultati più chiari

Data: 2026-10-14 · Stato: approvato in brainstorming, da rivedere come documento

Terza parte della standardizzazione UI, dopo la navigazione e il dettaglio casa (flusso A). Riguarda il flusso numero 1 dell'app, aggiungere oggetti con la scansione AI: come ci si arriva e la pagina dei risultati. È la strada che vogliamo far prendere: le foto danno agli oggetti i metadati (tipo, colore, fantasia, calore, formalità) che serviranno alla valigia automatica.

Mock di riferimento: branch locale `mock/ai-results` (codice usa e getta) e screenshot `mock-ai-risultati` da `test/screenshots/mock_ai_results_test.dart`.

## Problemi di partenza

- Dal tasto Crea alla galleria passano cinque passi; la pagina "Scegli fino a 5 foto di outfit" non aggiunge niente rispetto al foglio Galleria/Fotocamera che segue.
- Nei risultati un cestino rosso per ogni capo: l'elemento più visibile della pagina.
- L'AI ricava tipo, colore, fantasia, ma la riga mostra solo il nome.
- Non si capisce abbastanza che il nome si può cambiare (l'utente rinomina sempre i capi per riconoscerli).
- Miniatura della foto piccola, riga vuota tra i gruppi.
- In basso tre elementi (casa, Salva, X) e due uscite con significati diversi (freccia = torna a scegliere le foto, X = esci senza salvare).
- Nessun modo di sapere, durante la scansione, se un capo è già in casa.

## Decisioni

### 1. Ingresso

- Dalla card "Scansiona con AI" del foglio Crea, dal bottone AI della casa e dalla CTA dello stato vuoto della casa si apre **direttamente il foglio Galleria / Fotocamera** sopra la schermata corrente. Scelte le foto parte l'analisi e si va ai risultati.
- La pagina "Scegli fino a 5 foto di outfit" resta solo nel tour iniziale, dove spiega cosa sta per succedere.
- Un solo punto di codice apre la scansione (una funzione condivisa), usato da tutti gli ingressi.

### 2. Pagina dei risultati

- **Intestazione:** "3 capi identificati", sotto "Tocca un nome per chiamarlo come vuoi tu", sotto la **casa di destinazione** come testo, "In Casa Milano ▾" (tocco → scelta della casa, stesso schema della card AI del foglio Crea). In onboarding la riga della casa non c'è (la casa la crea il tour).
- **Gruppi per foto:** intestazione con la **foto intera più grande** (angoli `cardBorderRadius`, tocco → foto a schermo intero) e l'etichetta grigia "Foto 1 · 2 capi" (singolare "1 capo"), nello stile di `DsGroupHeader`. Niente righe vuote tra i gruppi.
- **Riga del capo:**
  - a sinistra una **casella, spuntata in partenza**; togliendo la spunta il capo non si salva (nome e dettagli si spengono al 38%) e si può rimettere;
  - il **nome** seguito da una **matita grigia** (`Icons.edit_outlined`, `iconSizeSm`); tocco sul nome o sulla matita → campo di testo sul posto;
  - sotto, una riga grigia con **2-3 caratteristiche** lette dall'AI: "T-shirt · bianco · tinta unita" (tipo, colore, fantasia);
  - a destra **"C'è già?"** in grigio, solo se la casa di destinazione ha già oggetti della stessa categoria.
- Niente cestini: la casella sostituisce l'eliminazione.
- **Barra in basso:** un solo bottone largo, arancio, che dice cosa succede: "Salva: 3 nuovi", "Salva: 2 nuovi · 1 aggiornato", "Salva: 1 aggiornato". Spento se non c'è niente da salvare.
- **Uscita:** in alto a sinistra la **X** al posto della freccia. Se ci sono capi spuntati chiede conferma ("Scartare i risultati?"); poi torna alla casa come fa oggi la X in basso. Il tasto indietro di Android fa lo stesso.

### 3. "C'è già?"

- Foglio **informativo**, titolo "C'è già in Casa Milano?", sotto il promemoria "Dalla foto: T-shirt bianca · T-shirt · bianco · tinta unita".
- Oggetti della casa della stessa categoria in due gruppi: **"Più simili"** aperto (nome che contiene il tipo, il colore o una parola del nome letto dall'AI, ordinati per quante parole coincidono) e **"Altri <categoria>"** chiuso finché non lo si tocca. È solo un ordinamento: l'app non dichiara mai un doppione.
- Accanto ai capi **già scansionati** (con metadati AI) un piccolo ✨ grigio.
- Riga d'aiuto in fondo, grigia: "Se c'è già, togli la spunta per non aggiungerlo".
- Si chiude con la X o toccando fuori. **Nessuna azione obbligatoria.**
- **Unica azione: "Aggiungi i dettagli"**, solo sulle righe dei "Più simili" **salvate a mano** (senza metadati AI). Toccandola:
  - i metadati della scansione vengono copiati sull'oggetto esistente (che non ne aveva: nessun conflitto);
  - il capo scansionato non si aggiunge come nuovo;
  - nella pagina dei risultati la riga perde la spunta e mostra "Già in casa: «Jeans blu» · dettagli aggiunti", con "Annulla" al posto di "C'è già?";
  - il bottone diventa "Salva: … · 1 aggiornato".
- Niente unione tra due capi già scansionati (due letture AI possono dare valori diversi e non sappiamo quale sia giusta) e niente "+1": la quantità si cambia dalla scheda dell'oggetto.

### 4. Analisi ed errori

Restano come oggi (barra di avanzamento, errore di rete, scansioni esaurite, errore parziale con "Riprova"), allineati al kit dove li si tocca: errore in `errorContainer`/`onErrorContainer`, stati vuoti dal template `DsEmptyState`.

## Analytics

- `already_here_opened` (`{has_manual_candidates}`): il foglio "C'è già?" è stato aperto, e se c'era almeno una riga arricchibile.
- `already_here_details_added`: "Aggiungi i dettagli" toccato.
- `trackAiItemsSaved` resta e prende in più `updated` (oggetti arricchiti) accanto al conteggio dei nuovi.
- Servono a capire se "C'è già?" si usa: se dopo qualche mese non si apre, si toglie.

## Modello e salvataggio

- Lo stato dei risultati (`AiImportState`) tiene, per ogni capo, se è **incluso** (casella) e l'eventuale **oggetto collegato** per l'arricchimento. Oggi l'esclusione cancella il capo dallo stato (`deleteItem`): diventa un flag, così la spunta si può rimettere.
- Il salvataggio inserisce in blocco i capi inclusi e non collegati (come oggi, con `aiMetadata`) e aggiorna in blocco gli oggetti collegati scrivendo `aiMetadata` solo dove era vuoto (mai sovrascrivere).

## Rimandato (fase successiva, dopo design e valigia AI)

- Ritaglio del singolo capo dalla foto (riquadri chiesti al modello) e miniature per oggetto salvate e sincronizzate. Stime: ritaglio ~1-2 giorni, costo AI trascurabile, da provare prima sulla qualità dei riquadri di gpt-4o-mini; miniature salvate + sync ~4-7 giorni (schema 10, bucket Supabase, cancellazioni).
- Aggiornare un capo già scansionato con una foto migliore.

## Fuori da questo lavoro

Prompt e modello del proxy, limite delle scansioni, schermata del tour iniziale (salvo il fatto che resta l'unico posto con la pagina "Scegli fino a 5 foto").

## Verifica

- Test di widget: ingresso dal foglio Crea e dalla casa apre subito Galleria/Fotocamera; casella che esclude e reinclude; matita che apre il campo; riga delle caratteristiche; "C'è già?" visibile solo con oggetti della stessa categoria; foglio con "Più simili" aperto e "Altri" chiuso; "Aggiungi i dettagli" solo sulle righe senza metadati; riga collegata e testo di "Salva"; X con conferma.
- Test del notifier: salvataggio di nuovi + aggiornati, `aiMetadata` mai sovrascritto.
- Screenshot del flusso `06-import-ai` rigenerati e confrontati col mock.
- `dart analyze` pulito, suite verde, prova sull'app con foto vere.

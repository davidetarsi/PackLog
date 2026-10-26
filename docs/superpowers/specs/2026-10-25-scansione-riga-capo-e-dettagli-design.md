# Scansione AI e scheda oggetto: riga del capo e dettagli a tag

Data: 2026-10-25 · Stato: approvato nella conversazione, da rivedere come documento

Mock di riferimento in `docs/superpowers/mock/scansione/` (locale): `risultati-v3-chiaro.png`, `scheda-tag-v3-chiaro.png`, `scheda-tag-v3-scuro.png`, codice in `mock-v3.diff.txt`. La foto dei mock è quella finta dei test (un quadrato con fondo disegnato): con una foto vera si vede solo lo scatto.

## Perché

Dopo la scansione l'utente vede ogni capo con una riga di caratteristiche in parte in inglese ("graphic", "solid", "Socks") e non può correggere quello che l'AI ha letto: il colore sbagliato di una maglia, l'uso "montagna" mancante su dei pantaloni tecnici. Alcuni di questi dati (tipo, calore, impermeabilità, formalità, usi) sono quelli che il generatore della valigia legge: correggerli migliora la valigia. Il colore non cambia la valigia ma serve all'utente per riconoscere i capi.

Da quando anche le aggiunte a mano (scheda oggetto e Rapid Fire) passano da `item-metadata` (Haiku + Jev) ogni oggetto ha i suoi metadati: non esiste più il caso dell'oggetto "da arricchire".

## Obiettivi

- Riga del capo nella scansione più leggibile e con un ingresso chiaro alla modifica completa.
- Una sezione "Dettagli" a tag nella scheda oggetto unica, per i vestiti, uguale dalla scansione e dalla casa.
- Tutto in italiano, dai dizionari.
- Un solo componente pillola di scelta nel design system, usato qui e nel foglio "Valigia con AI".

## Fuori da questo lavoro

- Il prompt e il modello di `item-metadata` (la tassonomia resta quella del 19 ottobre).
- Rifare la scheda quando l'utente rinomina un oggetto (non si rifà: le correzioni dell'utente restano).
- Miniature per oggetto e ritaglio dei capi dalla foto.

## 1. Pagina dei risultati della scansione

- **Foto del gruppo:** la foto intera, alta circa 160 dp (`context.responsive`), allineata a sinistra con le card e i testi della pagina, angoli `cardBorderRadius`, **senza fondo** attorno. Tocco → foto a schermo intero (come oggi). Sotto la foto l'etichetta del gruppo "Foto 1 · 2 capi" (`DsGroupHeader`), poi la card dei capi.
- **Riga del capo:**
  - a sinistra la casella (come oggi e come nella valigia);
  - **nome** più grande (`titleMedium`, semibold) con la matita grigia: tocco sul nome o sulla matita → rinomina sul posto (come oggi);
  - sotto, la **riga dei dettagli** più grande (`bodyMedium`): solo **tipo · colore**, in italiano, seguiti da "›". Tocco → si apre la scheda oggetto con i dettagli (§3). La fantasia non si mostra più;
  - se Jev ha dei dubbi su qualche campo, una riga in più sotto i dettagli: icona "?" e "1 da controllare" / "2 da controllare" (`onSurface`);
  - a destra **"C'è già?"** come oggi (stesse regole di comparsa).
- La casella spenta spegne anche la riga dei dettagli e quella dei dubbi (38%), come il nome.

## 2. "C'è già?"

- Resta com'è (foglio informativo, "Più simili" aperto, "Altri <categoria>" chiuso).
- **Si toglie l'azione "Aggiungi i dettagli"** e tutto quello che le serve: collegamento di un capo a un oggetto esistente, riga "Già in casa · dettagli aggiunti" con "Annulla", "· 1 aggiornato" nel bottone Salva, salvataggio con arricchimento in blocco, evento `already_here_details_added`. Il foglio aiuta solo a decidere se togliere la spunta.

## 3. Scheda oggetto: sezione "Dettagli"

La scheda è quella unica (crea / modifica). La sezione compare **solo per i vestiti** con metadati (`aiMetadata` presente e categoria di abbigliamento); per gli altri oggetti la scheda resta com'è.

Ordine: Nome, Categoria, Quantità, Spazio, **Dettagli**, Nota, bottone.

### Contenuto

- **Tipo**: riga con il tipo in italiano e "›" → foglio di scelta (`DsPickerSheet`) con la **lista chiusa** della tassonomia, raggruppata per categoria (Sopra, Sotto, Abito intero, Scarpe, Giacche, Accessori, Essenziali), "Altro" in fondo a ogni gruppo.
- **Colore**: tag. Prima i colori di base **Bianco, Nero, Grigio, Blu, Marrone, Beige**, poi i colori già usati negli altri oggetti dell'utente (letti dai metadati, senza maiuscole/minuscole doppie, senza "N/A"), poi **"+ Altro colore"** che apre un campo di testo (max 40 caratteri, come accetta il server). Il colore nuovo ricompare nelle schede successive perché sta nei metadati di quell'oggetto. Scelta singola; si può lasciare senza colore (dal solo nome spesso arriva "N/A").
- **Calore**: tag, scelta singola obbligatoria: Molto leggero, Leggero, Medio, Caldo, Molto caldo (`warmth` 1–5).
- **Pioggia**: tag, scelta singola obbligatoria: Si bagna, Pioggia leggera, Impermeabile (`waterResistance` 0–2).
- **Stile**: tag, scelta singola obbligatoria: Da casa, Casual, Curato, Lavoro, Elegante (`formality`: Loungewear, Casual, Smart Casual, Business, Formal).
- **Usi**: tag, **scelta multipla**, almeno uno: Tutti i giorni, Ufficio, Mare, Nuoto, Montagna, Sport, Elegante, Casa (`activityTags`: Everyday, Office, Beach, Swimming, Hiking, Sport, Formal, Lounge). Accanto al titolo "anche più di uno".
- Nei gruppi a scelta obbligatoria toccare il tag già scelto non lo toglie; negli Usi l'ultimo rimasto non si toglie.

### Aspetto

- **Titoli dei gruppi** più grandi dei tag (`titleMedium` semibold, `onSurface`). Anche "Tipo" e i titoli della parte alta della scheda (Nome, Categoria, Quantità, Spazio, Nota) si allineano allo stesso stile, così la scheda ha un solo tipo di titolo.
- **"da controllare"** con l'icona "?" **sulla stessa riga del titolo** del gruppo in dubbio.
- **Tag**: il componente pillola di scelta (§5): niente "+" e niente spunta, alto 32 dp con area di tocco 48, margini interni stretti. Scelto = bordo e testo `onSurface`, e nel tema chiaro anche lo sfondo (`surfaceContainerHigh`); non scelto = bordo `outlineVariant`, testo `onSurfaceVariant`. "+ Altro colore" è la stessa pillola con il "+" nel testo, perché è un'azione.

### Dubbi di Jev

- Oggi il server manda i `dubbi` ma l'app li ignora: l'app li legge dalla risposta di `item-metadata` della scansione e li tiene con il capo.
- Si mostrano **solo nella scansione** (riga del capo e scheda aperta dalla scansione). Un dubbio sparisce quando l'utente tocca un tag di quel gruppo (anche lo stesso già scelto, per confermarlo).
- **Non si salvano**: dopo il salvataggio non resta niente in sospeso.

### Da dove si apre, cosa salva

- **Dalla scansione** (riga dei dettagli): la scheda lavora sul capo ancora non salvato. "Salva" della scheda aggiorna il capo nella pagina dei risultati; l'oggetto si scrive in casa con "Salva: N nuovi" come oggi. Dalla scansione la scheda non mostra il menu ⋯ (sposta / elimina) né lo spazio se la casa non ne ha.
- **Dalla casa** (tocco su un oggetto): la scheda di modifica di oggi con in più la sezione. "Salva" riscrive l'oggetto.
- I valori scelti si scrivono **dentro `aiMetadata`** (stesso JSON, stesse chiavi: `subCategory`, `baseColor`, `warmth`, `waterResistance`, `formality`, `activityTags`). Nessuna colonna nuova, nessuna migrazione: la sincronizzazione porta il JSON su `items.ai_metadata` e `pack-trip` lo legge da lì.
- Cambiare il **Tipo** aggiorna anche `category` del JSON secondo la tassonomia (come fa il server). La **categoria dell'app** (Vestiti / Varie / …) resta quella scelta nelle pillole della scheda.

## 4. Testi in italiano

- Tipi della tassonomia, colori di base, calore, pioggia, stile, usi: tutti nei dizionari `it-IT` / `en-US`, con chiavi per valore. I valori salvati restano quelli del server (in inglese, tranne il colore): si traduce solo la visualizzazione.
- Proposta di nomi italiani dei tipi (da confermare in revisione):
  - Sopra: T-shirt, Camicia, Polo, Felpa con cappuccio, Felpa, Maglione, Canottiera, Top corto, Maglia termica, Pile.
  - Sotto: Jeans, Pantaloncini, Pantaloni, Leggings, Gonna, Pantaloni della tuta, Costume, Calzamaglia termica, Pantaloni da sci, Muta.
  - Abito intero: Vestito.
  - Scarpe: Sneakers, Sandali, Stivali, Infradito, Mocassini, Scarpe eleganti, Scarponi da trekking, Scarpe da scoglio, Doposci.
  - Giacche: Cappotto, Giacca impermeabile, Piumino, Giacca a vento, Blazer, Giacca da sci, Tuta da sci, Giubbotto, Gilet.
  - Accessori: Cappello, Cintura, Borsa, Sciarpa, Occhiali da sole, Gioielli, Orologio, Guanti, Cravatta, Ombrello.
  - Essenziali: Intimo, Calzini, Pigiama.
  - Altro: Altro.
- La tassonomia deve avere **una sola fonte** lato app (un file Dart che rispecchia `tassonomia.ts`, con un test che confronta le due liste), così un tipo aggiunto sul server non resta senza nome.

## 5. Design system

- Un componente condiviso **`DsChoicePill`** in `lib/shared/widgets/` (nome da confermare in piano), con l'aspetto del §3. Sostituisce `AiChoicePill` del foglio "Valigia con AI" (oggi su `feat/valigia-ai`, non ancora in develop) e i tag di questa scheda. Valori da token (`AppConstants`, `context.spacing*`, `colorScheme`), niente numeri sparsi.
- Un componente per il gruppo di tag con titolo, nota sulla stessa riga e scelta singola/multipla, usato da tutti i gruppi della sezione.
- Lo stile del titolo di sezione della scheda in un solo punto (oggi `DsFieldLabel` e `DsSectionTitle`): va deciso in piano quale dei due diventa quello della scheda.
- **Dipendenza**: se `feat/valigia-ai` non è ancora unito quando si parte, la pillola nasce in develop con questo lavoro e il branch della valigia AI la adotta quando si allinea.

## 6. Documenti

- Il commit `bc08263` (branch locale `docs/pubblica-ottobre`, 38 file di ottobre già ripuliti) entra nella PR di questo lavoro, insieme a questa specifica e ai mock in `docs/superpowers/mock/scansione/`, dopo lo stesso controllo dei temi esclusi concordati e con `git add -f` su percorsi espliciti.

## Analytics

- Si tolgono `already_here_details_added` e il conteggio `updated` di `trackAiItemsSaved`.
- Si aggiunge `item_details_edited` (`{source: scan | house, fields: [...]}`, senza valori) quando l'utente salva un cambiamento nei dettagli: serve a capire quali campi l'AI sbaglia più spesso.

## Verifica

- Test di widget: riga del capo (tipo · colore in italiano, niente fantasia, "?" con il conteggio, "›" che apre la scheda, "C'è già?" a destra); scheda dalla scansione e dalla casa; sezione solo per i vestiti; scelte singole obbligatorie, usi multipli con almeno uno; colori di base + colori dell'utente senza doppioni + "Altro colore"; dubbio che sparisce al tocco; "Aggiungi i dettagli" non c'è più.
- Test del notifier/repository: i dettagli scritti in `aiMetadata` senza toccare le altre chiavi; il tipo aggiorna la categoria del JSON e non quella dell'app.
- Test di coerenza tra la tassonomia Dart e `tassonomia.ts`.
- Screenshot dei flussi `05-oggetti` e `06-import-ai` rigenerati, chiaro e scuro, confrontati con i mock.
- `dart analyze` pulito, suite verde, prova sull'app con una scansione vera.

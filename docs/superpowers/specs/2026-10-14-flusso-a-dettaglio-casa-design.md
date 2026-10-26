# Flusso A: dettaglio casa più leggero

Data: 2026-10-14 · Stato: approvato in brainstorming, da rivedere come documento

Seconda parte della standardizzazione UI, dopo la navigazione (PR #23, #25, #26). Riguarda la schermata della casa: lista degli oggetti, aggiunta, scheda dell'oggetto e selezione multipla. È il flusso numero 1 dell'app (aggiungere oggetti a una casa, soprattutto con la scansione AI).

Mock di riferimento: branch locale `mock/house-list` (codice usa e getta, non va mergiato) e screenshot `mock-flusso-a` generati da `test/screenshots/mock_list_test.dart`.

## Problemi di partenza

- Arancio in quattro punti, nessuno dei quali è l'azione principale; la scansione AI era un cerchio grigio in un angolo.
- Due file di filtri (spazi, categorie) più il titolo "In casa" prima del primo oggetto: circa 280 px.
- Le categorie comparivano due volte: come filtro e come gruppi nella lista.
- Scheda oggetto con sei campi bordati e tre bottoni in basso, di cui uno ("chiudi") doppione della X.
- Selezione multipla con tre azioni alla pari ma di peso diverso, tutto arancio, foglio "Sposta" in due tocchi, "1 selezionati".

## Decisioni

### 1. Testata e filtri

- **Intestazione:** freccia indietro, icona della casa **neutra** (`onSurfaceVariant`), nome della casa; a destra 🔍 (vedi "Ricerca") e "⋯" (gestisci casa: oggi è il bottone tondo a sinistra della barra in basso).
- **Via la fila dei filtri per categoria.** Le categorie restano solo come gruppi della lista.
- **Resta la fila degli spazi**, solo se la casa ha almeno uno spazio (com'è oggi). La pillola scelta è **neutra**: riempimento tonale grigio e testo `onSurface`, niente arancio.

### 2. Lista degli oggetti

> Aggiornamento 17/10 (PR #32, decisione dell'utente dopo la prova): i gruppi della casa stanno su **superfici tonali arrotondate (a blocchi)**, non più righe piatte. Etichetta fissa e chiudibile restano.

- **Righe piatte** come oggi (nome, stato "In viaggio" sotto quando serve, quantità a destra), divise da una linea.
- **Etichetta di gruppo piccola e grigia** sopra ogni categoria: "Vestiti · 23" (`labelLarge`, `onSurfaceVariant`). Spariscono l'icona grande della categoria, il conteggio "7 oggetti" a destra e il titolo "In casa".
- **L'etichetta resta fissa in alto** mentre si scorre dentro il suo gruppo, con lo sfondo della pagina, così con 50-100 oggetti si sa sempre dove si è.
- **L'etichetta si tocca per chiudere e riaprire il gruppo**; a destra una freccetta piccola (`iconSizeSm`) ne mostra lo stato.
- **Temporanei** (oggetti di altre case portati qui per un viaggio) sono un gruppo uguale agli altri, in cima: "Temporanei · 4 · da Casa Milano". La provenienza resta sulla riga solo quando le case d'origine sono più di una (com'è oggi).

### 3. Barra in basso

- Il campo "Aggiungi oggetto…" prende il **bordo neutro** (`outlineVariant`, 1 dp) al posto di quello arancio da 2 dp.
- A destra il **bottone AI tondo con contorno e icona arancio**: è l'unico arancio della schermata.
- Il bottone "⋯" a sinistra sparisce (sale nell'intestazione).

### 4. Pagina "aggiungi"

Quando si tocca il campo "Aggiungi oggetto…" (o si arriva da Crea → "scrivili a mano", che apre già il campo):

- **La lista della casa sparisce** e resta una pagina vuota con il campo sopra la tastiera e le pillole delle categorie del rapid fire. L'intestazione mostra solo freccia indietro, icona e nome della casa: 🔍 e "⋯" si nascondono.
- **"Già in casa · n"**: mentre si scrive (da 2 caratteri), in alto compaiono gli oggetti della casa che somigliano al testo, con la stessa etichetta della lista ma senza freccetta né chiusura. Toccare una riga apre la scheda dell'oggetto.
- **"Aggiunti ora · n"**: sotto, gli oggetti salvati in questa sessione della pagina, ciascuno toccabile per correggerlo. Non compaiono mai tra i "Già in casa".
- Se il testo non somiglia a niente e non si è ancora aggiunto nulla, la pagina resta vuota.
- **Pillole delle categorie del rapid fire:** una fila larga quanto il campo, sopra di lui, allineata ai suoi bordi; quattro pillole di uguale larghezza, alte quanto il campo, con icona e **nome intero** ("Vestiti", "Toiletries", "Elettronica", "Varie") al posto delle iniziali.
- **Via il "+" a sinistra nel campo** (oggi apre il form completo `onOpenFullForm`): nome, categoria e quantità 1 bastano, il resto si sistema dalla scheda.
- **Lo stato vuoto della casa** ("Nessun oggetto") segue lo schema del foglio Crea: bottone principale `DsButton` arancio **"Scansiona con AI"** con icona `auto_awesome` (porta a `/houses/:id/ai-import`) e sotto il link **"Non sono vestiti? Scrivili a mano →"** (stesso `TextButton.icon` e stessa stringa `create_sheet.manual_link` del foglio Crea), che apre la pagina "aggiungi". Niente più form di creazione.
- **Uscita:** freccia indietro, tasto indietro di Android o tocco fuori dal campo; torna la casa, con gli oggetti nuovi al loro posto.
- **Somiglianza:** in questa fase confronto senza maiuscole né accenti ("contiene"), chiuso in una sola funzione pura così il motore della ricerca (vedi sotto) lo sostituisce senza toccare la UI.

### 5. Scheda dell'oggetto (modifica)

- **Nome come titolo**: campo grande senza bordo (`headlineSmall`), in cima, fino a tre righe.
- **Righe di impostazioni raggruppate** in un blocco con angoli `cardBorderRadius` e linee interne rientrate: **Categoria** (valore a destra + chevron → `DsPickerSheet`), **Quantità** (−/+ sulla riga, **neutri**), **Spazio** (valore + chevron → `DsPickerSheet`, con "Senza spazio").
- **"Aggiungi una nota"**: link che diventa campo solo al tocco; se la nota c'è, si vede il testo.
- **In alto**: X a sinistra (chiude senza salvare), "⋯" a destra con **Sposta in un'altra casa** ed **Elimina** (in `error`).
- **In basso solo "Salva"**, largo, arancio: l'unico arancio della scheda.
- La scheda serve **solo a modificare**. Il form completo di creazione sparisce: il rapid fire salva nome, categoria (dedotta o scelta) e quantità 1, nello spazio filtrato se c'è; il resto si corregge toccando l'oggetto in "Aggiunti ora".

### 6. Selezione multipla

- **Si entra** tenendo premuto un oggetto (com'è oggi) oppure dalla nuova voce **"Seleziona oggetti"** nel "⋯" della casa. Gli oggetti in viaggio restano non selezionabili.
- **Intestazione:** X, "2 selezionati" (con il singolare "1 selezionato", via plurale di easy_localization) e a destra il testo **"Seleziona tutti" / "Deseleziona tutti"** al posto dell'icona.
- **Righe:** casella arancio (è lo stato "selezionato"); la riga scelta prende un velo neutro (`onSurface` al 6%) invece di quello arancio.
- **Barra in basso:** tre azioni alla pari, **neutre, con icona e scritta**: Sposta · In viaggio · Elimina. Stessa forma e stesse misure della barra di navigazione. Spente (38%) finché non c'è almeno un oggetto scelto. Il rosso compare solo nella conferma di eliminazione.
- **Foglio "Sposta":** tocco sulla casa → se la casa non ha spazi, lo spostamento parte subito; se ne ha, il foglio passa alla scelta dello spazio (con "Senza spazio") e il tocco sullo spazio sposta. Sparisce il bottone "Sposta" in fondo al foglio.

## Ricerca (approvata come direzione, implementazione in una fase a parte)

- **Un solo motore, più domande.** Nella tab Case la 🔍 risponde a "dove sta?" (oggetto + casa + spazio); dentro la casa la 🔍 filtra la lista lasciando i gruppi (quelli vuoti spariscono); la pagina "aggiungi" risponde a "c'è già?"; più avanti anche la creazione del viaggio.
- **Tolleranza ai refusi stile Spotify**, se resta semplice: normalizzazione (minuscole, accenti), poi parole che iniziano con / contengono il testo, poi 1-2 lettere di differenza secondo la lunghezza. Dart puro, dati locali, nessuna libreria né server.
- **Eventi**, insieme a ogni 🔍 che esce: `search_opened` (`context`: `house` | `houses_tab`), `search_result_tapped` (`context`, `position`), `search_no_results` (`context`, `query_length`, mai il testo). Passano da `CoreAnalyticsService`.
- In questa fase la 🔍 nell'intestazione della casa c'è già, con il confronto semplice della pagina "aggiungi"; il motore con i refusi e la ricerca globale arrivano nella fase "Ricerca".

## "C'è già?" nella scansione AI (fase dei risultati AI)

Deciso come direzione, si progetta con la schermata dei risultati: ogni capo riconosciuto è "nuovo" di default; un tasto "C'è già?" apre un foglio con gli oggetti della casa prefiltrati dai metadati AI (tipo, colore, fantasia); "È questo" arricchisce l'oggetto esistente con i metadati (ed eventualmente +1 alla quantità). Niente confronto automatico per nome: due t-shirt bianche possono essere diverse o identiche, decide l'utente. Idea parcheggiata: miniatura per oggetto salvata dalla scansione (pesa su spazio e sync).

## Regole per il kit (da riportare in Figma)

1. **Arancio** solo sull'azione principale della schermata e sugli stati di scelta (caselle). Filtri scelti, icone di contesto, quantità, categorie: neutri.
2. **Etichetta di gruppo**: piccola, grigia, "Nome · n", fissa in alto durante lo scorrimento, toccabile per chiudere il gruppo. Sostituisce `CategorySectionHeader` nella casa; poi checklist del viaggio.
3. **Righe di impostazioni** in blocco (etichetta a sinistra, valore + chevron o controllo a destra, linee rientrate): standard dei moduli (casa, spazio, bagaglio, viaggio). Sfondo del blocco: `surfaceContainerLowest` in chiaro, `surfaceContainer` in scuro.
4. **Barra flottante a voci uguali** (icona + scritta, forma della barra di navigazione): la usano la navigazione e la selezione multipla. Si estrae da `MainShell` un componente condiviso invece di copiarlo (vedi memoria "riusa componenti del DS").
6. **Stato vuoto come template** (decisione dell'utente, 14/10): un solo componente (`DsEmptyState`) con contenuti strutturati che ogni schermata personalizza: icona, titolo, CTA (etichetta + icona) e link secondario (`DsLinkButton`, testo + freccia). Niente bottoni composti a mano negli stati vuoti.
5. **Modalità di inserimento a pagina pulita**: quando si scrive per aggiungere, il contenuto sparisce e restano solo le risposte utili ("Già in casa", "Aggiunti ora").

## Componenti e file toccati

- `lib/features/houses/view/house_detail_screen.dart`: via `_CategoryTab` e `_CategoryFilterPills`; intestazione con 🔍 e "⋯"; barra in basso campo + AI; pagina "aggiungi"; barra di selezione; "Seleziona oggetti" nel "⋯".
- `lib/features/houses/view/house_manage_sheet.dart`: voce "Seleziona oggetti".
- `lib/features/items/view/items_screen.dart`: via il titolo "In casa"; filtro testo per la 🔍; parametro `categoryFilter` rimosso se non serve più altrove.
- `lib/features/items/view/item_category_section.dart`, `in_transit_section.dart`: etichetta di gruppo fissa (`PinnedHeaderSliver` dentro `SliverMainAxisGroup`), chiudibile; i Temporanei diventano un gruppo sliver.
- `lib/shared/widgets/` nuovi componenti condivisi: etichetta di gruppo, riga di impostazioni + blocco, barra flottante a voci uguali (estratta da `main_shell.dart`).
- `lib/features/items/widgets/rapid_fire_input.dart`: bordo neutro; callback del testo per la pagina "aggiungi".
- `lib/features/items/view/add_edit_item_screen.dart` + `item_form_content.dart`: scheda nuova, solo modifica; via il ramo di creazione.
- `lib/features/items/widgets/items_empty_state.dart`: "Scansiona con AI" + link "scrivili a mano" che apre la pagina "aggiungi".
- `lib/features/items/view/bulk_move_sheet.dart`: spostamento al tocco.
- `lib/features/items/view/item_card.dart`: velo di selezione neutro.
- Traduzioni `it-IT.json` / `en-US.json`: plurale di "selezionati", "Seleziona oggetti", "Già in casa", "Aggiunti ora", "Aggiungi una nota", "In viaggio" (azione), "Cerca in {}".

## Tour guidato

Il suggerimento `moveItemsTooltip` punta oggi a `tourKeys.houseItemsAnchor`, messa sulla fila delle categorie che sparisce. La chiave passa alla **prima etichetta di gruppo** della lista (lo step parte solo con più case e la casa predefinita ha oggetti, quindi c'è). Testo invariato: "Tieni premuto su un oggetto per selezionarlo… poi tocca Sposta." Da aggiornare il commento in `tour_keys.dart`.

## Analytics

- Gli eventi esistenti restano (`trackItemAdded`, `trackItemBulkMoved`, `trackItemBulkDeleted`, `trackItemsAddedToTrip`…).
- Nuovo: `add_existing_match_tapped` quando dalla pagina "aggiungi" si tocca una riga "Già in casa": misura quante volte la pagina evita un doppione.
- I tre eventi della ricerca (sezione "Ricerca") entrano già qui con `context: house`, perché la 🔍 della casa esce in questa fase; `houses_tab` arriva con la ricerca globale.

## Fuori da questo lavoro

Motore di ricerca con refusi e ricerca globale; schermata dei risultati AI e "C'è già?"; checklist del viaggio; kit Figma (si fa dopo questo spec, partendo dalle regole sopra); analisi dei flussi con troppi passaggi.

## Verifica

- Test di widget: niente filtri categoria; etichetta di gruppo con conteggio, chiusura al tocco; 🔍 filtra; pagina "aggiungi" mostra "Già in casa" (escludendo gli aggiunti ora) e "Aggiunti ora"; scheda con righe e un solo bottone; barra di selezione spenta senza scelta; "1 selezionato"; foglio Sposta che sposta al tocco (con e senza spazi); tour con la chiave spostata.
- Test della funzione di somiglianza (maiuscole, accenti, stringa corta).
- Screenshot del test UI rigenerati (flussi dettaglio casa, oggetti) e confrontati con il mock.
- `dart analyze` pulito, suite completa verde, prova sull'app (etichette fisse in scorrimento, tastiera con la pagina "aggiungi").

## Punti aperti dal blocco 1 (PR #27)

- **Cursore della ricerca arancio.** Il campo ricerca della casa usa il cursore del tema (`primary`), come tutti i campi. Se lo si vuole neutro, va deciso nel tema per tutta l'app, non come eccezione in questa schermata.

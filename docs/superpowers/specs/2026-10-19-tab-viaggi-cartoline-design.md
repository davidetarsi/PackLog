# Tab Viaggi a cartoline · Design

Data: 19/10/2026 · Stato: approvato dall'utente (19/10/2026) · Riferimenti visivi: `docs/superpowers/mock/viaggi/cartolina-con-itinerario-base.png` (prossimi) e `passati-salvati-A-righe-B-album.png` (colonne B = album). Alternative scartate e storia delle varianti: `docs/superpowers/decisioni-aperte.md`.

## 1. Perché

La tab Viaggi oggi mostra una card "hero" per il viaggio più vicino e sotto una griglia masonry di card compatte con l'anteprima della checklist. È densa, ripete la checklist che sta già nel dettaglio e non dà una direzione chiara. Il redesign dell'app (navigazione, casa, scansione AI) ha fissato regole visive: leggerezza, un solo arancio per l'azione principale, superfici tonali, componenti del design system riusati. La tab Viaggi è il prossimo pezzo.

Dopo una lunga esplorazione (12 varianti) l'utente ha scelto una metafora: **i viaggi sono cartoline**. I prossimi viaggi sono una pila di cartoline da sfogliare; quelli passati e salvati sono un album di cartoline piccole da riusare.

## 2. Obiettivi, non obiettivi, anti-obiettivi

**Obiettivi**
- Prossimi: una cartolina grande per volta, con meta, giorni alla partenza, itinerario geografico-temporale, stato della valigia e un solo bottone che cambia col momento.
- Passati e Salvati: album di cartoline piccole, con "Riusa" sempre a portata.
- Filtri neutri Prossimi / Passati / Salvati (via "Tutto").
- Il bottone "Prepara la valigia" diventa il punto d'ingresso della futura valigia AI (non in questo lavoro).

**Non obiettivi (rimandati)**
- Dettaglio viaggio, modifica oggetti, nuovo viaggio: restano come sono. Il nuovo viaggio verrà ridisegnato subito dopo (l'utente ha un esempio da mostrare).
- Luogo di partenza ("Parti da"), mezzo di trasporto per ogni tratto, foto della meta: toccano i dati, si decidono col nuovo viaggio.
- Bagagli (peso, capienza, scelta): da riprendere in futuro.
- Nessuna modifica allo schema del database né alla sincronizzazione.

**Anti-obiettivi (sarebbe un fallimento anche se funziona)**
- Cartolina in cima storta: la cartolina attiva e il suo bottone sono sempre dritti.
- Arancio fuori dal bottone principale della cartolina (francobollo, anello, filtri, "Riusa", timbri: tutto neutro). Nessun arancio deve spuntare dalle cartoline sotto la pila.
- Lista degli oggetti mancanti sulla cartolina (c'è già nel dettaglio).
- "Oggi" nell'itinerario.
- Componenti o valori una tantum: si usano token (`context.spacing*`, `iconSize*`, `responsive`, `AppConstants`), colori del `colorScheme` e widget del design system esistenti dove c'è un equivalente.

## 3. Struttura della tab

Dall'alto: `TabHeader` "Viaggi" (invariato), `AppPillTab` con Prossimi / Passati / Salvati in versione neutra (`selectedColor: colorScheme.onSurface`, `selectedTextColor: colorScheme.onSurface`, come nella casa), poi il contenuto del filtro. Filtro iniziale: Prossimi. La voce "Tutto" e il suo enum spariscono.

Insiemi:
- **Prossimi** = viaggi in corso + futuri (`isActive || isUpcoming`; i viaggi senza data di partenza sono "upcoming" per il modello). Ordine: prima i viaggi in corso (ritorno più vicino prima; quelli senza ritorno, che per il modello restano "in corso" per sempre come oggi, in fondo ai viaggi in corso), poi i futuri per data di partenza crescente, in fondo quelli senza date (per `createdAt`). Il comportamento dei viaggi senza ritorno non cambia *(scelta mia)*.
- **Passati** = `isCompleted`.
- **Salvati** = `isSaved` (un viaggio salvato può comparire anche in Prossimi o Passati, come oggi).

## 4. Prossimi: la pila di cartoline

### 4.1 Pila e scorrimento
- Occupa lo spazio tra i filtri e l'indicatore. La cartolina in cima è a tutta larghezza (margini laterali come il resto della pagina) e **dritta**.
- Sotto si intravedono al massimo **due** cartoline: sono solo carta (stesso colore, bordo e ombra, **senza contenuto**), leggermente spostate e ruotate in senso opposto l'una all'altra. Con un solo viaggio non c'è carta sotto.
- **Scorrimento da destra a sinistra**: la cartolina in cima vola via verso sinistra (con una leggera rotazione mentre si trascina) e sotto compare la successiva, che si raddrizza e sale in cima. **Da sinistra a destra**: torna la cartolina scartata per ultima. Sull'ultima (o sulla prima) il gesto fa un piccolo rimbalzo e torna al posto. Soglia: circa un quarto della larghezza o un lancio veloce.
- Indicatore sotto la pila: puntini + "2 di 4", neutri (stile del mock). Nascosto con un solo viaggio. Spazio: `spacingMd` tra pila e indicatore e almeno `spacingLg` tra indicatore e barra di navigazione (oltre a `navBarReservedHeight`): la cartolina si accorcia di conseguenza.
- Accessibilità: la cartolina espone l'etichetta "Viaggio 2 di 4: Lisbona" e due azioni semantiche "Viaggio successivo" / "Viaggio precedente".
- Tocco sulla cartolina → dettaglio (`/trips/:id`). Pressione lunga → menu contestuale esistente (Copia / Salva / Elimina, via `showEntityContextMenu` + `EntityActionHandler`), come oggi.
- Se la lista dei prossimi cambia (sync, eliminazione) e la posizione corrente non esiste più, la pila torna alla prima cartolina.

### 4.2 La cartolina
Carta: colore della card (`surfaceContainerLowest` in chiaro, `surfaceContainer` in scuro, come i blocchi della casa), angoli poco arrotondati (aspetto da carta), bordo sottile `outlineVariant` attenuato e un'ombra leggera.

Dall'alto:
1. **Intestazione**. A sinistra: "Saluti da" (corsivo, secondario), sotto la **meta** in grande e grassetto (fino a 3 righe), sotto il **nome del viaggio** in secondario solo se diverso dalla meta. A destra: **francobollo** (rettangolo con bordo a dentini e cornice interna, tonale neutro) e, sovrapposto al suo angolo in basso a sinistra, un **timbro postale** tondo e un po' ruotato con "PACKLOG", la data di partenza ("28 OTT") e l'anno.
   - Francobollo: numero di giorni alla partenza + "giorni" ("giorno" se 1; "oggi" se si parte oggi ma il viaggio non è ancora iniziato); viaggio in corso → icona di decollo + "in viaggio"; senza data di partenza → icona calendario + "da decidere" e niente timbro.
2. **Itinerario verticale** (vedi 4.3).
3. Spazio flessibile.
4. **Riga valigia**, separata da una linea sottile sopra: anello di avanzamento neutro (traccia `surfaceContainerHigh`, riempimento `onSurface`) con la percentuale dentro; accanto "4 di 11 pronti" e sotto "mancano 7" / "tutto in valigia" / "nessun oggetto" (con 0 oggetti: "Valigia vuota" · "nessun oggetto" e anello a 0%). Sulla stessa riga, a destra, **solo se il viaggio ha bagagli**: icona valigia + nomi dei bagagli (uno per riga, massimo 2 righe, poi ellissi).
5. **Bottone principale** (`DsButton`, arancio, a tutta larghezza), unico arancio della tab:

Le righe si valutano dall'alto: vince la prima che vale. Il viaggio in corso non ha un testo suo ("Apri la checklist" scartato dall'utente il 19/10).

| Stato | Testo | Icona | Dove porta |
|---|---|---|---|
| Nessun oggetto | Prepara la valigia | valigia | `/trips/:id/edit-items` |
| Tutto spuntato | Valigia pronta | spunta in cerchio | `/trips/:id` |
| Mancano oggetti (anche in corso) | Continua a preparare | valigia | `/trips/:id` |

Quando arriverà la valigia AI, "Prepara la valigia" avrà l'icona AI e aprirà il suo flusso: fuori da questo lavoro.

### 4.3 Itinerario
Regola: **i luoghi dicono dove e quante notti; gli spostamenti portano le date**. Nessun luogo di partenza, nessun "oggi".

Righe, nell'ordine:
- **Andata**: icona decollo · "Andata" · data partenza ("mer 28 ott").
- Per ogni luogo: pallino pieno · **nome del luogo** in grassetto · sotto "3 notti · 28 ott – 31 ott".
- Tra due luoghi: icona aereo · "Spostamento" · data di inizio del luogo successivo.
- **Ritorno**: icona atterraggio · "Ritorno" · data di ritorno.

Le icone e i pallini stanno su una linea verticale sottile (`outline`) a sinistra; le date a destra in grassetto; etichette in secondario.

Luoghi *(scelta mia)*: nel modello le `legs` sono le "Altre tappe", in aggiunta alla meta. Quindi il **primo luogo è sempre la meta**, poi le tappe ordinate per `from` (quelle senza data in fondo, nell'ordine di inserimento); nome della tappa = parte prima della prima virgola di `locationDisplayName`. Periodo della meta: dalla partenza al `from` della prima tappa datata (senza tappe: fino al ritorno). Periodo di una tappa: `from`–`to`. Lo "Spostamento" prima di una tappa porta il suo `from`. Le date si mostrano come sono, senza correggere sovrapposizioni con quelle del viaggio.

Meta (titolo della cartolina e luogo unico): nome della casa se `destinationHouseId` punta a una casa esistente (nome completo, senza tagli alla virgola); altrimenti `destinationLocation.city` se c'è, altrimenti la parte di `displayName` prima della prima virgola; altrimenti il nome del viaggio.

Date mancanti: dove manca una data si scrive "da decidere"; le notti si omettono se manca una delle due date.

Molte tappe: si mostrano al massimo 3 luoghi. Oltre, restano il primo e l'ultimo e in mezzo una riga "+N tappe" (al posto delle righe intermedie e dei loro spostamenti).

## 5. Passati e Salvati: l'album

- Griglia a **due colonne** di cartoline piccole (proporzione circa 0,82), ciascuna leggermente ruotata con un'inclinazione che cambia in modo ciclico (pochi gradi, alternati), come appese in un album. Scorre in verticale; il fondo lascia spazio alla barra di navigazione.
- **Passati**: gruppi per anno di partenza (o di creazione se manca la data), anni dal più recente, con `DsGroupHeader` "2026 · 2"; dentro, dal viaggio più recente. **Salvati**: un solo gruppo "Da riusare · N", dal più recente.
- Cartolina piccola, stessa carta della grande:
  - in alto a destra un **francobollo piccolo** con il giorno ("20") e "AGO 26"; senza data → icona segnalibro;
  - nei Passati il francobollo è **annullato** dalle onde del timbro postale (linee ondulate sul suo bordo destro, senza coprire il testo); nei Salvati è pulito;
  - in basso: "Saluti da", la meta (fino a 2 righe), le notti ("5 notti", omesse senza date), e il bottone testuale neutro **"Riusa"** con icona.
- Tocco sulla cartolina → dettaglio. Pressione lunga → menu contestuale esistente.

### 5.1 Riusa
"Riusa" crea un nuovo viaggio a partire da quello scelto e apre subito la modifica delle informazioni del nuovo viaggio (`/trips/<nuovoId>/edit-info`) per mettere le date nuove.

Il nuovo viaggio copia nome (senza suffisso), descrizione, meta e oggetti (tutti da spuntare, come la copia di oggi); **non** copia le date né lo stato "salvato". Copia anche i **bagagli** (sono entità riusabili) e le **tappe con le date azzerate** *(scelta mia)*.

Se l'utente esce dalla modifica senza salvare, il nuovo viaggio viene eliminato: "Riusa" annullato non lascia copie senza date *(scelta mia)*. Se salva, il viaggio finisce dove dicono le sue date.

La copia del menu contestuale resta esattamente com'è (suffisso "(Copia)", date e stato salvato copiati, niente tappe né bagagli). Analytics: lo stesso evento della copia di oggi.

## 6. Stati vuoti, caricamento, errori

- **Nessun viaggio**: stato vuoto attuale (template `DsEmptyState` con CTA "nuovo viaggio" verso `/new-trip`), filtri sempre visibili.
- **Prossimi vuoto** (ma esistono altri viaggi): `DsEmptyState` con icona calendario, titolo "Nessun viaggio in programma" e CTA "Nuovo viaggio" → `/new-trip`.
- **Passati vuoto**: `DsEmptyState` titolo "Qui troverai i viaggi fatti".
- **Salvati vuoto**: `DsEmptyState` titolo "Nessun viaggio salvato" e sottotitolo "Tieni premuto un viaggio e scegli Salva per riusarlo".
- **Caricamento**: lo scheletro attuale va adattato: pillole dei filtri + una sagoma di cartolina grande.
- **Errore**: stato di errore attuale.
- Tirare per aggiornare resta sull'album e sugli stati vuoti; sulla pila no (lo scorrimento orizzontale è il gesto principale).

## 7. Testi e design system (richiesta esplicita dell'utente)

**Sempre** tutti i testi nei dizionari `it-IT` e `en-US` (plurali con `.plural()`), nessuna stringa scritta nel codice. **Sempre** valori del design system (token di spaziatura, icone, raggi, colori del tema) e componenti già definiti (`DsButton`, `DsEmptyState`, `DsGroupHeader`, `AppPillTab`, menu contestuale, ecc.); niente componenti o valori una tantum quando esiste l'equivalente. Le chiavi non più usate (filtro "Tutto", testi delle vecchie card) vanno rimosse se nessun altro le usa.

## 8. Cosa sparisce

- `TripFilterTab.all`.
- `TripCardHero`, `TripCardCompact` (`lib/shared/widgets/trip_cards.dart`) e la griglia masonry: usati solo dalla tab e dalla vetrina del design system (`ds_theme_showcase_screen.dart`), da cui vanno tolti. Anche `SkeletonTripCard` se non serve più.

## 9. Verifica

- Screenshot (flusso `07-viaggi` dell'harness, chiaro e scuro): vuoto; Prossimi con il viaggio in corso; Prossimi dopo uno scorrimento (Lisbona, con tappe e bagagli); Prossimi con la valigia vuota (Torino); Passati; Salvati; menu contestuale sulla cartolina; Prossimi vuoto. Aggiornare `docs/ui-flows.md`.
- Test: composizione dell'itinerario (luogo unico, tappe, date mancanti, oltre 3 luoghi), testo del francobollo per ogni stato, scelta del bottone (tabella 4.2), pila (scarto, ripristino, limiti), raggruppamento dell'album, "Riusa" (copia senza date e senza "salvato", apertura della modifica), nuovo comportamento della copia nel DAO.

## 10. Lasciato a chi costruisce

- Struttura dei file e nomi dei widget (cartella `lib/features/trips/view/widgets/` o simile).
- Valori esatti di rotazioni, spostamenti, ombre, dentini del francobollo e onde del timbro, curve e durate delle animazioni, purché coerenti col mock e coi token.
- Come estendere la copia nel DAO/repository per "Riusa" (parametri opzionali o metodo dedicato), mantenendo invariato il comportamento della copia del menu.
- Come la modifica delle informazioni sa di essere aperta da "Riusa" (per eliminare la copia all'uscita senza salvataggio).

## 11. Scelte mie da controllare

1. Itinerario: la meta è sempre il primo luogo, poi le "Altre tappe" ordinate per data (4.3).
2. Viaggio in corso senza oggetti → "Prepara la valigia" (4.2). Approvato dall'utente.
3. Viaggi senza ritorno: restano "in corso" come oggi, in fondo ai viaggi in corso (3).
4. "Riusa" copia anche bagagli e tappe (senza date); uscire senza salvare elimina la copia (5.1).
5. Nessun riordino ad hoc delle tappe con date fuori dal viaggio.

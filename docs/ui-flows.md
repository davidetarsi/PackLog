# Flussi UI di PackLog

Mappa delle schermate per flusso, con il comando che le fotografa tutte.
Serve per review di UI/UX e per l'import in Figma: ogni schermata elencata qui
ha (salvo dove indicato) un PNG generato da `test/screenshots/`.

## Come rigenerare gli screenshot

```bash
flutter test test/screenshots --dart-define=UI_SCREENSHOTS=true
```

- Gira su Linux senza emulatore: monta l'app vera (router, shell, tema,
  traduzioni) con un DB SQLite in memoria popolato da dati finti realistici.
- Output: `build/ui-screenshots/<flusso>/<nn>-<schermata>-<stato>-<tema>.png`
  più `build/ui-screenshots/manifest.json` (flusso, ordine, schermata, stato,
  tema, rotta, file sorgente, descrizione, eventuali overflow di layout).
- Telefono di riferimento: Pixel 7, 412×915 dp, PNG a 3x (1236×2745), status
  bar 24 dp e barra gesti 16 dp. Lingua it-IT. Temi: scuro (default dell'app) e
  chiaro.
- Un solo tema: `--dart-define=UI_SCREENSHOTS_THEMES=dark`.
- Un solo flusso: aggiungi `--plain-name "04-dettaglio-casa"` (il manifest
  viene fuso con quello esistente, non sovrascritto).
- Senza `UI_SCREENSHOTS=true` i test risultano *skipped*: `flutter test` resta
  veloce.

**Versione di Flutter.** Usare la stessa della CI (3.38.5, vedi
`.github/workflows/ci.yml`). Con SDK più recenti `build_runner` fallisce
(`analyzer` del lockfile più vecchio del linguaggio dell'SDK) e i file `.g.dart`
non si rigenerano. Sulla VPS c'è una copia in
`/srv/claude/workspaces/.tools/flutter-3.38.5`; prima della prima esecuzione
servono `flutter pub get` e
`dart run build_runner build --delete-conflicting-outputs`.

**Cosa i test sostituiscono.** Supabase, Google Sign-In, analytics, sync,
connettività, GPT e fotocamera sono rimpiazzati da fake (vedi
`test/screenshots/support/harness.dart`). I dati vengono scritti nel DB
passando dai repository veri (`support/seed.dart`). Nessuna modifica a `lib/`.

**Limiti noti.**
- Il video delle slide di onboarding non parte (nessun player nei test): si
  vede l'icona di fallback che l'app mostra quando il video fallisce.
- L'`AppBar` usa un `titleTextStyle` senza `fontFamily`: nei test il font di
  sistema è un font segnaposto, quindi l'harness replica il ramo "pronto" di
  `MyApp` aggiungendo `fontFamily: 'sans-serif'` al titolo (su Android è
  comunque Roboto). Se `MyApp` cambia, va riallineato `_ScreenshotMaterialApp`.
- Animazioni, transizioni e tastiera non compaiono: sono foto statiche.
- La ricerca dei luoghi (Geoapify, `LocationSearchService`) è sostituita da
  un fake con tre città fisse (Lisbona, Sintra, Siviglia) filtrate sul nome:
  niente rete nei test.

## Dati di esempio

Utente "Davide Rossi". Case: *Casa Milano* (principale, 18 oggetti in 3 spazi,
3 bagagli), *Casa al mare*, *Baita dei nonni a Courmayeur, Valle d'Aosta* (nome
lungo), *Monolocale Torino* (vuota). Viaggi: *Weekend al mare* (in corso, verso
Casa al mare), *Lisbona* (fra 10 giorni, con una tappa a Sintra, 11 oggetti di cui 4 spuntati),
*Matrimonio Giulia* (salvato), *Weekend a Torino* (senza oggetti), due viaggi
passati. Un oggetto ha un nome volutamente lungo.

## Navigazione

Shell con barra flottante (`lib/shared/widgets/main_shell.dart`): **Case**
(`/`, home), **Crea** al centro e **Viaggi** (`/trips`). Crea apre il foglio
Crea: "Scansiona con AI" in primo piano (con la casa di destinazione), il link
"scrivili a mano" (apre la pagina "aggiungi" della casa con il campo attivo), poi Nuova casa e
Nuovo viaggio, nell'ordine della tab da cui lo si apre. Il **Profilo**
(`/profile`) si apre dall'avatar in alto a destra.
Profilo e schermate di dettaglio stanno sul navigator radice, sopra la shell. Redirect in `lib/core/routing/app_router.dart`:
onboarding non completato → `/onboarding`; non autenticato → `/login`; tour
post-login allo step `aiIntro` → `/onboarding-ai-intro`.

La barra di navigazione e quella della selezione multipla condividono i
componenti `DsFloatingBar` e `DsBarItem`; nella selezione le azioni sono
Sposta, In viaggio ed Elimina.

## Flussi

Per ogni schermata: file sorgente, come ci si arriva, stati catturati
(✓ = c'è il PNG) e stati non catturati.

### 01 · Primo avvio: onboarding e login

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1-3 | Onboarding (3 slide: case, oggetti, viaggi) | `features/onboarding/view/onboarding_screen.dart` | primo avvio | ✓ slide 1, 2, 3 |
| 4-6 | Login Google | `features/auth/view/login_screen.dart` | onboarding completato, nessuna sessione | ✓ consenso mancante, ✓ snackbar "devi accettare", ✓ consenso dato. Non catturati: login in corso, errore di login |

### 02 · Tour post-login: import AI guidato

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1-2 | Intro AI | `features/tour/view/ai_onboarding_intro_screen.dart` | primo login (step `aiIntro`) | ✓ default, ✓ sheet fotocamera/galleria |
| 3-4 | Risultati AI (primo import) | `features/ai_input/view/ai_results_screen.dart` | dopo aver scelto le foto | ✓ analisi in corso, ✓ capi riconosciuti. Non catturati: tooltip "salva" del tour |

### 03 · Tab Case

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1-4 | Elenco case | `features/houses/view/houses_screen.dart` | tab Case | ✓ vuoto, ✓ skeleton durante il primo sync, ✓ elenco (principale, badge in viaggio/ospite, nome lungo, casa vuota), ✓ menu contestuale (long press). Non catturato: errore |
| 5 | Foglio Crea | `shared/widgets/create_sheet.dart` | Crea, dalla tab Case | ✓ |
| 6 | Nuova casa (sheet) | `features/houses/view/add_edit_house_screen.dart` | riga "Nuova casa" in fondo alla lista | ✓ |

### 04 · Dettaglio casa

Inventario a gruppi per categoria. Ogni gruppo ha un'etichetta grigia fissa in
alto ("Vestiti · 7") che resta visibile mentre si scorre e si chiude toccandola;
"Temporanei" (oggetti di viaggi attivi verso questa casa) è un gruppo come gli altri. Le
categorie non sono più filtri: il filtro in alto è solo per spazio. Niente
titolo "In casa": il nome della casa sta nell'app bar, con un'icona neutra.
In alto: 🔍 apre la ricerca (l'app bar diventa un campo e la lista mostra solo
gli oggetti che corrispondono) e "⋯" gestisce la casa. In basso: il campo
rapid-fire con bordo neutro e il bottone AI tondo, l'unico elemento arancione
della schermata. La pillola dello spazio scelto è neutra.

Toccando il campo si apre la **pagina "aggiungi"**: la lista della casa sparisce
e restano solo le risposte utili. Sopra il campo, una fila di quattro pillole
di uguale larghezza (icona sopra, nome intero sotto: Vestiti, Toiletries,
Elettronica, Varie). Da due caratteri digitati (spazi esclusi) compare
"Già in casa · n", con gli oggetti già presenti nella casa, in qualunque
spazio; sotto, "Aggiunti ora · n" con quelli salvati in questa pagina. L'app
bar ha solo la freccia e il nome della casa (niente 🔍 né "⋯"). Il tasto
"fatto" della tastiera salva e tiene il campo attivo; la freccia indietro, la
freccia dell'app bar o un tocco fuori chiudono la pagina.

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1-5 | Dettaglio casa | `features/houses/view/house_detail_screen.dart` | tap su una casa | ✓ pieno, ✓ filtro spazio, ✓ casa vuota (stato vuoto AI-first: "Scansiona con AI" e il link "scrivili a mano"), ✓ pagina "aggiungi" con un nome digitato (casa nascosta, pillole col nome intero), ✓ selezione multipla con caselle arancio, velo neutro e barra Sposta · In viaggio · Elimina |
| 6 | Sposta in… | `features/items/view/bulk_move_sheet.dart` | selezione → Sposta | ✓. Toccare una casa senza spazi sposta subito; una casa con spazi apre la scelta dello spazio, compresa "Senza spazio" |
| 7 | Aggiungi a viaggio | `features/trips/view/trip_picker_sheet.dart` | selezione → In viaggio | ✓ |
| 8 | Gestisci casa | `features/houses/view/house_manage_sheet.dart` | "⋯" in alto a destra | ✓, con "Seleziona oggetti" in cima |
| 9 | Modifica casa | `features/houses/view/add_edit_house_screen.dart` | Gestisci → Modifica info | ✓ |
| 10 | Spazi | `features/spaces/view/spaces_management_screen.dart` | Gestisci → Modifica spazi | ✓. Non catturato: sheet nuovo/modifica spazio |
| 11 | Bagagli | `features/luggages/view/luggages_management_screen.dart` | Gestisci → Modifica bagagli | ✓. Non catturato: sheet nuovo/modifica bagaglio |
| 12 | Conferma eliminazione | `house_detail_screen.dart` | Gestisci → Elimina | ✓ |
| 13 | Casa non trovata | `house_detail_screen.dart` | link a casa eliminata | ✓ |
| 14 | Ricerca nella casa | `features/houses/view/house_detail_screen.dart`, `features/items/view/items_screen.dart` | 🔍 in alto, poi testo | ✓ "cal": solo gli oggetti che corrispondono |
| 15 | Gruppo chiuso | `features/items/view/item_category_section.dart` | tap sull'etichetta "Vestiti · 7" | ✓ gruppo Vestiti chiuso |
| 16 | Temporanei in cima | `features/items/view/in_transit_section.dart` | Casa al mare (viaggio attivo verso di lei) | ✓ "Temporanei · 4 · da Casa Milano" in cima |
| 17 | Pagina "aggiungi": Già in casa | `features/houses/view/house_detail_screen.dart` (`_AddPage`) | campo rapid-fire, scrivi "calz" | ✓ "Già in casa · 1" con Calzini (x7) sopra le pillole |
| 18 | Sposta in…: scelta spazio | `features/items/view/bulk_move_sheet.dart` | Casa al mare → selezione di Infradito → Sposta → Casa Milano | ✓ elenco degli spazi di Casa Milano e "Senza spazio" |

### 05 · Oggetti

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1 | Pagina "aggiungi" dalla Crea | `features/houses/view/house_detail_screen.dart` (`_AddPage`) | Crea → scrivili a mano (niente più "+": il campo è già attivo) | ✓ campo attivo, casa nascosta. La creazione di un oggetto passa solo da qui: la scheda oggetto è solo modifica |
| 2 | Scheda oggetto | `features/items/view/item_sheet.dart` (`ItemSheet`) | tap su un oggetto nel dettaglio casa | ✓ nome come titolo, righe Categoria / Quantità / Spazio, "Aggiungi una nota" grigio, solo "Salva" arancio. Non catturati: picker di categoria e spazio aperti |
| 3 | Scheda oggetto: menu | `features/items/view/item_sheet.dart` | ⋯ in alto a destra della scheda | ✓ "Sposta in un'altra casa" ed "Elimina" (rosso). Non catturati: sheet di spostamento e conferma di eliminazione |

### 06 · Import AI da dettaglio casa

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1 | Scelta sorgente | `features/houses/view/house_detail_screen.dart` | bottone ✨ nel dettaglio casa, ingresso diretto | ✓ sheet Galleria/Fotocamera |
| 2-13 | Risultati AI | `features/ai_input/view/ai_results_screen.dart` | dopo la scelta delle foto | ✓ analisi in corso, ✓ capi riconosciuti, ✓ scelta casa, ✓ capo escluso, ✓ nome in modifica, ✓ foglio “C’è già?”, ✓ capo collegato, ✓ casa vuota senza “C’è già?”, ✓ conferma uscita, ✓ errore parziale con retry, ✓ errore di rete, ✓ quota esaurita |

### 07 · Tab Viaggi

Filtri: Prossimi, Passati, Salvati (il vecchio "Tutto" è stato tolto). Prossimi
è una pila di cartoline (`features/trips/view/widgets/postcard/postcard_pile.dart`,
scorrimento orizzontale, cartolina in cima sempre dritta, arancio solo sul
bottone della cartolina in cima). Le cartoline sotto sono solo carta. Passati e
Salvati sono un album (`widgets/postcard/trip_album.dart`) con i viaggi senza
date marcati "Riusa".

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1 | Elenco vuoto | `features/trips/view/trips_screen.dart` | tab Viaggi senza viaggi | ✓ vuoto, con "Nuovo viaggio" |
| 2 | Prossimi | `trips_screen.dart`, `widgets/postcard/postcard_pile.dart`, `widgets/postcard/trip_postcard.dart` | tab Viaggi, filtro Prossimi | ✓ viaggio in corso in cima (Casa al mare, francobollo "in viaggio") |
| 3 | Prossimi dopo uno scorrimento | `widgets/postcard/postcard_pile.dart` | scorrimento della pila di 330 dp | ✓ Lisbona: Andata, Spostamento, tappa Sintra, Ritorno; 2 bagagli |
| 4 | Prossimi, valigia vuota | `widgets/postcard/trip_postcard.dart`, `widgets/postcard/postcard_parts.dart` | secondo scorrimento | ✓ Torino senza oggetti né bagagli, CTA "Prepara la valigia" |
| 5 | Passati | `widgets/postcard/trip_album.dart` | filtro Passati | ✓ album per anno, Barcellona e una baita con nome lungo (titolo su due righe con ellissi) |
| 6 | Salvati | `widgets/postcard/trip_album.dart` | filtro Salvati | ✓ gruppo "Da riusare" con Firenze |
| 7 | Menu contestuale | `shared/widgets/entity_context_menu.dart` | pressione lunga sulla cartolina in cima | ✓ copia / salva / elimina |
| 8 | Prossimi vuoto | `trips_screen.dart` | filtro Prossimi quando restano solo viaggi passati | ✓ "Nessun viaggio in programma" con "Nuovo viaggio". Lo stato si ottiene eliminando i viaggi futuri nello scenario |
| 9 | Foglio Crea | `shared/widgets/create_sheet.dart` | Crea, dalla tab Viaggi (Nuovo viaggio in cima) | ✓ |
| 10 | Prossimi dopo il passo 1 | `trips_screen.dart` (`?focus=`), `widgets/postcard/postcard_pile.dart` | passo 1 compilato (Siviglia) e "Prepara la valigia più tardi" | ✓ Siviglia in cima alla pila, valigia vuota |

Non catturati: stato di errore del caricamento; il tap sulla cartolina porta
al dettaglio viaggio (flusso 09).

### 08 · Creazione viaggio: passo 1

Il nuovo viaggio è un passo solo, in ordine di itinerario
(`features/trips/view/new_trip_screen.dart`, rotta `/new-trip`): "Dove vai?"
(campo unico per le case e i luoghi, `widgets/place_search.dart`), "Quando?"
(foglio delle date, `widgets/trip_dates_sheet.dart` con `widgets/trip_calendar.dart`),
"Itinerario" (`widgets/postcard/trip_itinerary_view.dart`, con le tappe da
aggiungere nel foglio `widgets/stop_sheet.dart`) e "Nome del viaggio", che
segue la meta finché non lo si scrive a mano. Le uscite sono due: "Avanti:
prepara la valigia" (arancio, porta al passo 2 = pagina valigia del flusso 09,
con `?from=new`) e "Prepara la valigia più tardi" (link, torna alla tab Viaggi
con `?focus=<id>`). Entrambe salvano solo con meta e date e senza tappe a zero
notti. Con una meta scelta, Indietro chiede conferma.

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1 | Passo 1 vuoto | `new_trip_screen.dart` | tab Viaggi → Nuovo viaggio (o Crea) | ✓ vuoto, "Avanti" spento |
| 2 | "Dove vai?" con le case | `widgets/place_search.dart` | tocco sul campo | ✓ "Le tue case · 4" sotto il campo |
| 3 | Passo 1 compilato | `new_trip_screen.dart` | meta Lisbona e date dal 10 al 13 | ✓ itinerario con andata, tappa e ritorno; "Avanti" acceso |
| 4 | Foglio "Nuova tappa" vuoto | `widgets/stop_sheet.dart` | "Aggiungi tappa" | ✓ "Aggiungi tappa" spento |
| 5 | Foglio "Nuova tappa" compilato | `widgets/stop_sheet.dart` | Sintra scelta, fine il 15 | ✓ "Parti da Lisbona … Il ritorno diventa …" |
| 6 | Due tappe | `new_trip_screen.dart` | foglio 5 salvato | ✓ Lisbona, spostamento, Sintra, ritorno |
| 7 | Dati mancanti | `new_trip_screen.dart` | "Avanti" a modulo vuoto | ✓ campo meta e campo date in errore, messaggio sotto ciascuno, nessuno snackbar |
| 8 | Tappa a zero notti | `new_trip_screen.dart` | Sintra finisce il giorno in cui finisce la meta | ✓ "Sintra finisce prima di iniziare", "Avanti" spento |
| 9 | Foglio delle date | `widgets/trip_dates_sheet.dart` | tocco su "Quando?" | ✓ calendario, "Conferma date" spento |

Non catturati: stato di salvataggio in corso e errore di salvataggio (dialog
di riprova); lista dei luoghi mentre si scrive; modifica e rimozione di una
tappa esistente; dialog di uscita con modifiche non salvate.

### 09 · Dettaglio viaggio e pagina valigia

La pagina valigia (`features/trips/view/pack_suitcase_screen.dart`, rotta
`/trips/:id/edit-items`) sostituisce "Modifica oggetti" della vecchia
versione: riepilogo, bagagli a pillola, ricerca, selettore "Da" della casa e
oggetti della casa divisi per categoria, con quantità. Il salvataggio è
esplicito, con "Fatto". Con `?from=new` mostra l'indicatore dei passi in cima.
Non esistono più il wizard a due passi né `edit_trip_items_screen.dart`.

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1-3 | Dettaglio viaggio | `features/trips/view/trip_detail_screen.dart` | tap su un viaggio | ✓ checklist, ✓ in corso, ✓ senza oggetti |
| 4 | Conferma eliminazione | `trip_detail_screen.dart` | cestino | ✓ |
| 5 | Modifica info | `features/trips/view/edit_trip_info_screen.dart` | matita | ✓ |
| 6 | Pagina valigia da "Modifica oggetti" | `pack_suitcase_screen.dart` | "Modifica oggetti" | ✓ senza indicatore dei passi |
| 7 | Pagina valigia dal passo 1 | `pack_suitcase_screen.dart` (`fromNewTrip`) | "Avanti: prepara la valigia" al passo 1 | ✓ indicatore con "Viaggio" fatto e "Valigia" attivo, "Fatto" senza numero |
| 8 | Valigia con scelte e quantità | `pack_suitcase_screen.dart` | bagaglio "Valigia grande" in più, "Calzini" da 7 a 6 | ✓ "Fatto · 11 oggetti" |
| 9 | Dopo un cambio casa | `pack_suitcase_screen.dart`, `widgets/pack/pack_parts.dart` | pillola "Da" → "Casa al mare" nel selettore | ✓ oggetti di Casa al mare, selezione del viaggio invariata |
| 10 | Viaggio non trovato | `trip_detail_screen.dart` | link a viaggio eliminato | ✓ |

Non catturati: foglio di selezione della casa aperto; dialog di uscita con
modifiche non salvate; errore di salvataggio della valigia.

### 10 · Profilo

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1-3 | Profilo | `features/profile/view/profile_screen.dart` | avatar in alto a destra | ✓ inizio pagina, ✓ fine pagina, ✓ modifiche non sincronizzate |
| 4 | Lingua | `features/profile/view/dialogs/profile_language_dialog.dart` | Lingua | ✓ |
| 5 | Tema | `features/profile/view/dialogs/profile_theme_dialog.dart` | Tema | ✓ |
| 6 | Elimina account | `features/profile/view/dialogs/profile_delete_account_dialog.dart` | Elimina il mio account | ✓ |
| — | Esci / dettagli sync | `profile_logout_dialog.dart`, `profile/widgets/sync_details_dialog.dart` | Esci, tap sullo stato sync | **non catturati**: il logout legge le modifiche pendenti dal servizio di sync (Supabase) prima di aprire il dialog |

### 12 · Errori di navigazione

| # | Schermata | Sorgente | Stati |
|---|---|---|---|
| 1 | Errore router | `core/routing/app_router.dart` (`_ErrorScreen`) | ✓ rotta sconosciuta |

Non catturati in nessun flusso: i tooltip del tour guidato
(`features/tour/`, TutorialCoachMark).

## Attriti UX e incoerenze visive

Raccolti leggendo il codice e guardando gli screenshot. In ordine di impatto
stimato.

### Flussi e navigazione

1. **Creazione guidata da template irraggiungibile.** Le rotte
   `/bulk-creation/*` sono registrate (`core/routing/app_router.dart:295`) ma
   nessun bottone ci porta. O va collegata (ad esempio dallo stato vuoto di una
   casa) o va rimossa.
   **Risolto** nella PR #20.
2. **Due modi di modificare un viaggio.** `/trips/:id/edit`
   (`app_router.dart:259`) apre `AddTripScreen` in modalità modifica, con
   oggetti e bagagli inline, ma nessuno la usa: dal dettaglio si passa da
   `edit-info` + `edit-items`. È codice morto che può divergere.
   **Risolto** nella PR #20.
3. **Il "back" del dettaglio casa non torna indietro, va alla home.** La freccia
   fa `context.go('/')` (`houses/view/house_detail_screen.dart:521`, anche
   `:356`) invece di `pop`: lo stack si perde e la freccia di sistema si
   comporta in modo diverso da quella a schermo.
   **Risolto** nella PR #20.
4. **Onboarding senza "Salta" né swipe.** `PageView` con
   `NeverScrollableScrollPhysics` (`onboarding/view/onboarding_screen.dart:81`):
   tre tap obbligati su "Avanti", nessun gesto.
   **Risolto** nella PR #20.
5. **La matita in basso a sinistra del dettaglio casa apre un menu, non
   l'editor** (`house_detail_screen.dart:640`, `Icons.edit`), e il menu contiene
   anche "Elimina". L'icona promette un'azione diversa da quella che fa.
   **Risolto** nella PR #20.
6. **Destinazione del viaggio: il default è "Altra località", ma il testo sotto
   parla della casa di destinazione** ("Con una casa di destinazione, gli
   oggetti… compaiono lì come temporanei") anche quando la casa non è
   selezionata (`trips/view/trip_info_form.dart`, `trips.destination_benefit`).
   Si legge come un'istruzione sul campo sbagliato.
   **Risolto** nella PR #20.

### Coerenza con il design system

7. **Bottom sheet scritti a mano invece dei componenti condivisi.** 17 chiamate
   dirette a `showModalBottomSheet` in `lib/features`. In particolare:
   - il sheet fotocamera/galleria è copiato tre volte
     (`tour/view/ai_onboarding_intro_screen.dart:44`,
     `ai_input/view/ai_clothing_sandbox_screen.dart:47`,
     `ai_input/view/ai_results_screen.dart:107`);
   - i picker di quantità, casa e spazio del form oggetto
     (`items/view/item_form_content.dart:118`, `:428`, `:524`) e la scelta casa
     dell'import AI (`ai_results_screen.dart:387`) usano `ListTile` crudi invece
     di `DsPickerSheet`;
   - "Gestisci casa" (`houses/view/house_manage_sheet.dart:20`) non ha né handle
     né titolo, a differenza dei form con `StandardBottomSheetLayout`.
   **Risolto** nella PR #20.
8. **Selettore bagagli con `FilterChip`** (`trips/view/add_trip_screen.dart:482`, file poi rimosso)
   mentre il resto dell'app usa `AppPillTab` per scelte a pillola.
   **Risolto** nella PR #20.
9. **Altezze delle pill tab diverse fra schermate.** `height: 40` fisso nel
   dettaglio casa (`house_detail_screen.dart:738`), nel dettaglio viaggio
   (`trips/view/trip_detail_screen.dart:113`) e nel selettore oggetti
   (`trips/view/trip_items_selector.dart:162`, `:203`, file poi rimosso); default altrove (tab
   Viaggi).
   **Risolto** nella PR #20.
10. **Valori numerici fissi fuori dai token**, ad esempio:
    `houses/view/houses_screen.dart:151` (raggio `cardBorderRadius + 4`, solo qui),
    `:210-256` (icone 14/16, gap 4/6); `items/view/item_card.dart:47-80`;
    `items/widgets/category_pill.dart:47`; `items/widgets/rapid_fire_input.dart:174`,
    `:312-322`; `profile/widgets/sync_details_dialog.dart:63` e
    `trips/view/trip_picker_sheet.dart:96` (`EdgeInsets.all(16)`);
    `shared/widgets/main_shell.dart:411` (`spacingSm + 2`) e `:415`
    (`responsiveFont(15)`, fuori scala).
   **Risolto** nella PR #20.

### Testi e localizzazione

11. **Stringhe non tradotte o in inglese nella UI italiana**:
    `'Errore. Riprova.'` scritto nel codice
    (`onboarding/view/onboarding_screen.dart:63`); "Pack Log" scritto nel codice
    nel login (`auth/view/login_screen.dart:175`); "AI Scan", "Default" (spazio
    generico) e "Toiletries" (categoria) appaiono in inglese negli screenshot.
   **Risolto** nella PR #20. "Toiletries" resta in inglese per scelta (2026-10-11).
12. **Nomi delle case incoerenti nell'import AI.** La scelta casa e la CTA usano
    `house.name` (`ai_results_screen.dart:421`, `:341`) mentre il resto
    dell'app usa `displayName`.
   **Risolto** nella PR #20.

### Layout

13. **Overflow nell'input rapido.** Con l'input espanso, la riga dei
    suggerimenti di categoria sfora di 15 px a 412 dp
    (`items/widgets/rapid_fire_input.dart:175`, segnalato nel manifest di
    `04-dettaglio-casa/04-*`).
   **Risolto** nella PR #20.
14. **Il contenuto passa sotto la barra flottante.** Negli screenshot di
    dettaglio casa, dettaglio viaggio e profilo l'ultima riga visibile scorre
    dietro la CTA/tab bar senza sfumatura né separazione. È voluto
    (`navBarReservedHeight`), ma senza un'ombra o un fade la barra sembra
    appoggiata sopra il testo.
   **Non si fa** (2026-10-11): il contenuto sotto la barra è voluto, niente sfumatura.
15. **Profilo: "Esci" ed "Elimina il mio account" hanno lo stesso peso visivo**
    (due `UniversalActionBar` a tutta larghezza,
    `profile/view/profile_screen.dart:375`, `:389`). L'azione distruttiva e
    irreversibile sta subito sotto quella comune.
   **Risolto** nella PR #20.
16. **Errore parziale dell'import AI**: il link "Riprova" arancione sul box rosa
    ha poco contrasto (vedi `06-import-ai/06-*`).
   **Risolto** nella PR #20.

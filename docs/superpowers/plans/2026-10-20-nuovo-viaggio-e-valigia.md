# Nuovo viaggio (passo 1) e pagina valigia · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** sostituire il wizard del nuovo viaggio con il passo 1 "Viaggio" (dove, quando, tappe in catena, nome; salva alla fine) e sostituire "Modifica oggetti" con la pagina valigia (riepilogo, bagagli, oggetti), che è anche il passo 2.

**Architecture:**
- **Logica pura:** la catena delle tappe sta in un modello puro testato (`TripDraft`). Il passo 1 è uno schermo che compone widget piccoli: ricerca unica di case e luoghi, foglio della tappa, foglio del calendario estratto da quello attuale.
- **Pagina valigia:** prende la rotta `/trips/:id/edit-items`.
- **Dati:** `TripLeg` riceve campi facoltativi nel JSON delle tappe. Niente cambi allo schema del database né al payload di sincronizzazione.

**Tech Stack:** Flutter 3.38, Riverpod 2.5 (code-gen), Freezed, GoRouter 14, easy_localization (it-IT, en-US), mocktail.

**Spec:**
- `docs/superpowers/specs/2026-10-20-nuovo-viaggio-passo-1-design.md` (passo 1, comprese le sezioni 9 e 10);
- `docs/superpowers/specs/2026-10-20-pagina-valigia-design.md` (pagina valigia).

**Il meteo è escluso da questa PR** (decisione dell'utente del 20/10): la pagina valigia lascia libero il posto del blocco Meteo, senza segnaposto visibili. Esclusa anche la strada AI: il posto del bottone AI resta vuoto.

Mock (usa e getta, solo come riferimento visivo) in `docs/superpowers/mock/viaggi/`:
- `nuovo-viaggio-due-passi-chiaro.png`;
- `nuovo-viaggio-tappe-e-foglio-crea.png`, le prime quattro schermate (le ultime due riguardano il foglio Crea, fuori da questa PR);
- `nuovo-viaggio-bottone-ai-e-dati-mancanti.png`, la terza schermata;
- `new_trip_mock.dart.txt`, il codice del mock.

## Global Constraints

- **Testi:** **sempre** nei dizionari `assets/translations/it-IT.json` e `en-US.json`, con le stesse chiavi in entrambi. Nessuna stringa visibile nel codice. Plurali con `'chiave'.plural(n)`, con chiavi `one`/`other`.
- **Design system, sempre:**
  - spaziature `context.spacingXs/Sm/Md/Lg`, icone `context.iconSizeSm/Md/Lg`, misure `context.responsive(x)`;
  - raggi `AppConstants.*` e colori da `Theme.of(context).colorScheme`;
  - superficie dei gruppi `context.groupSurface`;
  - componenti esistenti: `DsButton` (con `onDisabledTap`), `DsLinkButton`, `DsSheetHeader`, `DsGroupHeader`, `DsEmptyState`, `DsPickerSheet`, `QuantityStepper`, `DialogHelpers.showConfirmation`, `ErrorRetryDialog.executeWithRetry`, `TripItineraryView`, `buildItinerary`, `tripDestinationName`.
  - Niente componenti o valori una tantum quando esiste l'equivalente.
- **Arancio:** solo sul bottone primario della schermata e sulle caselle di selezione. Indicatore dei passi, pillole dei bagagli e selettore di casa sono neutri.
- **Niente snackbar per gli errori di compilazione:** il campo mancante si colora (`colorScheme.error`) e sotto compare il messaggio.
- **Date in catena, ritorno automatico** (spec passo 1, §10.2): la tappa *i* inizia alla fine della tappa *i-1*, e il ritorno è la fine dell'ultima.
- **Obbligatori:** meta e date. Le uscite del passo 1 ("Avanti: prepara la valigia" e "Prepara la valigia più tardi") salvano solo con meta e date e senza tappe a zero notti.
- **Regole di progetto (`CLAUDE.md`):**
  - Provider → Repository → DAO;
  - `context.push` per dettagli e form;
  - `build_runner` dopo modifiche a Freezed o ai provider;
  - test aggiornati per ogni file toccato.
- **Git:** branch `feat/viaggi-nuovo-viaggio` (contiene già due commit sulla cartolina: non toccarli). Niente push, niente `git worktree`. I file non tracciati dell'utente non si toccano: `.claude/launch.json`, `.codex/`, `design-previews/`, `package-lock.json`.
- **A ogni task:** `dart format` sui file toccati, `dart analyze lib test` senza problemi nuovi, test del task verdi. Non vanno messe in stage le modifiche spurie ai `*.g.dart` di file non toccati.

## Review Focus

1. **Catena dopo un'eliminazione** a metà o in fondo: date coerenti e ritorno aggiornato (test nel Task 2).
2. **Meta cambiata** dopo aver aggiunto tappe e cambiato a mano il nome: il nome non viene sovrascritto (Task 2 e 7).
3. **Pagina valigia aperta da un viaggio con la checklist avanzata:** il salvataggio non azzera `isChecked` (Task 9).
4. **Uscita dal passo 1** con il solo nome proposto: nessuna conferma. Con una meta scelta: conferma (Task 7).
5. **Una casa sola che è anche la meta:** la pagina valigia mostra comunque i suoi oggetti, senza errori (Task 9).

---

### Task 1: Le tappe salvano coordinate o casa

**Files:**
- Modify: `lib/features/trips/model/trip_leg.dart`. Poi `dart run build_runner build --delete-conflicting-outputs`.
- Modify: `lib/features/trips/model/trip_postcard.dart` (`buildItinerary`).
- Modify: `lib/features/trips/view/trips_screen.dart` e `lib/features/trips/view/widgets/postcard/trip_postcard.dart`: passano i nomi delle case all'itinerario.
- Test: `test/features/trips/model/trip_leg_test.dart`, `test/features/trips/model/trip_postcard_test.dart`.

**Interfaces:**
- Produces:
  - `TripLeg` con i nuovi campi facoltativi `@JsonKey(name: 'lat') double? lat`, `@JsonKey(name: 'lon') double? lon`, `@JsonKey(name: 'country') String? country`, `@JsonKey(name: 'house_id') String? houseId`;
  - `List<ItineraryEntry> buildItinerary(TripModel trip, {required String destination, int maxPlaces = 3, Map<String, String> houseNames = const {}})`: per una tappa con `houseId` presente nella mappa, il nome è quello della casa; altrimenti si usa `legPlaceName(leg)`;
  - `TripPostcard` riceve `Map<String, String> houseNames` (con default `const {}`) e lo passa a `buildItinerary`; la tab Viaggi passa la mappa che costruisce già.

- [ ] **Step 1: Test.**
  - Andata e ritorno JSON di `TripLeg` con tutti i campi nuovi, e senza nessuno (le chiavi assenti restano null).
  - Un JSON vecchio, solo `id`, `location_display_name`, `from` e `to`, si legge.
  - `buildItinerary` con una tappa `houseId: 'h1'` e `houseNames: {'h1': 'Casa al mare'}` mostra "Casa al mare". Senza mappa mostra `legPlaceName`.
- [ ] **Step 2:** Esegui. Atteso: FAIL.
- [ ] **Step 3:** Implementa, poi build_runner.
- [ ] **Step 4:** `flutter test test/features/trips/`. Atteso: PASS.
- [ ] **Step 5:** Commit: `"Viaggi: le tappe salvano coordinate o la casa"`.

### Task 2: Bozza del viaggio con la catena delle tappe

**Files:**
- Create: `lib/features/trips/model/trip_draft.dart` (Dart puro, niente Flutter tranne i tipi del modello).
- Test: `test/features/trips/model/trip_draft_test.dart`.

**Interfaces:**
- Consumes: `TripLeg` (Task 1), `LocationSuggestionModel`, `TripModel`.
- Produces (usati dai Task 6, 7):
  ```dart
  /// Un posto scelto: una casa o un luogo della ricerca.
  class DraftPlace {
    final String? houseId;                    // casa
    final String name;                        // nome mostrato (casa: displayName; luogo: displayName completo)
    final LocationSuggestionModel? location;  // luogo (con lat/lon/country se presenti)
    const DraftPlace.house({required String id, required this.name}) ...;
    const DraftPlace.location(LocationSuggestionModel loc) ...;
    String get shortName;                     // casa: name; luogo: city ?? parte prima della virgola
  }
  class DraftStop { final DraftPlace place; final DateTime end; }
  class TripDraft {                           // immutabile, copyWith
    final DateTime? departure;
    final List<DraftStop> stops;              // stops[0] = meta (può mancare finché non scelta)
    final DraftPlace? destination;            // meta, anche prima delle date
    final String name;                        // testo del campo
    final bool nameEdited;                    // true se l'utente l'ha cambiato a mano
    const TripDraft.empty();
    TripDraft withDestination(DraftPlace place);       // se !nameEdited, name = place.shortName
    TripDraft withFirstDates(DateTime start, DateTime end);
    TripDraft withName(String text);                   // nameEdited = true (false se text vuoto)
    TripDraft addStop(DraftPlace place, DateTime end); // in coda
    TripDraft updateStop(int index, {DraftPlace? place, DateTime? end}); // index >= 1
    TripDraft removeStop(int index);                   // index >= 1
    DateTime? stopStart(int index);                    // 0 → departure; i → end di i-1
    DateTime? get returnDate;                          // end dell'ultima
    DateTime? get lastEnd;                             // per proporre l'inizio della nuova tappa
    Set<int> get stopsWithoutNights;                   // indici con end <= start (calendario)
    bool get hasDestination; bool get hasDates;
    bool get canSave;                                  // destinazione && date && stopsWithoutNights.isEmpty
    bool get hasUserInput;                             // meta, date, tappe, o nameEdited
    TripModel toTripModel({required String id, required DateTime now});
  }
  ```

Regole (spec passo 1, §4.4, §4.5, §10.2, §10.4):
- **`toTripModel`:**
  - `name` è `name.trim()`, o `destination.shortName` se vuoto;
  - `departureDateTime` è `departure`, `returnDateTime` è `returnDate`;
  - meta-casa: `destinationHouseId` più `destinationLocation = LocationSuggestionModel(placeId: '', displayName: <nome casa>)`, come fa oggi `add_trip_screen.dart`;
  - meta-luogo: `destinationLocation` (con le sue coordinate);
  - `legs`: dalla seconda tappa in poi, `TripLeg(id: uuid, locationDisplayName: place.name, from: stopStart(i), to: stops[i].end, lat, lon, country, houseId)`;
  - `items` e `luggages` vuoti.
- **Date:** solo giorno, mezzanotte locale. `stopsWithoutNights` confronta giorni di calendario.
- **`removeStop(i)`:** la tappa *i+1* parte da `stopStart(i)`, cioè la fine di *i-1*, e tiene la sua fine.
- **`updateStop(i, end:)`:** sposta solo l'inizio della tappa *i+1*.

- [ ] **Step 1: Test** (date fisse, una regola per test):
  - nome che segue la meta finché `nameEdited` è falso; una meta nuova dopo un nome a mano non cambia il nome;
  - `withFirstDates`, poi `addStop(Sintra, 3 nov)`: `stopStart(1)` è la fine della prima, `returnDate` è il 3 nov;
  - `updateStop(1, end:)` sulla prima di tre tappe sposta solo `stopStart(2)`;
  - `removeStop` a metà e in fondo: catena ricucita e `returnDate` aggiornato;
  - `stopsWithoutNights` dopo aver allungato la prima tappa oltre la fine della seconda;
  - `canSave` falso senza meta, senza date, o con tappe a zero notti;
  - `hasUserInput` falso con la bozza vuota e anche se il nome è solo quello proposto;
  - `toTripModel` con meta-luogo più una tappa-casa più una tappa-luogo: campi, date e coordinate come sopra; nome vuoto diventa `shortName`.
- [ ] **Step 2:** Esegui. Atteso: FAIL.
- [ ] **Step 3:** Implementa.
- [ ] **Step 4:** Esegui. Atteso: PASS.
- [ ] **Step 5:** Commit: `"Viaggi: bozza del viaggio con le tappe in catena"`.

### Task 3: Indicatore dei passi

**Files:**
- Create: `lib/shared/widgets/ds_steps.dart`, con export da `lib/shared/widgets/widgets.dart`.
- Modify: i due dizionari.
- Test: `test/shared/widgets/ds_steps_test.dart`.

**Interfaces:**
- Produces: `DsSteps({Key? key, required List<String> labels, required int current})`.
  - Passi prima di `current`: cerchio pieno `onSurface` con spunta (`Icons.check`).
  - Passo `current`: cerchio pieno `onSurface` con il numero (testo `surface`) ed etichetta in grassetto.
  - Passi dopo: cerchio con contorno `outline`, numero ed etichetta `onSurfaceVariant`.
  - Tra un passo e l'altro un `Divider` `outlineVariant` che si allarga. Riferimento: `_Steps` nel mock.
- Testi: `trips.new.step_trip` "Viaggio" / "Trip"; `trips.new.step_suitcase` "Valigia" / "Suitcase".

- [ ] **Step 1: Test.** Con `current: 1` su due passi: il primo mostra `Icons.check` e non "1"; il secondo mostra "2". Con `current: 0`: niente spunte.
- [ ] **Step 2–4:** RED, implementa, GREEN.
- [ ] **Step 5:** Commit: `"DS: indicatore dei passi"`.

### Task 4: Calendario in un foglio dal basso

**Files:**
- Create: `lib/features/trips/view/widgets/trip_calendar.dart`: il calendario a scorrimento estratto da `trip_date_range_screen.dart`.
- Create: `lib/features/trips/view/widgets/trip_dates_sheet.dart`.
- Modify: `lib/features/trips/view/trip_date_range_screen.dart`, che userà il widget estratto. Comportamento invariato: lo usa ancora "Modifica informazioni".
- Modify: i due dizionari.
- Test: `test/features/trips/view/trip_date_range_screen_test.dart` (deve passare senza modifiche), `test/features/trips/view/widgets/trip_dates_sheet_test.dart`.

**Interfaces:**
- Produces:
  - `TripCalendar({required TripDateRange selection, required ValueChanged<DateTime> onDaySelected, DateTime? initialMonth, DateTime? firstSelectableDay})`. I giorni prima di `firstSelectableDay` (oltre a quelli passati) sono spenti e non toccabili.
  - `Future<TripDateRange?> showTripRangeSheet(BuildContext context, {DateTime? initialDeparture, DateTime? initialReturn})`: foglio quasi a schermo intero con `DsSheetHeader` ("Quando?"), `TripCalendar`, "Conferma date" in fondo (`DsButton`, attivo solo con l'intervallo completo). La selezione usa `DateRangeSelectionNotifier` come la schermata.
  - `Future<DateTime?> showTripEndSheet(BuildContext context, {required DateTime start, DateTime? initialEnd})`: stesso foglio, ma l'inizio è fisso (mostrato come partenza della selezione e non modificabile), si sceglie solo la fine (dopo `start`) e "Conferma" restituisce la fine.
- Testi: `trips.new.when` "Quando?" / "When?"; `trips.new.confirm_dates` "Conferma date" / "Confirm dates" (riusa la chiave esistente se c'è già un "Conferma date").

- [ ] **Step 1: Test.**
  - Il foglio intervallo restituisce le due date toccate.
  - Il foglio fine: toccare un giorno prima di `start` non cambia niente, toccarne uno dopo e confermare restituisce quel giorno.
  - Il test esistente della schermata passa.
- [ ] **Step 2–4:** RED, implementa, GREEN.
- [ ] **Step 5:** Commit: `"Viaggi: calendario estratto, anche in un foglio"`.

### Task 5: Ricerca unica di case e luoghi

**Files:**
- Create: `lib/shared/services/location_search_service.dart`, con la chiamata a `geocode-proxy` spostata da `location_autocomplete_field.dart`.
- Modify: `lib/shared/widgets/location_autocomplete_field.dart`, che usa il servizio. Comportamento invariato.
- Create: `lib/features/trips/view/widgets/place_search.dart`.
- Modify: i due dizionari.
- Test: `test/features/trips/view/widgets/place_search_test.dart`.

**Interfaces:**
- Produces:
  - `class LocationSearchService { Future<List<LocationSuggestionModel>> search(String query, {required String lang}); }`, con `locationSearchServiceProvider` (Riverpod, `keepAlive`) per poterlo sostituire nei test. Stessa logica di oggi: JWT, `apikey`, `limit 15`, lista vuota senza sessione o con errore.
  - `PlaceSearch({Key? key, required ValueChanged<DraftPlace> onSelected, String? hintText, bool autofocus = false})`: un campo; sotto, dentro la pagina (non in overlay), la lista dei risultati:
    - a campo vuoto e attivo, il gruppo "Le tue case" (`DsGroupHeader` più righe con l'icona della casa `HouseIcons.getIcon(iconName)` e `displayName`);
    - scrivendo, le case filtrate per nome (senza distinzione di maiuscole) e sotto i luoghi dal servizio, con attesa di 300 ms tra un tasto e l'altro;
    - a scelta fatta, `onSelected` e la lista si chiude.
  - `DraftPlace` viene dal Task 2.
- Testi: `trips.new.where_hint` "Una tua casa o una città" / "One of your homes or a city"; `trips.new.your_homes` "Le tue case" / "Your homes"; `trips.new.places` "Luoghi" / "Places".

- [ ] **Step 1: Test** (servizio finto via override del provider):
  - al tocco compaiono tutte le case;
  - scrivendo "mar" resta "Casa al mare" e dopo l'attesa compaiono i luoghi del servizio finto;
  - toccare una casa chiama `onSelected` con `DraftPlace.house`, toccare un luogo con `DraftPlace.location`.
- [ ] **Step 2–4:** RED, implementa, GREEN. Anche `flutter test test/shared/`.
- [ ] **Step 5:** Commit: `"Viaggi: ricerca unica di case e luoghi"`.

### Task 6: Foglio "Nuova tappa"

**Files:**
- Create: `lib/features/trips/view/widgets/stop_sheet.dart`. Il foglio vecchio `trip_leg_sheet.dart` e `TripLegsSection` restano, perché li usa "Modifica informazioni".
- Modify: i due dizionari.
- Test: `test/features/trips/view/widgets/stop_sheet_test.dart`.

**Interfaces:**
- Consumes: `PlaceSearch` (Task 5), `showTripEndSheet` (Task 4), `DraftPlace` e `DraftStop` (Task 2).
- Produces: `Future<StopSheetResult?> showStopSheet(BuildContext context, {required DateTime start, required String previousName, DraftStop? initial})`, con `sealed class StopSheetResult` / `StopSaved(DraftStop stop)` / `StopRemoved()`.
  - Titolo "Nuova tappa", o "Modifica tappa" con `initial`.
  - "Dove?" usa `PlaceSearch`.
  - "Quando?" è un campo che apre `showTripEndSheet(start:)`; mostra "inizio – fine" e le notti.
  - Aiuto calcolato: `trips.new.stop_hint` "Parti da {} {}. Il ritorno diventa {}."
  - `DsButton` "Aggiungi tappa", o "Salva tappa" con `initial`, attivo solo con posto e fine.
  - Con `initial`, sotto c'è `DsLinkButton` "Elimina tappa", che restituisce `StopRemoved`.
- Testi: `trips.new.stop_new` "Nuova tappa" / "New stop"; `trips.new.stop_edit` "Modifica tappa" / "Edit stop"; `trips.new.where_stop` "Dove?" / "Where?"; `trips.new.stop_hint` (it sopra; en "Leaving {} on {}. You'll be back on {}."); `trips.new.stop_add` "Aggiungi tappa" / "Add stop"; `trips.new.stop_save` "Salva tappa" / "Save stop"; `trips.new.stop_remove` "Elimina tappa" / "Remove stop".

- [ ] **Step 1: Test.**
  - Il bottone è spento senza posto o senza fine.
  - Con posto e fine scelti (calendario finto via la funzione del foglio, o interazione reale) restituisce `StopSaved` con quella fine.
  - Con `initial`, "Elimina tappa" restituisce `StopRemoved`.
- [ ] **Step 2–4:** RED, implementa, GREEN.
- [ ] **Step 5:** Commit: `"Viaggi: foglio della tappa con la ricerca unica"`.

### Task 7: Il passo 1 "Viaggio"

**Files:**
- Create: `lib/features/trips/view/new_trip_screen.dart`.
- Modify: `lib/core/routing/app_router.dart`: `/new-trip` mostra `NewTripScreen` dentro lo stesso `TourTriggerWrapper`.
- Delete: `lib/features/trips/view/add_trip_screen.dart` e `test/features/trips/view/add_trip_screen_validation_test.dart`. Prima di toccare `trip_form_validation.dart` e il suo test, controlla con `git grep` se li usa ancora "Modifica informazioni": se sì restano, altrimenti vanno via.
- Modify: i due dizionari.
- Test: `test/features/trips/view/new_trip_screen_test.dart`.

**Interfaces:**
- Consumes: Task 2–6, `TripItineraryView`, `buildItinerary` (con `houseNames`), `DialogHelpers.showConfirmation`, `ErrorRetryDialog.executeWithRetry`, `TripNotifier.addTrip`.
- Produces: `NewTripScreen()`. Dopo il salvataggio:
  - "Avanti": `context.go('/trips')`, poi `context.push('/trips/<id>/edit-items?from=new')`;
  - "Più tardi": `context.go('/trips?focus=<id>')`.

Layout (spec passo 1, §4.1–4.6, con i riferimenti del mock):
- **In cima:** AppBar `trips.new.title` "Nuovo viaggio", poi `DsSteps(labels: [step_trip, step_suitcase], current: 0)`. Il posto del bottone AI resta vuoto.
- **Le sezioni:** titoli di sezione in `titleLarge` w800:
  - **"Dove vai?":** `PlaceSearch`. A scelta fatta diventa un campo con icona, nome e X.
  - **"Quando?":** un campo che apre `showTripRangeSheet` e mostra "gio 29 ott – dom 1 nov" con le notti a destra.
  - **"Itinerario":** prima di meta e date mostra il testo `trips.new.itinerary_empty`. Dopo, un blocco su `groupSurface` con:
    - `TripItineraryView(entries: buildItinerary(draft.toTripModel(...), destination: draft.destination!.shortName, houseNames: ...))`;
    - sotto `DsLinkButton` "Aggiungi tappa", che apre `showStopSheet(start: draft.lastEnd!, ...)`;
    - sotto l'aiuto `trips.new.stops_tip`;
    - una riga di tappa nell'itinerario apre `showStopSheet` con `initial`, solo per le tappe successive alla meta;
    - le tappe con zero notti mostrano sotto il blocco `trips.new.stop_no_nights` in `colorScheme.error`, con il nome della tappa.
  - **"Nome del viaggio":** `TextField` con `draft.name` e la nota `trips.new.name_hint` sotto.
- **In basso, fisso:**
  - `DsButton` "Avanti: prepara la valigia", con `onPressed` solo se `draft.canSave`, altrimenti `onDisabledTap: _showMissing`;
  - `DsLinkButton` "Prepara la valigia più tardi": se `!canSave` chiama `_showMissing`, altrimenti salva.
  - `_showMissing` accende gli errori sui campi mancanti (`trips.new.where_missing`, `trips.new.when_missing`) e scorre al primo.
- **Uscita senza salvare** (freccia o Indietro di sistema, tramite `PopScope`): se `draft.hasUserInput`, `DialogHelpers.showConfirmation` (`trips.new.discard_title` / `trips.new.discard_message`); altrimenti esce subito.

Testi: `trips.new.title` "Nuovo viaggio" / "New trip"; `trips.new.where` "Dove vai?" / "Where are you going?"; `trips.new.itinerary` "Itinerario" / "Itinerary"; `trips.new.itinerary_empty` "Scegli meta e date: qui compare il tuo itinerario." / "Pick where and when: your itinerary shows up here."; `trips.new.stops_tip` "Visiti più città? Aggiungi una tappa per ognuna: avrai il meteo di ogni tappa." / "Visiting more than one city? Add a stop for each: you'll get the weather for every stop."; `trips.new.name` "Nome del viaggio" / "Trip name"; `trips.new.name_hint` "L'abbiamo preso dalla meta: cambialo se vuoi." / "We took it from your destination: change it if you like."; `trips.new.next` "Avanti: prepara la valigia" / "Next: pack your suitcase"; `trips.new.later` "Prepara la valigia più tardi" / "Pack later"; `trips.new.where_missing` "Scegli dove vai: serve anche per il meteo." / "Choose where you're going: we need it for the weather too."; `trips.new.when_missing` "Scegli andata e ritorno." / "Choose your dates."; `trips.new.stop_no_nights` "{} finisce prima di iniziare: controlla le date." / "{} ends before it starts: check the dates."; `trips.new.discard_title` "Lasciare il nuovo viaggio?" / "Leave this new trip?"; `trips.new.discard_message` "Quello che hai inserito andrà perso." / "What you've entered will be lost.". La chiave `nights` dell'itinerario esiste già.

- [ ] **Step 1: Test** (mock repository come in `edit_trip_info_screen_legs_test.dart`, `LocationSearchService` finto, GoRouter vero con rotte finte per `/trips`, `/trips/:id/edit-items`):
  - a modulo vuoto il tocco su "Avanti" mostra i due messaggi e non chiama `addTrip`;
  - scelta una casa e le date (via il foglio, o con un'interazione minima ma reale), "Avanti" chiama `addTrip` con meta e date e porta a `edit-items?from=new`;
  - "più tardi" porta a `/trips?focus=<id>`;
  - con una meta scelta, Indietro mostra il dialogo; senza niente, esce subito;
  - il campo nome segue la meta finché non lo modifichi.
- [ ] **Step 2–4:** RED, implementa, GREEN. Poi tutta `test/features/trips/`.
- [ ] **Step 5:** Commit: `"Viaggi: nuovo viaggio, passo 1 in ordine di itinerario"`.

### Task 8: La tab Viaggi si apre sul viaggio appena creato

**Files:**
- Modify: `lib/features/trips/view/widgets/postcard/postcard_pile.dart`: aggiungere `int initialIndex = 0`.
- Modify: `lib/features/trips/view/trips_screen.dart`, che legge `focus` da `GoRouterState.of(context).uri.queryParameters`: se l'id è tra i prossimi, la pila parte da lì e il filtro passa su Prossimi.
- Modify: `lib/core/routing/app_router.dart`, solo se serve a far arrivare il parametro.
- Test: `test/features/trips/view/widgets/postcard_pile_test.dart`, `test/features/trips/view/trips_screen_test.dart`.

**Interfaces:**
- Produces: `PostcardPile(..., int initialIndex = 0)`. È usato solo alla creazione dello stato; se è fuori intervallo vale 0.

- [ ] **Step 1: Test.**
  - La pila con `initialIndex: 2` mostra `card 2`.
  - La tab aperta su `/trips?focus=<id del terzo prossimo>` mostra quel viaggio in cima.
- [ ] **Step 2–4:** RED, implementa, GREEN.
- [ ] **Step 5:** Commit: `"Viaggi: la pila si apre sul viaggio appena creato"`.

### Task 9: La pagina valigia

**Files:**
- Create: `lib/features/trips/view/pack_suitcase_screen.dart` (eventuali widget figli in `lib/features/trips/view/widgets/pack/`).
- Modify: `lib/core/routing/app_router.dart`: `/trips/:id/edit-items` mostra `PackSuitcaseScreen(tripId:, fromNewTrip: state.uri.queryParameters['from'] == 'new')`.
- Delete: `lib/features/trips/view/edit_trip_items_screen.dart`, `lib/features/trips/view/trip_items_selector.dart`. Porta sul nuovo schermo i test che li riguardano: `trip_edit_loading_test.dart` (la parte su `EditTripItemsScreen`) e `trip_items_selector_empty_test.dart`.
- Modify: i due dizionari.
- Test: `test/features/trips/view/pack_suitcase_screen_test.dart`.

**Interfaces:**
- Consumes: `DsSteps` (Task 3), `tripNotifierProvider` (`updateTrip`), `houseNotifierProvider`, `itemNotifierProvider(houseId)`, `allLuggagesProvider`, `defaultDestinationHouse` (`create_sheet.dart`), `DsPickerSheet`, `QuantityStepper`, `showLuggagesManagementSheet`, il segnaposto di caricamento ed errore che usa oggi `EditTripItemsScreen` (`trip_edit_placeholder.dart`).
- Produces: `PackSuitcaseScreen({required String tripId, bool fromNewTrip = false})`.

Layout (spec pagina valigia, §4, **senza §4.2 Meteo**; mock "Valigia" in `nuovo-viaggio-due-passi-chiaro.png`):
- **In cima:**
  - AppBar `trips.pack.title` "Prepara la valigia";
  - con `fromNewTrip`, `DsSteps(current: 1)`;
  - il riepilogo in una riga: nome (`headlineSmall` w800), sotto date, notti e luoghi (`buildItinerary`, solo i nomi dei posti, separati da ", "); a destra "-N giorni" (`stampFor`) oppure "in viaggio".
- **Bagagli:** titolo `trips.pack.luggages` "Bagagli".
  - Pillole neutre multiselezione da `allLuggagesProvider` (riferimento: `pill()` del mock).
  - Senza bagagli: testo `trips.pack.no_luggages` più `DsLinkButton` `trips.pack.add_luggages`, che apre `showLuggagesManagementSheet` per la casa mostrata.
- **Cosa porti:** titolo `trips.pack.items` "Cosa porti".
  - Campo ricerca `trips.pack.search_hint` "Cerca negli oggetti", che filtra per nome la casa mostrata.
  - Riga "Da" più la pillola neutra della casa con `Icons.expand_more`: apre `DsPickerSheet`, ma solo se le case sono più di una.
  - Casa iniziale: `defaultDestinationHouse`. Se coincide con `destinationHouseId` del viaggio, la prima altra casa; se non c'è un'altra casa, quella.
  - Oggetti per categoria, in ordine canonico: `DsGroupHeader(label: categoria, count:)` e un blocco `groupSurface`. Ogni riga ha `Checkbox`, il nome e, se l'oggetto è scelto e ha disponibilità maggiore di 1, `QuantityStepper(minValue: 1, maxValue: disponibile)`.
  - Casa vuota: `DsEmptyState` con le azioni dello stato vuoto del vecchio selettore (portale da `trip_items_selector.dart`).
- **In basso:** `DsButton` "Fatto", oppure `trips.pack.done_count` "Fatto · {} oggetti" (plurale).

Stato e salvataggio:
- **Selezione iniziale:** `trip.items`. La selezione è una mappa id → `TripItem`, mantenuta al cambio casa.
- **Spunta di un oggetto nuovo:** `TripItem(id, name, category, quantity: 1, originHouseId: casa mostrata, isChecked: false)`.
- **Oggetto già nel viaggio:** cambiando la quantità si usa `copyWith(quantity:)` e lo snapshot resta, `isChecked` compreso. Togliendo la spunta esce dalla mappa.
- **"Fatto":**
  1. normalizza gli `originHouseId` vuoti come `_normalizeItemOrigins` di oggi;
  2. `updateTrip(trip.copyWith(items:, luggages:, updatedAt:))` dentro `ErrorRetryDialog.executeWithRetry`;
  3. `context.pop()`.
- **Indietro con modifiche** (selezione o bagagli diversi dall'iniziale): `DialogHelpers.showConfirmation` (`trips.pack.discard_title` / `trips.pack.discard_message`).

Testi: `trips.pack.title` "Prepara la valigia" / "Pack your suitcase"; `trips.pack.luggages` "Bagagli" / "Luggage"; `trips.pack.no_luggages` "Non hai ancora bagagli." / "You have no luggage yet."; `trips.pack.add_luggages` "Aggiungi bagagli" / "Add luggage"; `trips.pack.items` "Cosa porti" / "What you're bringing"; `trips.pack.search_hint` "Cerca negli oggetti" / "Search your items"; `trips.pack.from` "Da" / "From"; `trips.pack.done` "Fatto" / "Done"; `trips.pack.done_count` one: "Fatto · {} oggetto", other: "Fatto · {} oggetti" / one: "Done · {} item", other: "Done · {} items"; `trips.pack.days_left` one: "-{} giorno", other: "-{} giorni" / one: "-{} day", other: "-{} days"; `trips.pack.discard_title` "Uscire senza salvare?" / "Leave without saving?"; `trips.pack.discard_message` "Le modifiche alla valigia andranno perse." / "Your suitcase changes will be lost.". Per "in viaggio" si riusa `trips.postcard.traveling`.

- [ ] **Step 1: Test** (mock come in `trip_edit_loading_test.dart`):
  - con `fromNewTrip` c'è `DsSteps`, senza no;
  - gli oggetti del viaggio partono spuntati;
  - una spunta su un oggetto di un'altra casa, poi il cambio casa: la scelta resta e "Fatto · N" la conta;
  - salvando un viaggio con un oggetto `isChecked: true` di cui si cambia la quantità, `isChecked` resta vero;
  - lo stepper non supera il disponibile;
  - bagagli scelti salvati in `luggages`;
  - Indietro con modifiche mostra il dialogo;
  - una casa sola, che è la meta, mostra i suoi oggetti.
- [ ] **Step 2–4:** RED, implementa, GREEN. Poi `flutter test` completo e `dart analyze lib test`.
- [ ] **Step 5:** Commit: `"Viaggi: pagina valigia al posto di Modifica oggetti"`.

### Task 10: Screenshot, documentazione dei flussi e pulizia

**Files:**
- Modify: `test/screenshots/ui_screenshots_test.dart` (flussi `08-nuovo-viaggio` e `09-dettaglio-viaggio`), più l'eventuale supporto in `test/screenshots/support/` per il `LocationSearchService` finto.
- Modify: `docs/ui-flows.md` (tracciato con `git add -f`).
- Modify: i due dizionari: togli le chiavi non più usate (verifica ognuna con `git grep` su `lib/` e `test/`).

Scenari, chiaro e scuro:
- **08-nuovo-viaggio:**
  1. vuoto;
  2. tocco su "Dove vai?" con le case;
  3. compilato con una tappa (casa o luogo);
  4. foglio "Nuova tappa" vuoto;
  5. foglio compilato;
  6. due tappe;
  7. dati mancanti dopo il tocco su "Avanti";
  8. tappa a zero notti;
  9. foglio delle date.
- **09-dettaglio-viaggio:** al posto di "modifica oggetti":
  1. pagina valigia da "Modifica oggetti";
  2. pagina valigia dal passo 1 (con l'indicatore);
  3. con scelte e quantità;
  4. dopo un cambio casa.

- [ ] **Step 1:** Aggiorna scenari e supporto.
- [ ] **Step 2:** `flutter test test/screenshots/ui_screenshots_test.dart --dart-define=UI_SCREENSHOTS=true --plain-name "08-nuovo-viaggio"` e lo stesso per `"09-dettaglio-viaggio"`. Atteso: PASS. Apri le immagini e confrontale con i mock: niente overflow, arancio solo sui bottoni principali e sulle caselle.
- [ ] **Step 3:** Esegui gli altri flussi che passano dal nuovo viaggio o da "Modifica oggetti" (`07-viaggi` per il foglio Crea e le CTA, `00`/onboarding se usa `/new-trip`).
- [ ] **Step 4:** Aggiorna le sezioni 08 e 09 di `docs/ui-flows.md`.
- [ ] **Step 5:** Pulisci i dizionari. Poi `flutter test` completo e `dart analyze lib test`.
- [ ] **Step 6:** Commit: `git add -f docs/ui-flows.md` più il resto, messaggio `"Screenshot e flussi: nuovo viaggio e pagina valigia"`.

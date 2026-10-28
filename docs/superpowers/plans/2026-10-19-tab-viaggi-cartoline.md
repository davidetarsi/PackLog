# Tab Viaggi a cartoline · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sostituire la tab Viaggi (hero + griglia masonry) con una pila di cartoline per i prossimi viaggi e un album di cartoline piccole con "Riusa" per Passati e Salvati.

**Architecture:** La logica (itinerario, francobollo, bottone, ordinamenti, gruppi) sta in funzioni pure testabili in `lib/features/trips/model/trip_postcard.dart`. I pezzi grafici stanno in `lib/features/trips/view/widgets/postcard/`. "Riusa" aggiunge un metodo dedicato DAO → repository → notifier, senza toccare la copia esistente né lo schema. `TripsScreen` diventa un compositore sottile.

**Tech Stack:** Flutter 3.38, Riverpod 2.5 (code-gen), Drift, Freezed, GoRouter 14, easy_localization (it-IT, en-US), mocktail.

**Spec:** `docs/superpowers/specs/2026-10-19-tab-viaggi-cartoline-design.md`. Riferimenti visivi in `docs/superpowers/mock/viaggi/`: la cartolina è `cartolina-con-itinerario-base.png`; l'album è la colonna B di `passati-salvati-A-righe-B-album.png`. Il codice del mock usa e getta è in `docs/superpowers/mock/viaggi/trips_mock.dart.txt`. È una fonte di ispirazione per le forme (`_StampPainter`, `_StampAndPostmark`, `_CancelWaves`, `_Itinerary`, `_PostcardPile`, `_AlbumPostcard`, `_ItineraryPostcard`), **non** codice da copiare: usa stringhe scritte a mano e valori magici che qui sono vietati.

## Global Constraints

- **Testi:** **sempre** nei dizionari `assets/translations/it-IT.json` e `en-US.json`, con le stesse chiavi in entrambi. Nessuna stringa visibile scritta nel codice, nemmeno "PACKLOG". Per i plurali si usa `'chiave'.plural(n)`, con chiavi `one`/`other`.
- **Design system:** **sempre** valori e componenti del design system:
  - spaziature `context.spacingXs/Sm/Md/Lg`, icone `context.iconSizeSm/Md/Lg`, misure scalate `context.responsive(x)`;
  - raggi `AppConstants.*`, colori da `Theme.of(context).colorScheme`;
  - componenti esistenti: `DsButton`, `DsEmptyState`, `DsGroupHeader`, `AppPillTab`, `showEntityContextMenu` + `EntityActionHandler`, `ShellTabScaffold`, `TabHeader`.
  - Niente componenti o valori una tantum quando esiste l'equivalente. Fanno eccezione le costanti geometriche interne a un painter (dentini, onde): stanno come `static const` nominate nel painter.
- **Arancio:** solo su `DsButton` primario della cartolina in cima. Francobollo, anello, filtri, "Riusa", timbri, puntini: tutti neutri (`onSurface`, `onSurfaceVariant`, `outline`, `outlineVariant`, `surfaceContainerHigh`).
- **Cartolina in cima:** sempre dritta, rotazione 0 a riposo. Le cartoline sotto sono solo carta senza contenuto.
- **Itinerario:** niente "oggi" e niente luogo di partenza.
- **Database:** nessuna modifica allo schema né al payload di sync. `duplicateTrip` resta identico.
- **Regole di progetto:** quelle di `CLAUDE.md`.
  - Provider → Repository → DAO; niente accesso al DB dalla UI.
  - `context.push` per aprire dettagli e form.
  - Dopo modifiche a provider o modelli generati: `dart run build_runner build --delete-conflicting-outputs`.
- **Git:** si lavora sul branch `feat/viaggi-cartoline` partito da `origin/develop`; niente push su `develop`/`main`; mai `git worktree add`. Le cartelle e i file non tracciati dell'utente non si toccano (`.claude/launch.json`, `.codex/`, `design-previews/`, `package-lock.json`).
- **A ogni task:** `dart format` sui file toccati, `dart analyze` senza nuovi problemi, test del task verdi.

## Review Focus

1. **Viaggio con una sola meta e senza tappe:** l'itinerario mostra Andata, meta (notti, periodo) e Ritorno, senza "Spostamento" (test nel Task 1).
2. **Viaggio senza date** (creato da "Riusa", o vecchi dati):
   - francobollo "da decidere", senza timbro;
   - righe Andata e Ritorno con "da decidere", nessuna notte;
   - sta in fondo alla pila;
   - nell'album, francobollo con il segnalibro.
   - Test nei Task 1, 3 e 5.
3. **La lista dei prossimi cambia mentre sei sulla 3ª cartolina** (sync, eliminazione dal menu): la pila torna alla prima senza errori di indice (test nel Task 4).
4. **Nomi lunghi:** case con virgole ("Baita dei nonni a Courmayeur, Valle d'Aosta") e più bagagli. La casa resta intera; il titolo va al massimo su 3 righe; i bagagli al massimo su 2 righe con ellissi; niente overflow (test nel Task 3 con questi dati).
5. **Uscita dalla modifica dopo "Riusa" senza salvare:** il viaggio copiato sparisce. Un salvataggio riuscito invece **non** lo elimina (test nel Task 6).

---

### Task 1: Logica pura della cartolina

**Files:**
- Create: `lib/features/trips/model/trip_postcard.dart`
- Test: `test/features/trips/model/trip_postcard_test.dart`

**Interfaces:**
- Consumes: `TripModel`, `TripLeg` (esistenti).
- Produces (usati dai Task 3, 4, 5, 7):
  ```dart
  enum ItineraryKind { departure, place, transfer, moreStops, ret }
  class ItineraryEntry {            // immutabile, const ctor, == e hashCode
    final ItineraryKind kind;
    final String? name;             // solo place
    final DateTime? date;           // departure, transfer, ret
    final DateTime? from, to;       // solo place
    final int? hiddenStops;         // solo moreStops
  }
  String legPlaceName(TripLeg leg);                       // prima della prima virgola, trim
  String tripDestinationName(TripModel trip, {String? houseName});
  int? nightsBetween(DateTime? from, DateTime? to);       // giorni di calendario, null se manca una data
  List<ItineraryEntry> buildItinerary(TripModel trip, {required String destination, int maxPlaces = 3});
  enum StampKind { daysLeft, today, traveling, noDate }
  ({StampKind kind, int? days}) stampFor(TripModel trip, DateTime now);
  enum PostcardCta { prepare, ready, continuePacking }
  PostcardCta ctaFor(TripModel trip);
  List<TripModel> upcomingTrips(List<TripModel> trips);
  List<TripModel> pastTrips(List<TripModel> trips);
  List<TripModel> savedTrips(List<TripModel> trips);
  List<MapEntry<int, List<TripModel>>> groupByYear(List<TripModel> trips);
  ```

Regole, dalla spec (sezioni 3, 4.2, 4.3, 5):

- **`tripDestinationName`:** `houseName`, se non è null né vuoto, intero e senza tagli. Altrimenti `destinationLocation.city`, poi la parte di `destinationLocation.displayName` prima della prima virgola, poi `trip.name`.
- **`buildItinerary`, i luoghi:**
  - il primo luogo è la meta: `from = departureDateTime`, `to` = `from` della prima tappa datata, altrimenti `returnDateTime`;
  - poi le tappe datate in ordine di `from` crescente, poi quelle senza `from` nell'ordine di inserimento, con `name = legPlaceName`, `from`/`to` della tappa.
- **`buildItinerary`, le righe:** `departure(date: departure)`, primo luogo; per ogni luogo successivo `transfer(date: luogo.from)` e poi il luogo; infine `ret(date: returnDateTime)`.
- **Più di `maxPlaces` luoghi:** restano `departure`, primo luogo, `moreStops(hiddenStops: luoghi - 2)`, `transfer(date: ultimo.from)`, ultimo luogo, `ret`.
- **`stampFor`:**
  - `isActive` → `traveling`;
  - senza partenza → `noDate`;
  - giorni di calendario tra oggi e la data di partenza: `0` → `today`, altrimenti `daysLeft` con `days`.
- **`ctaFor`:** nessun oggetto → `prepare`; tutti spuntati → `ready`; altrimenti `continuePacking`. Lo stato "in corso" non conta.
- **`upcomingTrips`:** `isActive || isUpcoming`, in quest'ordine:
  1. in corso con ritorno, per ritorno crescente;
  2. in corso senza ritorno, per `createdAt`;
  3. futuri con partenza, per partenza crescente;
  4. senza partenza, per `createdAt`.
- **`pastTrips`:** `isCompleted`, dal più recente (ritorno, poi partenza, poi `createdAt`, decrescente).
- **`savedTrips`:** `isSaved`, per partenza (o `createdAt`) decrescente.
- **`groupByYear`:** anno di partenza (o di `createdAt`); anni decrescenti; l'ordine interno resta quello in ingresso.

- [ ] **Step 1: Scrivi i test che falliscono.** Usa `DateTime` fissi (es. `now = DateTime(2026, 10, 19, 10)`) e `TripModel` costruiti a mano. Un `test` per caso:
  - `buildItinerary` senza tappe: `kinds == [departure, place, ret]`; la riga `place` ha `name == 'Lisbona'`, `from == partenza`, `to == ritorno`.
  - Con tappe `Sintra` (`from` 13, `to` 15) e `Porto` (senza date), meta Lisbona con viaggio 10→15:
    - `kinds == [departure, place, transfer, place, transfer, place, ret]`;
    - la meta va da 10 a 13;
    - il primo `transfer.date` è il 13;
    - l'ultimo luogo è `Porto` con `from == null`.
  - 4 luoghi, `maxPlaces` 3: `kinds == [departure, place, moreStops, transfer, place, ret]` e `hiddenStops == 2`.
  - Viaggio senza date: `departure.date == null`, `ret.date == null`, `nightsBetween(place.from, place.to) == null`.
  - `legPlaceName(TripLeg(id: 'x', locationDisplayName: 'Sintra, Portogallo')) == 'Sintra'`.
  - `tripDestinationName`:
    - con `houseName: 'Baita dei nonni a Courmayeur, Valle d\'Aosta'` restituisce il nome intero;
    - con `destinationLocation` `LocationSuggestionModel(placeId: 'p', displayName: 'Lisbona, Portogallo')` senza `city` restituisce `'Lisbona'`;
    - senza meta restituisce `trip.name`.
  - `nightsBetween(DateTime(2026,10,28,9), DateTime(2026,10,31,8)) == 3`.
  - `stampFor`, una riga per stato:
    - partenza tra 9 giorni → `(daysLeft, 9)`;
    - partenza oggi alle 18 con `now` alle 10 → `today`;
    - viaggio in corso → `traveling`;
    - senza partenza → `noDate`.
  - `ctaFor`: senza oggetti → `prepare`; 2 su 2 spuntati → `ready`; 1 su 2 → `continuePacking`; in corso senza oggetti → `prepare`.
  - `upcomingTrips` sull'insieme [futuro +25, senza date, in corso con ritorno, futuro +10, in corso senza ritorno, passato]: ordine degli id `[inCorsoRitorno, inCorsoSenzaRitorno, futuro10, futuro25, senzaDate]`.
  - `groupByYear` su viaggi del 2026, 2025 e 2026: `[2026, 2025]`; il gruppo 2026 tiene l'ordine in ingresso.
- [ ] **Step 2:** `flutter test test/features/trips/model/trip_postcard_test.dart`. Atteso: FAIL, i simboli non sono definiti.
- [ ] **Step 3:** Implementa il file con le firme qui sopra.
- [ ] **Step 4:** Rilancia gli stessi test. Atteso: PASS.
- [ ] **Step 5:** Commit: `git add lib/features/trips/model/trip_postcard.dart test/features/trips/model/trip_postcard_test.dart && git commit -m "Viaggi: logica della cartolina (itinerario, francobollo, bottone, ordinamenti)"`

### Task 2: "Riusa" nel DAO, nel repository e nel notifier

**Files:**
- Modify: `lib/core/database/daos/trips_dao.dart` (aggiungere accanto a `duplicateTrip`)
- Modify: `lib/features/trips/repositories/trip_repository.dart`, `lib/features/trips/repositories/drift_trip_repository.dart`
- Modify: `lib/features/trips/providers/trip_provider.dart`
- Test: `test/core/database/daos/trips_dao_test.dart`, `test/features/trips/providers/trip_provider_test.dart`

**Interfaces:**
- Produces:
  - `TripsDao.reuseTrip(String originalTripId, String newTripId) → Future<String>`
  - `TripRepository.reuseTrip(String tripId) → Future<String>` (implementato in `DriftTripRepository`)
  - `TripNotifier.reuseTrip(String tripId) → Future<String>`: restituisce l'id del nuovo viaggio; lo usa il Task 7.

Comportamento (spec 5.1):
- `reuseTrip` fa tutto in una transazione e copia come `duplicateTrip`, con queste differenze:
  - `name` = nome originale **senza suffisso**;
  - `departureDateTime` e `returnDateTime` null;
  - `isSaved` false;
  - `legs`: stesso JSON con `from` e `to` a null su ogni tappa (stessi id e nomi);
  - bagagli: una riga `TripLuggageEntries` per ogni riga dell'originale.
- Oggetti: copiati con `isChecked` false, come in `duplicateTrip`.
- Viaggio originale inesistente: stessa eccezione di `duplicateTrip`.
- Repository e notifier rispecchiano `duplicateTrip`: uuid nuovo, gestione errori, `mutate` con `reload` e `rethrowOnly`, e lo stesso evento analytics `trackTripDuplicated()`.

- [ ] **Step 1: Test DAO**, nel gruppo di `duplicateTrip`, con la stessa preparazione dei test esistenti. Un originale con:
  - date;
  - `isSaved: true`;
  - due tappe datate;
  - due oggetti, di cui uno spuntato;
  - un bagaglio collegato.

  Dopo `reuseTrip(orig, 'new-id')` verifica:
  - stesso nome dell'originale;
  - date null, `isSaved` false;
  - tappe con gli stessi nomi e date null;
  - 2 oggetti, tutti non spuntati;
  - 1 riga bagaglio per `'new-id'`;
  - originale invariato.

  Aggiungi un test con id inesistente che si aspetta un'eccezione. Aggiungi anche un test che verifica che `duplicateTrip` **non** copia i bagagli, così il comportamento attuale resta fissato.
- [ ] **Step 2: Test notifier**, con il pattern di `trip_provider_test.dart`. `reuseTrip('t1')` chiama `repo.reuseTrip('t1')`, restituisce l'id del repository e chiama `trackTripDuplicated()`.
- [ ] **Step 3:** Esegui i due file di test. Atteso: FAIL.
- [ ] **Step 4:** Implementa i tre metodi e poi lancia `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 5:** Rilancia i test, più l'intera cartella `test/features/trips/`, perché i mock di `TripRepository` devono compilare ancora. Atteso: PASS.
- [ ] **Step 6:** Commit: `"Viaggi: Riusa copia un viaggio senza date, con tappe e bagagli"`.

### Task 3: La cartolina grande

**Files:**
- Create: `lib/shared/theme/surface_colors.dart`, con export da `lib/shared/theme/theme.dart`.
- Modify: `lib/shared/widgets/ds_settings.dart`, che deve usare il nuovo getter al posto del calcolo inline.
- Create in `lib/features/trips/view/widgets/postcard/`:
  - `postcard_parts.dart`
  - `trip_itinerary_view.dart`
  - `trip_postcard.dart`
- Modify: i due dizionari.
- Test: `test/features/trips/view/widgets/trip_postcard_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `extension SurfaceColors on BuildContext { Color get groupSurface; }`: in chiaro `surfaceContainerLowest`, in scuro `surfaceContainer`; è il calcolo che oggi sta in `DsSettingsGroup`.
  - `PostcardPaper({Key? key, Widget? child, EdgeInsetsGeometry? padding})`:
    - colore `context.groupSurface`;
    - raggio `AppConstants.badgeBorderRadius`;
    - bordo `outlineVariant` con alpha 0.6;
    - ombra `colorScheme.shadow` con alpha 0.12, blur 12, offset (0, 3), come `DsFloatingBar`.
  - `PostageStamp({required Size size, required Widget child})`: rettangolo `surfaceContainerHigh` con bordo a dentini e cornice interna `outlineVariant`.
  - `Postmark({required DateTime date, required double size})`: tondo con bordo `onSurfaceVariant`, ruotato di circa -0,3 rad, con dentro `trips.postcard.postmark_brand`, la data `d MMM` maiuscola e l'anno.
  - `CancelWaves({required Size size})`: quattro onde `onSurfaceVariant`, usate dal Task 5.
  - `TripItineraryView({required List<ItineraryEntry> entries})`.
  - `TripPostcard({Key? key, required TripModel trip, required String destination, required ValueChanged<PostcardCta> onCta})`.

Aspetto: identico a `cartolina-con-itinerario-base.png` e alla spec 4.2 e 4.3.
- **Intestazione:** "Saluti da" in corsivo; meta in `headlineLarge` w800, al massimo 3 righe; nome del viaggio solo se diverso dalla meta (confronto senza maiuscole).
- **Francobollo con timbro:**
  - `daysLeft` → numero + `trips.postcard.days_label.plural(n)`;
  - `today` → `trips.postcard.today`;
  - `traveling` → icona `flight_takeoff` + `trips.postcard.traveling`;
  - `noDate` → icona `event` + `trips.postcard.no_date`, senza `Postmark`.
- **Itinerario:**
  - linea verticale `outline`, dove l'icona o il pallino interrompono la linea;
  - icone: decollo `flight_takeoff`, spostamento `flight`, ritorno `flight_land`;
  - luoghi con pallino pieno `onSurface`; `moreStops` con la stessa grafica di un luogo, testo `trips.itinerary.more_stops.plural(n)`;
  - date `EEE d MMM` in grassetto a destra; periodo dei luoghi `trips.itinerary.nights.plural(n) · d MMM – d MMM`, con le notti omesse se null;
  - data mancante → `trips.postcard.no_date`.
- **Riga valigia:**
  - linea sottile sopra;
  - `CircularProgressIndicator` neutro con la percentuale dentro;
  - `trips.postcard.ready_count` ("4 di 11 pronti") con sotto `trips.postcard.missing.plural(n)`, `trips.postcard.all_packed` o, senza oggetti, `trips.postcard.empty_title` + `trips.postcard.empty_sub`;
  - a destra, solo se ci sono bagagli: icona `luggage_outlined` + nomi uno per riga, `maxLines: 2`, ellissi.
- **Bottone:** `DsButton(expand: true)` con questi testi e icone:
  - `prepare` → `trips.postcard.cta_prepare`, icona `luggage_outlined`;
  - `ready` → `trips.postcard.cta_ready`, icona `check_circle_outline`;
  - `continuePacking` → `trips.postcard.cta_continue`, icona `luggage_outlined`.

Chiavi dei widget per i test: `postcard_stamp`, `postcard_postmark`, `postcard_cta`, `postcard_luggage`, `itinerary_row` (una per riga).

Testi da aggiungere (it / en):

| Chiave | it | en |
|---|---|---|
| `trips.postcard.greetings` | Saluti da | Greetings from |
| `trips.postcard.days_label` | one: giorno, other: giorni | one: day, other: days |
| `trips.postcard.today` | oggi | today |
| `trips.postcard.traveling` | in viaggio | travelling |
| `trips.postcard.no_date` | da decidere | to be decided |
| `trips.postcard.postmark_brand` | PACKLOG | PACKLOG |
| `trips.postcard.ready_count` | {} di {} pronti | {} of {} packed |
| `trips.postcard.missing` | one: manca {}, other: mancano {} | one: {} left, other: {} left |
| `trips.postcard.all_packed` | tutto in valigia | all packed |
| `trips.postcard.empty_title` | Valigia vuota | Empty suitcase |
| `trips.postcard.empty_sub` | nessun oggetto | no items |
| `trips.postcard.cta_prepare` | Prepara la valigia | Pack your suitcase |
| `trips.postcard.cta_ready` | Valigia pronta | Suitcase ready |
| `trips.postcard.cta_continue` | Continua a preparare | Keep packing |
| `trips.itinerary.departure` | Andata | Outbound |
| `trips.itinerary.transfer` | Spostamento | Transfer |
| `trips.itinerary.return` | Ritorno | Return |
| `trips.itinerary.nights` | one: {} notte, other: {} notti | one: {} night, other: {} nights |
| `trips.itinerary.more_stops` | one: +{} tappa, other: +{} tappe | one: +{} stop, other: +{} stops |

- [ ] **Step 1: Test widget.** Usa `MaterialApp` con `AppTheme` e `EasyLocalization` (setup come in `edit_trip_info_screen_legs_test.dart`) dentro un `SizedBox` alto quanto uno schermo (390×640). Casi:
  - Lisbona con una tappa Sintra: 5 `itinerary_row`.
  - Francobollo: per ciascuno dei 4 stati compare il testo atteso dentro `postcard_stamp`. Con `noDate` non c'è `postcard_postmark`.
  - Bagagli: `postcard_luggage` presente con 2 bagagli, assente con 0.
  - Bottone: un tap su `postcard_cta` chiama `onCta` con l'enum giusto per oggetti vuoti, tutti spuntati e parziali.
  - Nomi lunghi: casa "Baita dei nonni a Courmayeur, Valle d'Aosta" + 3 bagagli + 4 luoghi su 390×560 → `tester.takeException()` è null (niente overflow).
- [ ] **Step 2:** Esegui. Atteso: FAIL.
- [ ] **Step 3:** Implementa `surface_colors.dart`, i quattro pezzi, l'itinerario e la cartolina, poi le chiavi nei due dizionari. Aggiorna `DsSettingsGroup` perché usi `context.groupSurface`.
- [ ] **Step 4:** Esegui il test e anche `flutter test test/shared/`. Atteso: PASS.
- [ ] **Step 5:** Commit: `"Viaggi: cartolina con itinerario, francobollo e valigia"`.

### Task 4: La pila di cartoline

**Files:**
- Create: `lib/features/trips/view/widgets/postcard/postcard_pile.dart`
- Modify: i due dizionari.
- Test: `test/features/trips/view/widgets/postcard_pile_test.dart`

**Interfaces:**
- Consumes: `PostcardPaper` (Task 3).
- Produces:
  ```dart
  PostcardPile({Key? key, required int itemCount, required IndexedWidgetBuilder itemBuilder,
                required String Function(int index) semanticLabel})
  ```

Comportamento (spec 4.1):
- Mostra l'elemento corrente dritto. Sotto, fino a due `PostcardPaper()` vuoti, spostati di `context.spacingSm` per livello e ruotati di +0,045 e -0,06 rad.
- **Trascinamento:** sposta la cartolina e la ruota leggermente (proporzionale allo spostamento, massimo circa 0,08 rad).
- **Rilascio:** se lo spostamento supera il 25% della larghezza o la velocità supera 700 px/s:
  - verso sinistra con un elemento successivo → la cartolina esce a sinistra e l'indice avanza;
  - verso destra con un elemento precedente → la precedente rientra da sinistra e l'indice torna indietro;
  - in ogni altro caso torna al centro.
- **Animazioni:** `AnimationController` di 250 ms, `Curves.easeOut`.
- **Indicatore:** sotto la pila, a `context.spacingMd`, con chiave `postcard_pile_dots`. Puntini neutri (attivo `onSurface` largo `spacingMd`, gli altri `outlineVariant` larghi `spacingSm`) + `trips.pile.position` ("2 di 4"). Nascosto con un solo elemento.
- **Semantica:** `Semantics(label: semanticLabel(index))` con `customSemanticsActions` `trips.pile.next` / `trips.pile.previous`, presenti solo quando applicabili.
- **Elenco che cambia:** in `didUpdateWidget`, se `index >= itemCount`, l'indice torna a 0.
- Chiavi: `postcard_pile` per la pila (è l'area del gesto), `postcard_pile_top` per il widget che avvolge la cartolina in cima (quello con il `Transform` di spostamento e rotazione).

Testi: `trips.pile.position` "{} di {}" / "{} of {}"; `trips.pile.next` "Viaggio successivo" / "Next trip"; `trips.pile.previous` "Viaggio precedente" / "Previous trip".

- [ ] **Step 1: Test.** `itemBuilder` restituisce `Text('card $i')`.
  - Con 3 elementi si vede `card 0` e "1 di 3".
  - Dopo `tester.drag(find.byKey(Key('postcard_pile')), Offset(-300, 0))` + `pumpAndSettle` si vede `card 1`.
  - Dopo un `drag(+300)` si torna a `card 0`.
  - Sull'ultimo elemento un `drag(-300)` lascia l'ultimo.
  - Un `drag(-40)` (sotto soglia) non cambia l'elemento.
  - Con 1 elemento non c'è `postcard_pile_dots`.
  - Ricostruendo da indice 2 con `itemCount: 1` si vede `card 0`, senza eccezioni.
  - A riposo il `Transform` della cartolina in cima ha rotazione 0. Verificalo cercando l'`AnimatedBuilder` o il `Transform` della cartolina in cima, con chiave `postcard_pile_top`.
- [ ] **Step 2:** Esegui. Atteso: FAIL.
- [ ] **Step 3:** Implementa.
- [ ] **Step 4:** Esegui. Atteso: PASS.
- [ ] **Step 5:** Commit: `"Viaggi: pila di cartoline da sfogliare"`.

### Task 5: L'album di Passati e Salvati

**Files:**
- Create: `lib/features/trips/view/widgets/postcard/trip_album.dart`
- Modify: i due dizionari.
- Test: `test/features/trips/view/widgets/trip_album_test.dart`

**Interfaces:**
- Consumes: `PostcardPaper`, `PostageStamp`, `CancelWaves` (Task 3); `nightsBetween` (Task 1).
- Produces:
  ```dart
  class TripAlbumGroup { final String label; final List<TripModel> trips; const TripAlbumGroup(this.label, this.trips); }
  TripAlbum({Key? key, required List<TripAlbumGroup> groups, required bool cancelledStamps,
             required String Function(TripModel) destinationOf,
             required ValueChanged<TripModel> onTap, required ValueChanged<TripModel> onLongPress,
             required ValueChanged<TripModel> onReuse, EdgeInsetsGeometry? padding})
  ```

Aspetto: la colonna B di `passati-salvati-A-righe-B-album.png`, spec 5.
- `ListView` (scorrevole, usabile da `RefreshIndicator`).
- Per ogni gruppo: `DsGroupHeader(label:, count:)`, poi una griglia a 2 colonne non scorrevole (`shrinkWrap`), `childAspectRatio` 0,82, spaziature `context.spacingMd`.
- Ogni cartolina piccola ha una rotazione ciclica di [-0,025, 0,02, 0,012, -0,018] rad.
- **Cartolina piccola** (`PostcardPaper`), chiave `album_postcard_<id>`:
  - in alto a destra un `PostageStamp` con il giorno + `MMM yy` in maiuscolo (senza partenza: icona `bookmark_border`);
  - con `cancelledStamps`, le `CancelWaves` sul bordo destro del francobollo, senza coprire il testo;
  - in basso: "Saluti da", la meta (`titleLarge` w800, 2 righe), le notti (omesse se null);
  - `TextButton.icon` neutro (`foregroundColor: onSurface`, icona `replay`), chiave `album_reuse_<id>`, testo `trips.album.reuse`.
- Tap → `onTap`; pressione lunga → `onLongPress`.

Testi: `trips.album.reuse` "Riusa" / "Reuse"; `trips.album.saved_group` "Da riusare" / "To reuse".

- [ ] **Step 1: Test.**
  - Due gruppi ("2026" con 2 viaggi, "2025" con 1): 2 `DsGroupHeader` e 3 `album_postcard_*`.
  - Un tap su `album_reuse_<id>` chiama `onReuse` con quel viaggio; un tap sulla cartolina chiama `onTap`.
  - Con `cancelledStamps: true` c'è un `CancelWaves` per cartolina; con false nessuno.
  - Un viaggio senza date mostra l'icona `bookmark_border`.
  - Nessun overflow con la meta "Baita dei nonni a Courmayeur, Valle d'Aosta" su larghezza 390.
- [ ] **Step 2:** Esegui. Atteso: FAIL.
- [ ] **Step 3:** Implementa.
- [ ] **Step 4:** Esegui. Atteso: PASS.
- [ ] **Step 5:** Commit: `"Viaggi: album di cartoline per passati e salvati"`.

### Task 6: Modifica dopo "Riusa": uscire senza salvare elimina la copia

**Files:**
- Modify: `lib/core/routing/app_router.dart` (rotta `/trips/:id/edit-info`)
- Modify: `lib/features/trips/view/edit_trip_info_screen.dart`
- Test: `test/features/trips/view/edit_trip_info_reuse_test.dart`, con il setup copiato da `edit_trip_info_screen_legs_test.dart`.

**Interfaces:**
- Produces:
  - `EditTripInfoScreen({super.key, required String tripId, bool discardOnExit = false})`;
  - la rotta passa `discardOnExit: state.uri.queryParameters['reuse'] == '1'`. Il Task 7 naviga a `/trips/<id>/edit-info?reuse=1`.

Comportamento:
- Con `discardOnExit`, un `PopScope` registra l'uscita.
- Se lo schermo si chiude **senza** un salvataggio riuscito (Indietro di sistema, freccia dell'AppBar), chiama `ref.read(tripNotifierProvider.notifier).deleteTrip(tripId)`, una volta sola.
- Dopo `_saveChanges` riuscito non elimina niente.
- Senza `discardOnExit` il comportamento è quello di oggi.

- [ ] **Step 1: Test.** Router con `/trips/:id/edit-info`, aperto con `push` da una pagina radice.
  - `?reuse=1` e Indietro (`tester.pageBack()` o pop del navigator) → `tripRepo.deleteTrip('trip-1')` chiamato una volta.
  - `?reuse=1`, salvataggio riuscito (tap su `edit_trip_info_save`) → `deleteTrip` mai chiamato.
  - Senza `reuse` e Indietro → `deleteTrip` mai chiamato.
- [ ] **Step 2:** Esegui. Atteso: FAIL.
- [ ] **Step 3:** Implementa.
- [ ] **Step 4:** Esegui il test e anche `test/features/trips/view/`. Atteso: PASS.
- [ ] **Step 5:** Commit: `"Viaggi: Riusa annullato non lascia copie"`.

### Task 7: La nuova tab Viaggi

**Files:**
- Modify (riscrittura): `lib/features/trips/view/trips_screen.dart`
- Modify: `lib/shared/widgets/skeleton/skeleton_screens.dart` (`SkeletonTripsBody`), `lib/shared/widgets/skeleton/skeleton_tiles.dart`
- Delete: `lib/shared/widgets/trip_cards.dart`; togli l'export da `lib/shared/widgets/widgets.dart` e le voci da `lib/shared/dev/ds_theme_showcase_screen.dart`.
- Modify: i due dizionari, per i testi nuovi e la pulizia.
- Test: `test/features/trips/view/trips_screen_test.dart`, con il setup dei mock come in `edit_trip_info_screen_legs_test.dart`.

**Interfaces:**
- Consumes: tutto quello che producono i Task 1-6. Usa anche `houseNotifierProvider` (nome della casa via `displayName`), `tripNotifierProvider` (`reuseTrip`, `duplicateTrip`, `deleteTrip`, `toggleSaved`) e `showEntityContextMenu` + `EntityActionHandler` (copiare `_handleTripLongPress` di oggi).

Comportamento (spec 3, 4, 5, 6):
- **Struttura:** `ShellTabScaffold` → `TabHeader` → `AppPillTab<TripFilterTab>` con i soli `upcoming`, `past`, `saved` (togli `all` dall'enum di questo file; `trips.filter_all` resta perché lo usa `trip_detail_screen.dart`), con `selectedColor` e `selectedTextColor` = `colorScheme.onSurface`. Sotto, il contenuto.
- **Meta di ogni viaggio:** `tripDestinationName(trip, houseName: <displayName della casa con id destinationHouseId, se esiste>)`.
- **Prossimi:**
  - `PostcardPile` su `upcomingTrips(trips)`;
  - `itemBuilder` → `GestureDetector(onTap: push('/trips/<id>'), onLongPress: menu contestuale, child: TripPostcard(...))`;
  - `onCta`: `prepare` → `push('/trips/<id>/edit-items')`, altrimenti `push('/trips/<id>')`;
  - `semanticLabel` → `trips.pile.semantics` ("Viaggio {} di {}: {}");
  - sotto l'indicatore, spazio `context.navBarReservedHeight + context.spacingLg`.
- **Passati:** `TripAlbum(groups: groupByYear(pastTrips(trips)).map((e) => TripAlbumGroup('${e.key}', e.value)), cancelledStamps: true, …)`.
- **Salvati:** `TripAlbum(groups: [TripAlbumGroup('trips.album.saved_group'.tr(), savedTrips(trips))], cancelledStamps: false, …)`. Padding in fondo `context.navBarReservedHeight`, dentro un `RefreshIndicator` come oggi.
- **Riusa:** `final id = await notifier.reuseTrip(trip.id)`, poi `push('/trips/$id/edit-info?reuse=1')`. In caso di errore, lo snackbar di errore esistente con `errors.duplicate_trip_failed`.
- **Stati vuoti:** tutti con `DsEmptyState`, filtri sempre visibili.
  - Nessun viaggio: quello attuale.
  - Prossimi vuoto: icona `calendar_today_outlined`, titolo `trips.no_upcoming`, CTA `create_sheet.new_trip` con icona `add` → `push('/new-trip')`.
  - Passati vuoto: icona `history_outlined`, titolo `trips.no_past`, con il valore aggiornato a "Qui troverai i viaggi fatti" / "Your past trips will show up here".
  - Salvati vuoto: icona `bookmark_border_outlined`, titolo `trips.no_saved`, sottotitolo nuovo `trips.no_saved_hint` "Tieni premuto un viaggio e scegli Salva per riusarlo" / "Long-press a trip and choose Save to reuse it".
- **Caricamento:** `SkeletonTripsBody` = pillole + una sagoma di cartolina grande che riempie l'altezza (`SkeletonBox` con raggio `AppConstants.badgeBorderRadius`). `SkeletonTripCard` va rimosso se non lo usa più nessuno.
- **Pulizia:**
  - elimina `trip_cards.dart` e la griglia;
  - con `git grep` togli dai due dizionari le chiavi che nessuno usa più (controlla almeno `trips.next_trip` e `trips.progress`);
  - controlla che `trip_summary_card.dart` e `trip_info_badges.dart` siano ancora usati: se non lo sono più, eliminali.

Testi: `trips.pile.semantics` "Viaggio {} di {}: {}" / "Trip {} of {}: {}"; `trips.no_saved_hint`; nuovo valore di `trips.no_past`.

- [ ] **Step 1: Test schermo**, con mock repository che restituiscono viaggi di prova: uno in corso, due futuri, uno passato salvato, uno passato.
  - Ci sono 3 pillole e nessun testo `trips.filter_all`.
  - Su Prossimi c'è `postcard_pile` con la prima cartolina = il viaggio in corso.
  - Un tap su "Passati" mostra 2 `album_postcard_*` e 1 `DsGroupHeader`.
  - Un tap su "Salvati" mostra 1 `album_postcard_*`.
  - Un tap su `album_reuse_<id>` chiama `tripRepo.reuseTrip(id)` e porta alla rotta `/trips/<nuovo>/edit-info?reuse=1` (router di test con una rotta finta che mostra `Text('edit-info')`).
  - Con 0 prossimi ma un passato, su Prossimi c'è `DsEmptyState` con la CTA.
- [ ] **Step 2:** Esegui. Atteso: FAIL.
- [ ] **Step 3:** Implementa, poi lancia `dart run build_runner build --delete-conflicting-outputs` se serve.
- [ ] **Step 4:** Esegui `flutter test` (tutta la suite) e `dart analyze`. Atteso: tutto verde e nessun nuovo problema.
- [ ] **Step 5:** Commit: `"Viaggi: tab a cartoline (pila, album, filtri neutri)"`.

### Task 8: Screenshot e documentazione dei flussi

**Files:**
- Modify: `test/screenshots/support/seed.dart`. Nel viaggio Lisbona togli la tappa `leg-lisbona`, perché le tappe sono "altre tappe". Resta `leg-sintra` (dal giorno 13 al 15).
- Modify: `test/screenshots/ui_screenshots_test.dart` (flow `07-viaggi`)
- Modify: `docs/ui-flows.md` (tracciato con `git add -f`)

Scenari del flow `07-viaggi`, in chiaro e in scuro, rinumerati in sequenza:
1. vuoto;
2. Prossimi (viaggio in corso);
3. Prossimi dopo uno scorrimento (Lisbona: tappa Sintra, 2 bagagli);
4. Prossimi con la valigia vuota (Torino, secondo scorrimento);
5. Passati;
6. Salvati;
7. menu contestuale sulla cartolina (pressione lunga sulla cartolina in cima, trovata con `find.byKey(const Key('postcard_pile_top'))`);
8. Prossimi vuoto (seed con solo viaggi passati, oppure un `AppSetup` equivalente già esistente);
9. il foglio Crea, come oggi.

Lo scorrimento si fa con `tester.drag(find.byKey(const Key('postcard_pile')), const Offset(-330, 0))` + `settle`.

- [ ] **Step 1:** Aggiorna seed e scenari.
- [ ] **Step 2:** `flutter test test/screenshots/ui_screenshots_test.dart --dart-define=UI_SCREENSHOTS=true --plain-name "07-viaggi"`. Atteso: PASS, con le immagini in `build/ui-screenshots/07-viaggi/`. Guarda le immagini e confrontale con `cartolina-con-itinerario-base.png` e con l'album B: niente overflow, cartolina dritta, arancio solo sul bottone.
- [ ] **Step 3:** Esegui gli altri flow che usano il seed dei viaggi (`--plain-name "08"` e tutti quelli con `/trips`) per controllare che il cambio della tappa non rompa nulla.
- [ ] **Step 4:** Aggiorna la sezione "07 · Tab Viaggi" di `docs/ui-flows.md`: componenti nuovi, stati catturati, "Tutto" rimosso.
- [ ] **Step 5:** Commit: `git add -f docs/ui-flows.md` più seed e test, messaggio `"Screenshot: tab Viaggi a cartoline"`.

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

## Dati di esempio

Utente "Davide Rossi". Case: *Casa Milano* (principale, 18 oggetti in 3 spazi,
3 bagagli), *Casa al mare*, *Baita dei nonni a Courmayeur, Valle d'Aosta* (nome
lungo), *Monolocale Torino* (vuota). Viaggi: *Weekend al mare* (in corso, verso
Casa al mare), *Lisbona* (fra 10 giorni, 2 tappe, 11 oggetti di cui 4 spuntati),
*Matrimonio Giulia* (salvato), *Weekend a Torino* (senza oggetti), due viaggi
passati. Un oggetto ha un nome volutamente lungo.

## Navigazione

Shell con barra flottante (`lib/shared/widgets/main_shell.dart`): **Case**
(`/`, home) e **Viaggi** (`/trips`), più un bottone d'azione staccato che fa
l'azione della tab corrente (Case → foglio "Aggiungi oggetti", Viaggi → nuovo
viaggio). Il **Profilo** (`/profile`) si apre dall'avatar in alto a destra.
Profilo e schermate di dettaglio stanno sul navigator radice, sopra la shell. Redirect in `lib/core/routing/app_router.dart`:
onboarding non completato → `/onboarding`; non autenticato → `/login`; tour
post-login allo step `aiIntro` → `/onboarding-ai-intro`.

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
| 5 | Aggiungi oggetti (sheet) | `features/items/view/add_items_sheet.dart` | bottone d'azione in Case | ✓ |
| 6 | Nuova casa (sheet) | `features/houses/view/add_edit_house_screen.dart` | riga "Nuova casa" in fondo alla lista | ✓ |

### 04 · Dettaglio casa

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1-5 | Dettaglio casa | `features/houses/view/house_detail_screen.dart` | tap su una casa | ✓ pieno, ✓ filtro spazio, ✓ casa vuota, ✓ input rapido espanso, ✓ selezione multipla |
| 6 | Sposta in… | `features/items/view/bulk_move_sheet.dart` | selezione → Sposta | ✓ |
| 7 | Aggiungi a viaggio | `features/trips/view/trip_picker_sheet.dart` | selezione → icona valigia | ✓ |
| 8 | Gestisci casa | `features/houses/view/house_manage_sheet.dart` | matita in basso a sinistra | ✓ |
| 9 | Modifica casa | `features/houses/view/add_edit_house_screen.dart` | Gestisci → Modifica info | ✓ |
| 10 | Spazi | `features/spaces/view/spaces_management_screen.dart` | Gestisci → Modifica spazi | ✓. Non catturato: sheet nuovo/modifica spazio |
| 11 | Bagagli | `features/luggages/view/luggages_management_screen.dart` | Gestisci → Modifica bagagli | ✓. Non catturato: sheet nuovo/modifica bagaglio |
| 12 | Conferma eliminazione | `house_detail_screen.dart` | Gestisci → Elimina | ✓ |
| 13 | Casa non trovata | `house_detail_screen.dart` | link a casa eliminata | ✓ |

### 05 · Oggetti

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1 | Nuovo oggetto (sheet) | `features/items/view/add_edit_item_screen.dart` | Aggiungi oggetti → Scrivi a mano | ✓ |
| 2 | Modifica oggetto | `features/items/view/item_form_content.dart` | tap su un oggetto | ✓. Non catturati: picker quantità, casa, spazio (sheet) |

### 06 · Import AI da dettaglio casa

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1-2 | Import AI | `features/ai_input/view/ai_clothing_sandbox_screen.dart` | dettaglio casa → ✨ | ✓ vuoto, ✓ sheet fotocamera/galleria |
| 3-8 | Risultati AI | `features/ai_input/view/ai_results_screen.dart` | dopo la scelta delle foto | ✓ analisi in corso, ✓ capi riconosciuti, ✓ scelta casa, ✓ errore parziale con retry, ✓ errore di rete, ✓ quota esaurita |

### 07 · Tab Viaggi

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1-5 | Elenco viaggi | `features/trips/view/trips_screen.dart` | tab Viaggi | ✓ vuoto, ✓ Prossimi (hero del viaggio in corso + griglia), ✓ Passati, ✓ Salvati, ✓ menu contestuale. Non catturati: tab "Tutto", errore |

### 08 · Creazione viaggio (wizard 2 passi)

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1-4 | Nuovo viaggio, passo 1 | `features/trips/view/add_trip_screen.dart`, `trip_info_form.dart` | bottone d'azione in Viaggi, o CTA nei Viaggi | ✓ vuoto, ✓ errore di validazione, ✓ destinazione "Casa", ✓ picker casa |
| 5 | Selezione date | `features/trips/view/trip_date_range_screen.dart` | tap sulle date | ✓ |
| 6 | Nuova tappa (sheet) | `features/trips/view/widgets/trip_leg_sheet.dart` | Aggiungi tappa | ✓ |
| — | Passo 2: oggetti e bagagli | `add_trip_screen.dart` (`_buildItemsStep`), `trip_items_selector.dart` | Avanti con passo 1 valido | **non catturato**: serve compilare date e destinazione via UI |
| — | Suggerimenti località | `shared/widgets/location_autocomplete_field.dart` | digitando la destinazione | **non catturato**: chiama Geoapify |

### 09 · Dettaglio viaggio

| # | Schermata | Sorgente | Come ci si arriva | Stati |
|---|---|---|---|---|
| 1-3 | Dettaglio viaggio | `features/trips/view/trip_detail_screen.dart` | tap su un viaggio | ✓ checklist, ✓ in corso, ✓ senza oggetti |
| 4 | Conferma eliminazione | `trip_detail_screen.dart` | cestino | ✓ |
| 5 | Modifica info | `features/trips/view/edit_trip_info_screen.dart` | matita | ✓ |
| 6 | Modifica oggetti | `features/trips/view/edit_trip_items_screen.dart` | "Modifica oggetti" | ✓ |
| 7 | Viaggio non trovato | `trip_detail_screen.dart` | link a viaggio eliminato | ✓ |

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
8. **Selettore bagagli con `FilterChip`** (`trips/view/add_trip_screen.dart:482`)
   mentre il resto dell'app usa `AppPillTab` per scelte a pillola.
   **Risolto** nella PR #20.
9. **Altezze delle pill tab diverse fra schermate.** `height: 40` fisso nel
   dettaglio casa (`house_detail_screen.dart:738`), nel dettaglio viaggio
   (`trips/view/trip_detail_screen.dart:113`) e nel selettore oggetti
   (`trips/view/trip_items_selector.dart:162`, `:203`); default altrove (tab
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

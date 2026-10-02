# Onboarding Redesign — Design Spec

**Data:** 2026-06-06  
**Status:** Approvato  
**App:** Pack Log (Stuff Tracker 2)

---

## Contesto

L'onboarding attuale presenta due problemi:
1. La prima slide di selezione lingua è ridondante: il device locale può essere rilevato automaticamente.
2. Il guided tour post-login (6 spotlight sequenziali via `tutorial_coach_mark`) non accompagna l'utente verso un'azione concreta. Il nuovo flusso sostituisce i tooltip con un'esperienza attiva centrata sull'AI import, seguita da una catena di tooltip contestuali.

---

## Architettura — approccio scelto

**Milestone enum + avanzamento esplicito nel layer UI.**

Un `PostLoginOnboardingProvider` tiene traccia di un enum con 7 step. Il layer UI chiama `advance()` dopo ogni azione rilevante. Il `TourListener` (già esistente, wrappa `MainShell`) guarda il provider e mostra il tooltip giusto tramite `TutorialCoachMark` a singolo target. La navigazione verso la pagina AI intro è gestita dal redirect GoRouter, mai da `context.push` dentro un listener.

---

## Sezione 1 — Pre-login onboarding

### Cosa cambia in `OnboardingScreen`

- La slide 0 (`LanguageSlide`) viene rimossa completamente
- Le 3 slide video rimangono: `houses`, `items`, `trips`
- Il dots indicator passa da 4 a 3 punti
- Eliminata tutta la logica di selezione locale: `_initDefaultLocale`, `_ensureLocaleApplied`, `_onLocaleTapped`
- Rimosso il guard `_isNextEnabled` (era legato alla selezione della locale)
- Il file `lib/features/onboarding/view/widgets/language_slide.dart` va eliminato
- `_pageNames` diventa `['houses', 'items', 'trips']`

### Lingua auto-detect — approccio reattivo

La logica di fallback vive nel build() di languageLocaleProvider. Per mantenere il provider testabile (Clean Code), non invocare direttamente WidgetsBinding.instance. Crea un provider sincrono di base (es. deviceLocaleProvider) che restituisce il locale della piattaforma e sovrascrivilo nel ProviderScope se necessario nei test. Il languageLocaleProvider farà un semplice ref.watch(deviceLocaleProvider).

`MaterialApp.router` consuma questo provider in modo reattivo — nessuna chiamata imperativa a `context.setLocale()` in startup, nessun widget inizializzatore custom, nessuna race condition con il ciclo di vita dell'app.

---

## Sezione 2 — Architettura post-login

### Provider e stato

`tour_status_provider.dart` viene sostituito da `post_login_onboarding_provider.dart`.

```dart
enum OnboardingStep {
  aiIntro,               // Mostra la pagina AI intro
  houseTooltip,          // Spotlight sul FAB "crea casa"
  defaultHouseTooltip,   // Card centrata "apri la Casa di prova"
  moveItemsTooltip,      // Card centrata "seleziona e sposta item"
  createTripTooltip,     // Spotlight sul tab Viaggi
  tripCreationTooltip,   // Card centrata dentro AddTripScreen
  done,
}

class OnboardingState {
  final OnboardingStep step;
  final bool skippedAi;          // true solo se l'utente ha tappato "Salta" sull'AI intro
  final bool hasExistingHouses;  // true se l'utente aveva già ≥1 casa al momento del reset
  final String? defaultHouseId;  // ID della "Casa di prova", noto dopo il save AI
}
```

### Persistenza — pattern repository

Viene definita un'interfaccia `IOnboardingRepository` con metodi:
`saveStep`, `loadStep`, `saveSkippedAi`, `loadSkippedAi`, `saveHasExistingHouses`, `loadHasExistingHouses`, `saveDefaultHouseId`, `loadDefaultHouseId`.

L'implementazione concreta `SharedPrefsOnboardingRepository` usa `SharedPreferences`. Il notifier riceve `IOnboardingRepository` tramite dependency injection nel costruttore — mockabile nei test senza toccare il filesystem. Questo è coerente con il pattern repository già usato nel resto del codebase.

### Metodi del notifier

| Metodo | Quando viene chiamato | Effetto |
|--------|----------------------|---------|
| `completeAi(String defaultHouseId)` | Dopo il save in `AiClothingSandboxScreen` | Se `state.hasExistingHouses == true`: `step = done`. Altrimenti: `step = houseTooltip`, salva `defaultHouseId` |
| `skipAi()` | Tap "Salta" su `AiOnboardingIntroScreen` | `step = houseTooltip`, `skippedAi = true` |
| `advance()` | Layer UI dopo ogni azione rilevante o tap "Avanti" su tooltip | Avanza al prossimo step secondo la logica branch |
| `markDone()` | Tap "Salta" su qualsiasi tooltip | `step = done` direttamente |
| `reset({required bool hasExistingHouses})` | Tap "Ripeti il tour" nel profilo | Vedi sezione Relaunch |

### Logica branch di `advance()`

```
skippedAi == false:
  houseTooltip → defaultHouseTooltip → moveItemsTooltip → createTripTooltip → tripCreationTooltip → done

skippedAi == true:
  houseTooltip → createTripTooltip → tripCreationTooltip → done
```

Il flag `hasExistingHouses` viene impostato da `reset()` e letto da `completeAi()`. Non viene mai modificato da `skipAi()` né da `advance()`.

### Navigazione — router redirect

La pagina AI intro non viene mai pushata imperativamante da `TourListener`. Il redirect di GoRouter controlla: se l'utente è autenticato e `step == aiIntro`, devia su `/onboarding-ai-intro`. Quando `step` avanza oltre `aiIntro`, il redirect cessa e il router porta l'utente sulla home normalmente.

Il `TourListener` gestisce **solo gli overlay** (`TutorialCoachMark`). Ogni esecuzione è avvolta in `WidgetsBinding.instance.addPostFrameCallback` per garantire che il widget target sia già stato renderizzato prima di mostrare la spotlight.

---

## Sezione 3 — Pagina AI intro + casa di default

### Nuova schermata: `AiOnboardingIntroScreen`

**File:** `lib/features/tour/view/ai_onboarding_intro_screen.dart`  
**Route:** `/onboarding-ai-intro` (matched dal redirect GoRouter quando `step == aiIntro`)

Layout full-screen senza AppBar:
- `Icons.auto_awesome` grande in `colorScheme.primary`
- Titolo `textTheme.headlineSmall`: chiave i18n `onboarding_tour.ai_intro.title`
- Corpo `textTheme.bodyMedium` in `colorScheme.onSurfaceVariant`: chiave i18n `onboarding_tour.ai_intro.body`
- Footer con `UniversalActionBar` (componente già esistente): `FilledButton` "Scatta o carica una foto" + `TextButton` "Salta"
- Spaziatura via `context.spacingMd/Lg/Xl`

**Tasto "Scatta o carica una foto":** esegue esclusivamente `context.push('/onboarding-ai-intro/sandbox')` verso `AiClothingSandboxScreen` con `isFirstTimeOnboarding: true`. Nessuna creazione anticipata nel database.

**Tasto "Salta":** chiama `ref.read(postLoginOnboardingProvider.notifier).skipAi()` poi `context.go('/')`.

---

### `AiClothingSandboxScreen` in modalità onboarding

Nuovo parametro opzionale: `bool isFirstTimeOnboarding = false`.

**Quando `isFirstTimeOnboarding == true`:**
- Il parametro `houseId` diventa nullable (non richiesto)
- Il selettore casa nel bottom bar è nascosto (non serve: la casa viene creata al momento del save)
- Quando appaiono i **primi risultati AI**: mostra un singolo `TutorialCoachMark` come card centrata (senza spotlight, usando `tourKeys.infoCardTarget`) con testo `'onboarding_tour.ai_save_tooltip'` — "Abbiamo creato una casa **'Casa di prova'** dove salveremo questi oggetti. Potrai spostarli quando vuoi." Solo tasto "Ok", nessun "Salta".

**In `_saveItems()` quando `isFirstTimeOnboarding == true`:**

Esegue una singola transazione Drift che:
1. Crea la casa di default con nome `'onboarding.default_house_name'.tr()` (IT: `"Casa di prova"`, EN: `"Demo House"`)
2. Salva contemporaneamente tutti gli item riconosciuti dall'AI al suo interno

Dopo il save:
1. Chiama `ref.read(postLoginOnboardingProvider.notifier).completeAi(defaultHouseId: newHouseId)`
2. Nota architetturale: Nessuna chiamata esplicita a context.go('/') è necessaria. Poiché il router di livello superiore ascolta il provider, l'aggiornamento dello stato (che rimuove la condizione di redirect per aiIntro) triggererà automaticamente un refresh del router che ci trasporterà in Home in modo pulito.

---

## Sezione 4 — Catena tooltip

### Responsabilità di visualizzazione

I tooltip i cui target sono elementi della `MainShell` (tab bar, FAB) sono gestiti dal `TourListener`. I tooltip i cui target sono dentro schermate pushate sono gestiti dalle schermate stesse. Tutti usano `TutorialCoachMark` a singolo target e `addPostFrameCallback`.

Il widget `TourStepContent` (già esistente) viene riusato per il contenuto di ogni card.

### GlobalKey aggiuntiva in `tourKeys`

```dart
final houseFab = GlobalKey();  // assegnata al FAB della schermata houses
```

Le chiavi `infoCardTarget` e `tripsTab` già esistono e vengono riusate.

### Sequenza completa

| Step | Gestito da | Target | Tipo | Avanzamento |
|------|-----------|--------|------|-------------|
| `houseTooltip` | `TourListener` | `tourKeys.houseFab` | Spotlight | Layer UI: dopo `await addHouse(...)` con successo → `ref.read(provider.notifier).advance()` |
| `defaultHouseTooltip` *(solo se `!skippedAi`)* | `TourListener` | `tourKeys.infoCardTarget` | Card centrata | Tap "Avanti" sulla card |
| `moveItemsTooltip` *(solo se `!skippedAi`)* | `TourTriggerWrapper` (via Router) | `tourKeys.infoCardTarget` | Card centrata | **Gestito dal Router:** Non inquinare la vista originale. Il Router wrappa `HouseDetailScreen` in un `TourTriggerWrapper` che lancia `addPostFrameCallback`. L'avanzamento avviene chiamando il provider dopo la mutazione `bulkMove`. |
| `createTripTooltip` | `TourListener` | `tourKeys.tripsTab` | Spotlight | Tap "Avanti" sulla card |
| `tripCreationTooltip` | `TourTriggerWrapper` (via Router) | `tourKeys.infoCardTarget` | Card centrata | **Gestito dal Router:** Il Router wrappa `AddTripScreen` nel `TourTriggerWrapper`. Tap "Ok" sulla card per avanzare. |

**"Salta" su ogni tooltip:** chiama `notifier.markDone()` → `step = done` immediato.

### Testi i18n per i tooltip

| Step | Chiave titolo | Chiave corpo |
|------|--------------|-------------|
| `houseTooltip` | `tour.house_tooltip.title` | `tour.house_tooltip.body` |
| `defaultHouseTooltip` | `tour.default_house_tooltip.title` | `tour.default_house_tooltip.body` |
| `moveItemsTooltip` | `tour.move_items_tooltip.title` | `tour.move_items_tooltip.body` |
| `createTripTooltip` | `tour.create_trip_tooltip.title` | `tour.create_trip_tooltip.body` |
| `tripCreationTooltip` | `tour.trip_creation_tooltip.title` | `tour.trip_creation_tooltip.body` |

---

## Relaunch dal profilo

Il bottone "Ripeti il tour" in `ProfileScreen` chiama `reset(hasExistingHouses: houses.isNotEmpty)`:

- **0 case** → `step = aiIntro, skippedAi = false, defaultHouseId = null` — stesso flusso del primo login
- **1+ case** → `step = aiIntro, skippedAi = false, hasExistingHouses = true, defaultHouseId = null` — `AiOnboardingIntroScreen` è mostrata, ma dopo il save AI (che usa il selettore case normale, visibile) `completeAi()` legge `hasExistingHouses == true` e imposta `step = done` direttamente senza catena tooltip

---

## Analytics

| Evento | Proprietà | Quando |
|--------|-----------|--------|
| `onboarding_started` | — | Primo slide video visualizzato |
| `onboarding_page_viewed` | `page_index`, `page_name` | Cambio slide (houses/items/trips) |
| `onboarding_completed` | — | Tap "Avanti" sull'ultima slide → login |
| `ai_onboarding_started` | — | `AiOnboardingIntroScreen` visualizzata |
| `ai_onboarding_skipped` | — | Tap "Salta" |
| `onboarding_step_viewed` | `step_name` | Ogni tooltip visualizzato |
| `onboarding_step_skipped` | `step_name` | Tap "Salta" su un tooltip |
| `onboarding_completed_full` | — | `step = done` raggiunto |

---

## Localizzazione — nuove chiavi i18n

```
onboarding.default_house_name         # "Casa di prova" / "Demo House"

onboarding_tour.ai_intro.title        # "Facciamo una prova"
onboarding_tour.ai_intro.body         # "Carica una foto del tuo outfit o scattane una. L'AI riconosce i capi e li salva per te."
onboarding_tour.ai_save_tooltip       # "Abbiamo creato una casa 'Casa di prova' dove salveremo questi oggetti. Potrai spostarli quando vuoi."

tour.house_tooltip.title
tour.house_tooltip.body
tour.default_house_tooltip.title
tour.default_house_tooltip.body
tour.move_items_tooltip.title
tour.move_items_tooltip.body
tour.create_trip_tooltip.title
tour.create_trip_tooltip.body
tour.trip_creation_tooltip.title
tour.trip_creation_tooltip.body
```

---

## File da creare / modificare

| Azione | File |
|--------|------|
| Crea | `lib/features/tour/view/ai_onboarding_intro_screen.dart` |
| Crea | `lib/features/tour/providers/post_login_onboarding_provider.dart` |
| Crea | `lib/features/tour/repositories/i_onboarding_repository.dart` |
| Crea | `lib/features/tour/repositories/shared_prefs_onboarding_repository.dart` |
| Modifica | `lib/features/tour/controllers/tour_orchestrator.dart` — evolve in `PostLoginOnboardingListener`, rimuove riferimenti a `tourStatusProvider` |
| Modifica | `lib/features/tour/tour_keys.dart` — aggiunge `houseFab` |
| Modifica | `lib/features/ai_input/view/ai_clothing_sandbox_screen.dart` — aggiunge `isFirstTimeOnboarding`, transazione atomica in `_saveItems`, tooltip su risultati |
| Crea | `lib/features/tour/widgets/tour_trigger_wrapper.dart` — ConsumerWidget generico usato nel router per avvolgere le screen target e sparare i tooltip isolando la logica di business. |
| Modifica | `lib/features/onboarding/view/onboarding_screen.dart` — rimuove slide lingua e logica locale |
| Modifica | `lib/core/routing/app_router.dart` — aggiunge route `/onboarding-ai-intro`, redirect per `step == aiIntro`, rimuove redirect per `tour_status` |
| Modifica | `lib/features/profile/view/profile_screen.dart` — `reset()` con conteggio case |
| Modifica | `lib/shared/providers/language_locale.dart` — auto-detect device locale nel `build()` |
| Elimina | `lib/features/onboarding/view/widgets/language_slide.dart` |
| Elimina | `lib/features/tour/providers/tour_status_provider.dart` |
| Modifica | `assets/translations/it-IT.json` + `en-US.json` — nuove chiavi |

---

## Vincoli e decisioni

- **Nessuna chiamata imperativa a `context.setLocale()` in startup** — la lingua è gestita reattivamente dal provider
- **Nessun `context.push` da listener o `initState` non protetto** — tutto passa da redirect GoRouter o `addPostFrameCallback`
- **La "Casa di prova" viene creata solo al save** — nessuna casa orfana se l'utente non completa il flusso
- **Domain notifier (`HouseNotifier`, `ItemNotifier`) non importano il provider di onboarding** — l'accoppiamento è solo nel layer UI
- **`TourStepContent`, `tourKeys`, `TutorialCoachMark`** — riusati senza modifiche strutturali
- **`IOnboardingRepository`** — mockabile nei test; coerente con il pattern repository del resto del codebase


800 991 815
04221744299

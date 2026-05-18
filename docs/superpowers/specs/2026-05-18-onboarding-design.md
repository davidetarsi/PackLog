# Onboarding Flow — Design Spec

## Obiettivo

Mostrare un flusso di onboarding al primo avvio dell'app, prima della schermata di login. Il flusso include la selezione della lingua e 3 slide di presentazione delle feature principali. Ogni schermata traccia eventi Amplitude per monitorare il funnel acquisizione.

## Flusso completo

```
Prima installazione:
  /onboarding → /login → /

Installazioni successive (onboarding già completato):
  /login → /   oppure   / (se già autenticato)
```

## Stack tecnico coinvolto

- GoRouter 14 (routing + redirect guard)
- Riverpod 2.5 (`onboardingStatusProvider`, `analyticsServiceProvider`)
- SharedPreferences (`onboarding_completed` key)
- easy_localization (`context.setLocale()`, `LanguageTile` esistente)
- Amplitude (`analyticsServiceProvider.logEvent()`)

---

## Architettura

### 1. Provider: onboardingStatusProvider

Segue il pattern di `ThemeModeNotifier` (SharedPreferences + AsyncNotifier).

```dart
// file: lib/features/onboarding/providers/onboarding_status_provider.dart
const String _onboardingCompletedKey = 'onboarding_completed';

@Riverpod(keepAlive: true)
class OnboardingStatus extends _$OnboardingStatus {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
    state = const AsyncData(true);
  }
}
```

### 2. Routing — redirect guard esteso

Il guard in `app_router.dart` viene esteso con il controllo onboarding come primo check:

```dart
redirect: (context, state) {
  // 1. Bootstrap completato?
  final bootstrapState = ref.read(appBootstrapProvider);
  if (bootstrapState is! AsyncData) return null;

  // 2. Onboarding completato?
  final onboardingState = ref.read(onboardingStatusProvider);
  final onboardingCompleted = onboardingState.valueOrNull ?? false;
  final isOnOnboarding = state.matchedLocation == '/onboarding';

  if (!onboardingCompleted && !isOnOnboarding) return '/onboarding';
  if (onboardingCompleted && isOnOnboarding) return '/login';

  // 3. Auth check (logica esistente invariata)
  final authState = ref.read(authNotifierProvider);
  final isAuthenticated = authState is Authenticated;
  final isOnLogin = state.matchedLocation == '/login';

  if (!isAuthenticated && !isOnLogin) return '/login';
  if (isAuthenticated && isOnLogin) return '/';
  return null;
},
```

Nuova route da aggiungere prima delle tab routes:
```dart
GoRoute(
  path: '/onboarding',
  builder: (context, state) => const OnboardingScreen(),
),
```

`_AuthChangeNotifier` deve ascoltare anche `onboardingStatusProvider` per triggerare il refresh del router quando il flag viene scritto.

---

## OnboardingScreen

### Struttura

```dart
// file: lib/features/onboarding/view/onboarding_screen.dart
class OnboardingScreen extends ConsumerStatefulWidget { ... }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Locale? _selectedLocale; // null finché l'utente non sceglie (slide 0)

  // Pages: [LanguageSlide, HousesSlide, ItemsSlide, TripsSlide]
}
```

**Layout**:
```
SafeArea
  ├─ Spacer (flessibile, occupa spazio in alto)
  ├─ PageView (physics: NeverScrollableScrollPhysics)
  │     ├─ Slide 0: LanguageSlide
  │     ├─ Slide 1: ContentSlide (houses)
  │     ├─ Slide 2: ContentSlide (items)
  │     └─ Slide 3: ContentSlide (trips)
  ├─ DotsIndicator (4 dots, colorScheme.primary per attivo)
  ├─ SizedBox(height: spacingMd)
  └─ UniversalActionBar
        primaryLabel: _currentPage < 3 ? 'onboarding.next'.tr() : 'onboarding.start'.tr()
        onPrimaryPressed: _isNextEnabled ? _handleNext : null
```

**Comportamento bottone**:
- Slide 0 (lingua): disabilitato finché `_selectedLocale == null`
- Slide 1–2: sempre abilitato, avanza alla slide successiva
- Slide 3 (ultima): `_handleComplete()` — scrive flag + naviga a `/login`

**Swipe disabilitato** (`NeverScrollableScrollPhysics`) per evitare che l'utente salti la slide lingua senza aver fatto una scelta.

---

## Slide 0 — Selezione Lingua

```dart
// file: lib/features/onboarding/view/widgets/language_slide.dart
```

**UI**:
```
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Icon(Icons.language, size: 80, color: colorScheme.primary),
    SizedBox(height: context.spacingLg),
    Text(
      'Scegli la tua lingua\nChoose your language',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: context.fontSizeLg, fontWeight: FontWeight.bold),
    ),
    SizedBox(height: context.spacingLg),
    LanguageTile(
      locale: const Locale('it', 'IT'),
      title: 'Italiano',
      flag: '🇮🇹',
      isSelected: _selectedLocale?.languageCode == 'it',
      onTap: () => _selectLocale(const Locale('it', 'IT')),
    ),
    SizedBox(height: context.spacingSm),
    LanguageTile(
      locale: const Locale('en', 'US'),
      title: 'English',
      flag: '🇬🇧',
      isSelected: _selectedLocale?.languageCode == 'en',
      onTap: () => _selectLocale(const Locale('en', 'US')),
    ),
  ],
)
```

**Selezione lingua**:
```dart
Future<void> _selectLocale(Locale locale) async {
  await context.setLocale(locale);
  ref.read(languageLocaleProvider.notifier).updateLocale(locale.languageCode);
  setState(() => _selectedLocale = locale);

  // Analytics
  ref.read(analyticsServiceProvider).logEvent(
    'onboarding_language_selected',
    properties: {'language': locale.languageCode},
  );
}
```

**Pre-selezione**: Al mount della slide, se il device locale è supportato (it o en), lo pre-seleziona visivamente ma NON chiama `context.setLocale()` — l'utente deve confermare esplicitamente tappando. In questo modo il bottone resta disabilitato finché non avviene un tap.

---

## Slide 1-3 — ContentSlide (widget riusabile)

```dart
// file: lib/features/onboarding/view/widgets/content_slide.dart
class ContentSlide extends StatelessWidget {
  final IconData icon;
  final String titleKey;      // chiave i18n
  final String descriptionKey; // chiave i18n

  const ContentSlide({
    super.key,
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Theme.of(context).colorScheme.primary),
          SizedBox(height: context.spacingLg),
          Text(
            titleKey.tr(),
            style: TextStyle(
              fontSize: context.fontSizeLg,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.spacingMd),
          Text(
            descriptionKey.tr(),
            style: TextStyle(
              fontSize: context.fontSizeSm,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
```

**Le 3 slide di contenuto**:

| Slide | Icon | titleKey | descriptionKey |
|---|---|---|---|
| 1 | `Icons.home_outlined` | `onboarding.houses.title` | `onboarding.houses.description` |
| 2 | `Icons.inventory_2_outlined` | `onboarding.items.title` | `onboarding.items.description` |
| 3 | `Icons.luggage_outlined` | `onboarding.trips.title` | `onboarding.trips.description` |

---

## Chiavi di traduzione

Da aggiungere a `assets/translations/it-IT.json` e `assets/translations/en-US.json`.

**it-IT.json**:
```json
"onboarding": {
  "next": "Avanti",
  "start": "Inizia",
  "houses": {
    "title": "Le tue case",
    "description": "Organizza i tuoi oggetti in più abitazioni. Crea spazi all'interno di ogni casa per trovare tutto al volo."
  },
  "items": {
    "title": "Aggiungi i tuoi oggetti",
    "description": "Inserisci oggetti velocemente con il rapid fire, oppure importa direttamente da una foto con l'intelligenza artificiale."
  },
  "trips": {
    "title": "I tuoi viaggi",
    "description": "Crea un viaggio e seleziona gli oggetti da portare. Durante il viaggio li ritrovi automaticamente segnati come \"in viaggio\"."
  }
}
```

**en-US.json**:
```json
"onboarding": {
  "next": "Next",
  "start": "Get started",
  "houses": {
    "title": "Your homes",
    "description": "Organize your belongings across multiple homes. Create spaces within each house to find everything instantly."
  },
  "items": {
    "title": "Add your items",
    "description": "Quickly add items with rapid fire input, or import directly from a photo using AI."
  },
  "trips": {
    "title": "Your trips",
    "description": "Create a trip and select the items to bring. During the trip, they're automatically marked as \"travelling\"."
  }
}
```

---

## Analytics

### Pattern di chiamata (dal codebase esistente)

```dart
ref.read(analyticsServiceProvider).logEvent(
  'event_name',
  properties: {'key': 'value'},
);
```

Nessun await necessario (il service gestisce internamente errori e null-safety su Amplitude).

### Onboarding events

| Evento | Dove | Proprietà |
|---|---|---|
| `onboarding_started` | `initState` di OnboardingScreen | — |
| `onboarding_page_viewed` | `onPageChanged` del PageController | `page_index: int`, `page_name: String` |
| `onboarding_language_selected` | tap su LanguageTile | `language: 'it'/'en'` |
| `onboarding_completed` | `_handleComplete()` (tap "Inizia") | `language: 'it'/'en'` |

`page_name` mapping: `{0: 'language', 1: 'houses', 2: 'items', 3: 'trips'}`

### Login events (da aggiungere a login_screen.dart)

| Evento | Dove | Proprietà |
|---|---|---|
| `login_screen_viewed` | `initState` di LoginScreen | — |
| `login_attempted` | inizio `_signInWithGoogle()` | `method: 'google'` |
| `login_completed` | auth va a buon fine (nessuna eccezione) | `method: 'google'` |
| `login_failed` | catch in `_signInWithGoogle()` | `method: 'google'`, `error: e.toString()` |

---

## File da creare/modificare

```
CREA:
  lib/features/onboarding/
    view/
      onboarding_screen.dart
      widgets/
        language_slide.dart
        content_slide.dart
    providers/
      onboarding_status_provider.dart
      onboarding_status_provider.g.dart  (generato da build_runner)

MODIFICA:
  lib/core/routing/app_router.dart         — nuova route + redirect guard esteso
  lib/features/auth/view/login_screen.dart — 4 eventi analytics
  assets/translations/it-IT.json          — chiavi onboarding.*
  assets/translations/en-US.json          — chiavi onboarding.*
```

**Nota**: `onboarding_screen.dart` NON usa `new-feature` scaffold perché non ha repository/DAO — è solo UI + provider SharedPreferences.

---

## Edge cases

- **Utente che forza-chiude durante l'onboarding**: il flag `onboarding_completed` viene scritto solo al completamento → alla riapertura riparte dall'inizio. Nessun resume parziale.
- **Cambio lingua e poi back**: non è possibile (swipe disabilitato, no back button su questa route).
- **Reset onboarding**: non esposto in UI; può essere fatto da profile screen in futuro se necessario (cancellando il flag SharedPreferences).
- **Amplitude non configurato**: `analyticsServiceProvider` ritorna `AppAnalyticsService(null)` → `logEvent` è no-op, nessun crash.

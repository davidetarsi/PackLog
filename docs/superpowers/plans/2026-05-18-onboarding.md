# Onboarding Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mostrare un flusso di onboarding di 4 schermate (selezione lingua + 3 slide feature) al primo avvio dell'app, prima del login, tracciando ogni step con Amplitude.

**Architecture:** `OnboardingStatus` è un `AsyncNotifier` con `keepAlive: true` che legge/scrive il flag `onboarding_completed` su SharedPreferences (pattern identico a `ThemeModeNotifier`). Il router viene esteso con un check onboarding come primo redirect, prima del check auth. `_AuthChangeNotifier` ascolta anche `onboardingStatusProvider` per triggerare il refresh automatico del router quando il flag viene scritto.

**Tech Stack:** Riverpod 2.5 + `riverpod_annotation`, GoRouter 14, SharedPreferences, easy_localization, Amplitude (`analyticsServiceProvider`).

---

## File Map

```
CREA:
  lib/features/onboarding/providers/onboarding_status_provider.dart
  lib/features/onboarding/providers/onboarding_status_provider.g.dart  ← generato da build_runner
  lib/features/onboarding/view/widgets/content_slide.dart
  lib/features/onboarding/view/widgets/language_slide.dart
  lib/features/onboarding/view/onboarding_screen.dart
  test/features/onboarding/providers/onboarding_status_provider_test.dart

MODIFICA:
  lib/core/routing/app_router.dart          ← route /onboarding + guard esteso + notifier
  lib/features/auth/view/login_screen.dart  ← 4 eventi analytics
  assets/translations/it-IT.json           ← chiavi onboarding.*
  assets/translations/en-US.json           ← chiavi onboarding.*
```

---

## Task 1: OnboardingStatus provider

**Files:**
- Create: `lib/features/onboarding/providers/onboarding_status_provider.dart`
- Create (generated): `lib/features/onboarding/providers/onboarding_status_provider.g.dart`
- Create: `test/features/onboarding/providers/onboarding_status_provider_test.dart`

- [ ] **Step 1: Crea la directory e scrivi il test (fallirà perché il file non esiste)**

Crea `test/features/onboarding/providers/onboarding_status_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/onboarding/providers/onboarding_status_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OnboardingStatus', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('build() returns false when onboarding_completed not set', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(onboardingStatusProvider.future);
      expect(result, isFalse);
    });

    test('build() returns true when onboarding_completed is true', () async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(onboardingStatusProvider.future);
      expect(result, isTrue);
    });

    test('markCompleted() sets state to AsyncData(true)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Carica stato iniziale
      await container.read(onboardingStatusProvider.future);
      expect(container.read(onboardingStatusProvider).valueOrNull, isFalse);

      // Completa onboarding
      await container.read(onboardingStatusProvider.notifier).markCompleted();

      expect(container.read(onboardingStatusProvider).valueOrNull, isTrue);
    });

    test('markCompleted() persists to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(onboardingStatusProvider.future);
      await container.read(onboardingStatusProvider.notifier).markCompleted();

      // Nuovo container simula riavvio app
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);

      final result = await container2.read(onboardingStatusProvider.future);
      expect(result, isTrue);
    });
  });
}
```

- [ ] **Step 2: Esegui il test — deve fallire**

```bash
flutter test test/features/onboarding/providers/onboarding_status_provider_test.dart
```

Expected: errore di compilazione (`onboarding_status_provider.dart` non esiste).

- [ ] **Step 3: Crea `lib/features/onboarding/providers/onboarding_status_provider.dart`**

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'onboarding_status_provider.g.dart';

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

- [ ] **Step 4: Esegui build_runner per generare il `.g.dart`**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: nessun errore, `onboarding_status_provider.g.dart` creato.

- [ ] **Step 5: Esegui il test — deve passare**

```bash
flutter test test/features/onboarding/providers/onboarding_status_provider_test.dart
```

Expected: `All tests passed.`

- [ ] **Step 6: Commit**

```bash
git add lib/features/onboarding/providers/onboarding_status_provider.dart \
        lib/features/onboarding/providers/onboarding_status_provider.g.dart \
        test/features/onboarding/providers/onboarding_status_provider_test.dart
git commit -m "feat: add OnboardingStatus provider with SharedPreferences persistence"
```

---

## Task 2: Chiavi di traduzione

**Files:**
- Modify: `assets/translations/it-IT.json`
- Modify: `assets/translations/en-US.json`

- [ ] **Step 1: Aggiungi chiavi a `assets/translations/it-IT.json`**

Apri il file e aggiungi la sezione `"onboarding"` prima della chiusura `}` del JSON radice. Rispetta la struttura flat esistente (tutte le sezioni sono al primo livello):

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

- [ ] **Step 2: Aggiungi chiavi a `assets/translations/en-US.json`**

Stessa posizione (prima della chiusura `}` radice):

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

- [ ] **Step 3: Verifica JSON valido**

```bash
dart run --enable-experiment=native-assets - <<'EOF'
import 'dart:convert';
import 'dart:io';
void main() {
  for (final path in ['assets/translations/it-IT.json', 'assets/translations/en-US.json']) {
    try {
      jsonDecode(File(path).readAsStringSync());
      print('OK: $path');
    } catch (e) {
      print('ERRORE in $path: $e');
      exit(1);
    }
  }
}
EOF
```

Alternativa più semplice se il comando sopra non funziona:
```bash
python3 -c "import json; json.load(open('assets/translations/it-IT.json')); json.load(open('assets/translations/en-US.json')); print('JSON valid')"
```

Expected: `OK: ...` per entrambi i file, nessun errore.

- [ ] **Step 4: Commit**

```bash
git add assets/translations/it-IT.json assets/translations/en-US.json
git commit -m "feat: add onboarding translation keys (it/en)"
```

---

## Task 3: ContentSlide widget

**Files:**
- Create: `lib/features/onboarding/view/widgets/content_slide.dart`

Widget riusabile per le slide 1–3. Riceve icon, title key i18n, description key i18n. Nessuna logica di stato.

- [ ] **Step 1: Crea `lib/features/onboarding/view/widgets/content_slide.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../shared/theme/app_spacing.dart';

class ContentSlide extends StatelessWidget {
  final IconData icon;
  final String titleKey;
  final String descriptionKey;

  const ContentSlide({
    super.key,
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: colorScheme.primary),
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
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verifica con `dart analyze`**

```bash
dart analyze lib/features/onboarding/view/widgets/content_slide.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/onboarding/view/widgets/content_slide.dart
git commit -m "feat: add ContentSlide widget for onboarding"
```

---

## Task 4: LanguageSlide widget

**Files:**
- Create: `lib/features/onboarding/view/widgets/language_slide.dart`

Widget puro (StatelessWidget) per la slide 0. Riceve la locale selezionata e una callback. Tutta la logica di selezione è nel parent (`OnboardingScreen`).

`LanguageTile` è in `lib/features/profile/widgets/language_tile.dart`. Ha interfaccia:
```dart
LanguageTile({
  required Locale locale,
  required String title,
  required String flag,
  required bool isSelected,
  required VoidCallback onTap,
})
```

- [ ] **Step 1: Crea `lib/features/onboarding/view/widgets/language_slide.dart`**

```dart
import 'package:flutter/material.dart';
import '../../../../features/profile/widgets/language_tile.dart';
import '../../../../shared/theme/app_spacing.dart';

class LanguageSlide extends StatelessWidget {
  final Locale? selectedLocale;
  final void Function(Locale) onLocaleTapped;

  const LanguageSlide({
    super.key,
    required this.selectedLocale,
    required this.onLocaleTapped,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.language, size: 80, color: colorScheme.primary),
          SizedBox(height: context.spacingLg),
          Text(
            'Scegli la tua lingua\nChoose your language',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.fontSizeLg,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.spacingLg),
          LanguageTile(
            locale: const Locale('it', 'IT'),
            title: 'Italiano',
            flag: '🇮🇹',
            isSelected: selectedLocale?.languageCode == 'it',
            onTap: () => onLocaleTapped(const Locale('it', 'IT')),
          ),
          SizedBox(height: context.spacingSm),
          LanguageTile(
            locale: const Locale('en', 'US'),
            title: 'English',
            flag: '🇬🇧',
            isSelected: selectedLocale?.languageCode == 'en',
            onTap: () => onLocaleTapped(const Locale('en', 'US')),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verifica con `dart analyze`**

```bash
dart analyze lib/features/onboarding/view/widgets/language_slide.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/onboarding/view/widgets/language_slide.dart
git commit -m "feat: add LanguageSlide widget for onboarding"
```

---

## Task 5: OnboardingScreen

**Files:**
- Create: `lib/features/onboarding/view/onboarding_screen.dart`

Dipende da: Task 1 (provider), Task 2 (traduzioni), Task 3 (ContentSlide), Task 4 (LanguageSlide).

**Logica chiave:**

- `_selectedLocale`: locale attualmente selezionata (null = nessuna, inizializzata da device locale in initState)
- `_localeApplied`: true quando `context.setLocale()` è già stato chiamato (evita doppia chiamata se user tappa tile E poi preme Avanti)
- `_currentPage`: pagina corrente, aggiornata da `PageView.onPageChanged`
- `_isNextEnabled`: true se `_currentPage > 0` oppure `_selectedLocale != null`
- `_handleNext()`: se slide 0 e locale non ancora applicata, applica ora; se slide 3, chiama `_handleComplete()`
- `_handleComplete()`: scrive flag via provider (il router si aggiorna automaticamente via `_AuthChangeNotifier`)

**DotsIndicator:** widget privato `_DotsIndicator` implementato inline nel file (solo 4 dot, nessuna dipendenza da package esterni).

- [ ] **Step 1: Crea `lib/features/onboarding/view/onboarding_screen.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../features/onboarding/providers/onboarding_status_provider.dart';
import '../../../shared/providers/language_locale.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import 'widgets/content_slide.dart';
import 'widgets/language_slide.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Locale? _selectedLocale;
  bool _localeApplied = false;

  static const _pageNames = ['language', 'houses', 'items', 'trips'];

  bool get _isNextEnabled {
    if (_currentPage == 0) return _selectedLocale != null;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _initDefaultLocale();
    ref.read(analyticsServiceProvider).logEvent('onboarding_started');
  }

  void _initDefaultLocale() {
    final deviceLang =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    const supported = {
      'it': Locale('it', 'IT'),
      'en': Locale('en', 'US'),
    };
    final match = supported[deviceLang];
    if (match != null) {
      setState(() => _selectedLocale = match);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onLocaleTapped(Locale locale) async {
    await context.setLocale(locale);
    _localeApplied = true;
    ref.read(languageLocaleProvider.notifier).updateLocale(locale.languageCode);
    setState(() => _selectedLocale = locale);
    ref.read(analyticsServiceProvider).logEvent(
      'onboarding_language_selected',
      properties: {'language': locale.languageCode},
    );
  }

  Future<void> _ensureLocaleApplied() async {
    if (!_localeApplied && _selectedLocale != null) {
      await _onLocaleTapped(_selectedLocale!);
    }
  }

  Future<void> _handleNext() async {
    if (_currentPage == 0) {
      await _ensureLocaleApplied();
    }
    if (_currentPage == 3) {
      await _handleComplete();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleComplete() async {
    ref.read(analyticsServiceProvider).logEvent(
      'onboarding_completed',
      properties: {'language': _selectedLocale?.languageCode ?? 'unknown'},
    );
    await ref.read(onboardingStatusProvider.notifier).markCompleted();
    // Il router si aggiorna automaticamente via _AuthChangeNotifier
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Expanded(
              flex: 6,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  ref.read(analyticsServiceProvider).logEvent(
                    'onboarding_page_viewed',
                    properties: {
                      'page_index': index,
                      'page_name': _pageNames[index],
                    },
                  );
                },
                children: [
                  LanguageSlide(
                    selectedLocale: _selectedLocale,
                    onLocaleTapped: _onLocaleTapped,
                  ),
                  const ContentSlide(
                    icon: Icons.home_outlined,
                    titleKey: 'onboarding.houses.title',
                    descriptionKey: 'onboarding.houses.description',
                  ),
                  const ContentSlide(
                    icon: Icons.inventory_2_outlined,
                    titleKey: 'onboarding.items.title',
                    descriptionKey: 'onboarding.items.description',
                  ),
                  const ContentSlide(
                    icon: Icons.luggage_outlined,
                    titleKey: 'onboarding.trips.title',
                    descriptionKey: 'onboarding.trips.description',
                  ),
                ],
              ),
            ),
            const Spacer(),
            _DotsIndicator(
              count: 4,
              currentIndex: _currentPage,
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.outlineVariant,
            ),
            SizedBox(height: context.spacingMd),
            UniversalActionBar(
              primaryLabel: _currentPage < 3
                  ? 'onboarding.next'.tr()
                  : 'onboarding.start'.tr(),
              onPrimaryPressed: _isNextEnabled ? _handleNext : null,
            ),
            SizedBox(height: context.spacingMd),
          ],
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;

  const _DotsIndicator({
    required this.count,
    required this.currentIndex,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
```

- [ ] **Step 2: Verifica con `dart analyze`**

```bash
dart analyze lib/features/onboarding/view/onboarding_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/onboarding/view/onboarding_screen.dart
git commit -m "feat: add OnboardingScreen with PageView, language selection and analytics"
```

---

## Task 6: App router extension

**Files:**
- Modify: `lib/core/routing/app_router.dart`

Tre modifiche distinte in un'unica edit:
1. `_AuthChangeNotifier` ascolta anche `onboardingStatusProvider`
2. Aggiunta route `/onboarding` prima della route `/login`
3. Redirect guard esteso con check onboarding come primo check (dopo bootstrap)

**Attenzione:** il guard deve includere `if (isOnOnboarding) return null;` prima del check auth, altrimenti un utente non autenticato sulla schermata `/onboarding` verrebbe reindirizzato a `/login` durante il flow.

Il file attuale (`lib/core/routing/app_router.dart`) ha:
- `_AuthChangeNotifier` alle righe 34–40
- `redirect:` che inizia alla riga 50
- `routes:` che inizia alla riga 66, con `/login` come prima route alla riga 67

- [ ] **Step 1: Aggiungi import per onboarding screen, provider e bootstrap**

Nel blocco import esistente di `app_router.dart`, aggiungi questi tre import (il file attuale non ha nessuno dei tre):

```dart
import '../../bootstrap.dart';  // per appBootstrapProvider
import '../../features/onboarding/providers/onboarding_status_provider.dart';
import '../../features/onboarding/view/onboarding_screen.dart';
```

- [ ] **Step 2: Estendi `_AuthChangeNotifier` per ascoltare `onboardingStatusProvider`**

Sostituisci il corpo di `_AuthChangeNotifier`:

```dart
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (_, _) {
      notifyListeners();
    });
    ref.listen<AsyncValue<bool>>(onboardingStatusProvider, (_, _) {
      notifyListeners();
    });
  }
}
```

- [ ] **Step 3: Sostituisci il blocco `redirect:` con la versione estesa**

Il redirect attuale è alle righe 50–65. Sostituiscilo con:

```dart
redirect: (context, state) {
  // 1. Bootstrap completato?
  final bootstrapState = ref.read(appBootstrapProvider);
  if (bootstrapState is! AsyncData) return null;

  // 2. Onboarding completato?
  final onboardingState = ref.read(onboardingStatusProvider);
  final bool onboardingCompleted = onboardingState.valueOrNull ?? false;
  final bool isOnOnboarding = state.matchedLocation == '/onboarding';

  if (!onboardingCompleted && !isOnOnboarding) return '/onboarding';
  if (onboardingCompleted && isOnOnboarding) return '/login';
  if (isOnOnboarding) return null; // onboarding in corso, bypassa check auth

  // 3. Auth check (invariato)
  final authState = ref.read(authNotifierProvider);
  final isAuthenticated = authState is Authenticated;
  final isOnLogin = state.matchedLocation == '/login';

  if (!isAuthenticated && !isOnLogin) {
    debugPrint('[Router] redirect → /login (not authenticated)');
    return '/login';
  }
  if (isAuthenticated && isOnLogin) {
    debugPrint('[Router] redirect → / (authenticated, leaving login)');
    return '/';
  }

  return null;
},
```

Nota: `appBootstrapProvider` è definito in `lib/bootstrap.dart`, già importato via `app_router.dart`? Verifica gli import esistenti. Se mancante, aggiungi:
```dart
import '../../bootstrap.dart';
```

- [ ] **Step 4: Aggiungi la route `/onboarding` prima di `/login`**

Nella sezione `routes:`, aggiungi prima del `GoRoute` per `/login`:

```dart
GoRoute(
  path: '/onboarding',
  name: 'onboarding',
  builder: (context, state) => const OnboardingScreen(),
),
```

- [ ] **Step 5: Verifica con `dart analyze` e compila**

```bash
dart analyze lib/core/routing/app_router.dart
```

Poi:
```bash
flutter analyze
```

Expected: `No issues found!` per entrambi.

- [ ] **Step 6: Commit**

```bash
git add lib/core/routing/app_router.dart
git commit -m "feat: extend router with /onboarding route and guard"
```

---

## Task 7: Login analytics

**Files:**
- Modify: `lib/features/auth/view/login_screen.dart`

Aggiunge 4 eventi Amplitude a `LoginScreen`. Il file ha un `ConsumerStatefulWidget` con `_LoginScreenState`. Non toccare la logica di login esistente — aggiungi solo le chiamate analytics.

`analyticsServiceProvider` è in `lib/core/analytics/analytics_service.dart`.

- [ ] **Step 1: Aggiungi import analytics**

In cima a `login_screen.dart`, aggiungi:

```dart
import '../../../core/analytics/analytics_service.dart';
```

- [ ] **Step 2: Aggiungi `initState` con `login_screen_viewed`**

Aggiungi `initState` a `_LoginScreenState` (attualmente non esiste):

```dart
@override
void initState() {
  super.initState();
  ref.read(analyticsServiceProvider).logEvent('login_screen_viewed');
}
```

- [ ] **Step 3: Aggiungi eventi a `_signInWithGoogle()`**

Il metodo attuale è:
```dart
Future<void> _signInWithGoogle() async {
  setState(() => _isLoading = true);
  try {
    await ref.read(authRepositoryProvider).signInWithGoogle();
  } on SignInFailedException catch (e) {
    if (mounted) {
      AppSnackBar.showError(context, 'login.sign_in_failed'.tr());
      debugPrint('[LoginScreen] Sign-in failed: $e');
    }
  } catch (e) {
    if (mounted) {
      AppSnackBar.showError(context, 'login.sign_in_failed'.tr());
      debugPrint('[LoginScreen] Unexpected error: $e');
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

Sostituiscilo con:

```dart
Future<void> _signInWithGoogle() async {
  setState(() => _isLoading = true);
  ref.read(analyticsServiceProvider).logEvent(
    'login_attempted',
    properties: {'method': 'google'},
  );

  try {
    await ref.read(authRepositoryProvider).signInWithGoogle();
    ref.read(analyticsServiceProvider).logEvent(
      'login_completed',
      properties: {'method': 'google'},
    );
  } on SignInFailedException catch (e) {
    ref.read(analyticsServiceProvider).logEvent(
      'login_failed',
      properties: {'method': 'google', 'error': e.toString()},
    );
    if (mounted) {
      AppSnackBar.showError(context, 'login.sign_in_failed'.tr());
      debugPrint('[LoginScreen] Sign-in failed: $e');
    }
  } catch (e) {
    ref.read(analyticsServiceProvider).logEvent(
      'login_failed',
      properties: {'method': 'google', 'error': e.toString()},
    );
    if (mounted) {
      AppSnackBar.showError(context, 'login.sign_in_failed'.tr());
      debugPrint('[LoginScreen] Unexpected error: $e');
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

- [ ] **Step 4: Verifica con `dart analyze`**

```bash
dart analyze lib/features/auth/view/login_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/view/login_screen.dart
git commit -m "feat: add Amplitude analytics events to LoginScreen"
```

---

## Verifica finale

Dopo tutti i task:

- [ ] **Analisi completa**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Test suite completa**

```bash
flutter test
```

Expected: tutti i test passano, inclusi quelli nuovi in `test/features/onboarding/`.

- [ ] **Test manuale del flusso**

Per testare su device/simulator, resetta il flag SharedPreferences prima:
```dart
// In bootstrap.dart (temporaneo per testing):
// await SharedPreferences.getInstance().then((p) => p.remove('onboarding_completed'));
```

Oppure disinstalla e reinstalla l'app. Verifica:
1. Prima installazione → `/onboarding` appare (slide lingua)
2. Locale device pre-selezionata, bottone Avanti abilitato
3. Tap su lingua diversa → tile si aggiorna, locale cambia immediatamente
4. Avanti × 3 → slide houses, items, trips
5. "Inizia" → redirect a `/login`
6. Riavvio app → `/login` direttamente (skip onboarding)
7. Amplitude: verifica `onboarding_started`, `onboarding_page_viewed` ×4, `onboarding_language_selected`, `onboarding_completed`
8. `login_screen_viewed` loggato al mount di LoginScreen

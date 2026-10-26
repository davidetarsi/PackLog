# Navigazione: due luoghi + azione contestuale — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Barra flottante con due luoghi (Case, Viaggi), bottone d'azione staccato che fa l'azione della tab corrente, Profilo come avatar in alto a destra.

**Architecture:** `MainShell` perde lo speed-dial "Crea" e il ramo Profilo; la barra diventa `[pillola Case|Viaggi] + PrimaryActionButton`. In Case il bottone apre `AddItemsSheet` (casa di destinazione + Scansiona con AI / Scrivi a mano), in Viaggi spinge `/new-trip`. Le due tab usano un `TabHeader` comune (titolo + `ProfileAvatarButton`). `/profile` diventa una route sul navigator radice. Il tour guidato punta ai nuovi bersagli.

**Tech Stack:** Flutter 3.38.5, Riverpod 2.5, GoRouter 14 (`StatefulShellRoute.indexedStack`), easy_localization, mocktail.

**Spec:** `docs/superpowers/specs/2026-10-13-navigazione-azione-contestuale-design.md`

## Global Constraints

- Branch: `feat/nav-azione-contestuale`, creato da `origin/develop`. Mai push su `develop`/`main`; nessun upstream finché il controller non pusha.
- Leggi `CLAUDE.md` e `.claude/skills/ui-design-system/SKILL.md` prima di toccare UI: niente colori/spacing/font hardcoded (usa `colorScheme`, `context.spacingXx`, `context.responsive()`, `AppConstants`).
- Ogni stringa nuova va in **entrambi** `assets/translations/it-IT.json` e `assets/translations/en-US.json`.
- Nei widget test le traduzioni non sono caricate: `.tr()` restituisce la chiave grezza. Cerca i widget per `Key`, non per testo tradotto.
- Nessun nuovo provider `@riverpod`: non serve `build_runner`.
- Dopo ogni task: `dart format lib/ test/`, `dart analyze` pulito, test del task verdi, poi commit.
- Non toccare i file non tracciati dell'utente: `.claude/launch.json`, `.codex/`, `design-previews/`, `package-lock.json`.
- I commit terminano con la riga `Co-Authored-By` del modello che li scrive.

---

### Task 1: Eventi analytics

**Files:**
- Modify: `lib/core/analytics/core_analytics_service.dart` (nuova sezione dopo `// ── item_ ──`)
- Test: `test/core/analytics/core_analytics_service_test.dart`

**Interfaces:**
- Produces: `CoreAnalyticsService.trackPrimaryActionTapped({required String tab, required String action, required bool enabled})` e `CoreAnalyticsService.trackAddItemsSheetChoice({required String choice})`.

- [ ] **Step 1: Crea il branch**

```bash
git fetch origin
git switch -c feat/nav-azione-contestuale origin/develop
git branch --unset-upstream 2>/dev/null || true
```

- [ ] **Step 2: Test che fallisce** — aggiungi in fondo al `main()` di `test/core/analytics/core_analytics_service_test.dart`:

```dart
  group('navigation_', () {
    test('trackPrimaryActionTapped logs primary_action_tapped', () async {
      service.trackPrimaryActionTapped(
        tab: 'houses',
        action: 'add_items',
        enabled: false,
      );
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'primary_action_tapped',
          properties: {'tab': 'houses', 'action': 'add_items', 'enabled': false},
        ),
      ).called(1);
    });

    test('trackAddItemsSheetChoice logs add_items_sheet_choice', () async {
      service.trackAddItemsSheetChoice(choice: 'ai_scan');
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'add_items_sheet_choice',
          properties: {'choice': 'ai_scan'},
        ),
      ).called(1);
    });
  });
```

- [ ] **Step 3: Verifica che fallisca**

Run: `flutter test test/core/analytics/core_analytics_service_test.dart`
Expected: errore di compilazione, `trackPrimaryActionTapped` non definito.

- [ ] **Step 4: Implementa** — in `core_analytics_service.dart`, subito prima di `// ── space_` (o dopo il blocco `item_`):

```dart
  // ── navigation_ ───────────────────────────────────────────────────────────

  /// Tocco sul bottone d'azione della shell. `enabled: false` = bottone
  /// spento (tab Case senza case): misura quante volte l'utente lo cerca
  /// prima di avere una casa.
  void trackPrimaryActionTapped({
    required String tab,
    required String action,
    required bool enabled,
  }) {
    _safeLogEvent(
      'primary_action_tapped',
      properties: {'tab': tab, 'action': action, 'enabled': enabled},
    );
  }

  /// Scelta nel foglio "Aggiungi oggetti": `ai_scan` o `manual`.
  void trackAddItemsSheetChoice({required String choice}) {
    _safeLogEvent('add_items_sheet_choice', properties: {'choice': choice});
  }
```

- [ ] **Step 5: Verifica che passi**

Run: `flutter test test/core/analytics/core_analytics_service_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/analytics/core_analytics_service.dart test/core/analytics/core_analytics_service_test.dart
git commit -m "feat(analytics): eventi del bottone d'azione e del foglio Aggiungi oggetti"
```

---

### Task 2: Foglio "Aggiungi oggetti"

**Files:**
- Create: `lib/features/items/view/add_items_sheet.dart`
- Modify: `assets/translations/it-IT.json`, `assets/translations/en-US.json` (oggetto `items`)
- Test: `test/features/items/view/add_items_sheet_test.dart`

**Interfaces:**
- Consumes: `houseNotifierProvider` (`lib/features/houses/providers/house_provider.dart`, `AsyncValue<List<HouseModel>>`), `DsSheetHeader({required String title})`, `DsPickerSheet.show<T>({context, title, items, getLabel, getIcon, selected})`, `DsButton(label:, onPressed:, icon:, variant: DsButtonVariant.secondary, expand: true)`, `HouseIcons.getIcon(String)`.
- Produces:
  - `enum AddItemsMethod { aiScan, manual }`
  - `class AddItemsChoice { final AddItemsMethod method; final String houseId; }`
  - `HouseModel? defaultDestinationHouse(List<HouseModel> houses)`
  - `Future<AddItemsChoice?> showAddItemsSheet(BuildContext context)`
  - `class AddItemsSheet extends ConsumerStatefulWidget`
  - Keys: `Key('add_items_destination')`, `Key('add_items_ai_scan')`, `Key('add_items_manual')`.

Il foglio **non naviga**: restituisce la scelta e la shell (Task 6) apre la rotta o il form. Così il contesto usato per navigare è sempre quello della shell, non quello del foglio già chiuso.

- [ ] **Step 1: Traduzioni** — dentro l'oggetto `"items"`:

it-IT:
```json
"add_sheet": {
  "title": "Aggiungi oggetti",
  "destination": "Nella casa",
  "choose_house": "Scegli la casa",
  "ai_scan": "Scansiona con AI",
  "ai_scan_hint": "Fotografa i vestiti: l'AI li riconosce e li salva",
  "manual": "Scrivi a mano"
}
```
en-US:
```json
"add_sheet": {
  "title": "Add items",
  "destination": "In house",
  "choose_house": "Choose house",
  "ai_scan": "Scan with AI",
  "ai_scan_hint": "Take a photo of your clothes: AI recognises and saves them",
  "manual": "Type it in"
}
```

- [ ] **Step 2: Test che falliscono** — `test/features/items/view/add_items_sheet_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/items/view/add_items_sheet.dart';

HouseModel _house(String id, {bool primary = false}) => HouseModel(
  id: id,
  name: 'Casa $id',
  isPrimary: primary,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _FakeHouseNotifier extends HouseNotifier {
  _FakeHouseNotifier(this.houses);
  final List<HouseModel> houses;
  @override
  Future<List<HouseModel>> build() async => houses;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('defaultDestinationHouse', () {
    test('null senza case', () {
      expect(defaultDestinationHouse(const []), isNull);
    });
    test('preferisce la casa principale', () {
      final houses = [_house('a'), _house('b', primary: true)];
      expect(defaultDestinationHouse(houses)!.id, 'b');
    });
    test('senza principale prende la prima', () {
      final houses = [_house('a'), _house('b')];
      expect(defaultDestinationHouse(houses)!.id, 'a');
    });
  });

  Future<Future<AddItemsChoice?> Function()> pumpLauncher(
    WidgetTester tester,
    List<HouseModel> houses,
  ) async {
    AddItemsChoice? result;
    var done = false;
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('it', 'IT')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        saveLocale: false,
        child: ProviderScope(
          overrides: [
            houseNotifierProvider.overrideWith(() => _FakeHouseNotifier(houses)),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  key: const Key('open'),
                  onPressed: () async {
                    result = await showAddItemsSheet(context);
                    done = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return () async {
      expect(done, isTrue, reason: 'il foglio doveva chiudersi');
      return result;
    };
  }

  testWidgets('Scansiona con AI restituisce la casa principale', (tester) async {
    final read = await pumpLauncher(tester, [_house('a'), _house('b', primary: true)]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byType(AddItemsSheet), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_items_ai_scan')));
    await tester.pumpAndSettle();

    final choice = await read();
    expect(choice!.method, AddItemsMethod.aiScan);
    expect(choice.houseId, 'b');
  });

  testWidgets('cambiare casa e scegliere Scrivi a mano', (tester) async {
    final read = await pumpLauncher(tester, [_house('a', primary: true), _house('b')]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_items_destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casa b').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_items_manual')));
    await tester.pumpAndSettle();

    final choice = await read();
    expect(choice!.method, AddItemsMethod.manual);
    expect(choice.houseId, 'b');
  });
}
```

Nota: se `HouseModel.displayName` non coincide con `name` quando la località manca, adatta `find.text('Casa b')` al valore reale di `displayName` (leggi `house_model.dart`).

- [ ] **Step 3: Verifica che falliscano**

Run: `flutter test test/features/items/view/add_items_sheet_test.dart`
Expected: errore di compilazione (`add_items_sheet.dart` non esiste).

- [ ] **Step 4: Implementa** — `lib/features/items/view/add_items_sheet.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_button.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../../../shared/widgets/ds_sheet_header.dart';
import '../../houses/model/house_model.dart';
import '../../houses/providers/house_provider.dart';

enum AddItemsMethod { aiScan, manual }

/// Scelta fatta nel foglio: chi lo apre decide come navigare.
class AddItemsChoice {
  final AddItemsMethod method;
  final String houseId;
  const AddItemsChoice(this.method, this.houseId);
}

/// Casa proposta di default: la principale, altrimenti la prima.
HouseModel? defaultDestinationHouse(List<HouseModel> houses) {
  if (houses.isEmpty) return null;
  return houses.firstWhere((h) => h.isPrimary, orElse: () => houses.first);
}

/// Foglio dell'azione principale della tab Case. Non naviga: restituisce la
/// scelta, così la shell usa il proprio contesto (quello del foglio è già
/// smontato quando la `Future` si completa).
Future<AddItemsChoice?> showAddItemsSheet(BuildContext context) {
  return showModalBottomSheet<AddItemsChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const AddItemsSheet(),
  );
}

class AddItemsSheet extends ConsumerStatefulWidget {
  const AddItemsSheet({super.key});

  @override
  ConsumerState<AddItemsSheet> createState() => _AddItemsSheetState();
}

class _AddItemsSheetState extends ConsumerState<AddItemsSheet> {
  String? _selectedHouseId;

  HouseModel? _destination(List<HouseModel> houses) {
    for (final h in houses) {
      if (h.id == _selectedHouseId) return h;
    }
    return defaultDestinationHouse(houses);
  }

  Future<void> _chooseHouse(List<HouseModel> houses, HouseModel current) async {
    final picked = await DsPickerSheet.show<HouseModel>(
      context: context,
      title: 'items.add_sheet.choose_house'.tr(),
      items: houses,
      getLabel: (h) => h.displayName,
      getIcon: (h) => HouseIcons.getIcon(h.iconName),
      selected: current,
    );
    if (picked != null && mounted) {
      setState(() => _selectedHouseId = picked.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final houses = ref.watch(houseNotifierProvider).valueOrNull ?? const [];
    final house = _destination(houses);

    return Padding(
      padding: EdgeInsets.only(bottom: AppConstants.bottomSheetBottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSheetHeader(title: 'items.add_sheet.title'.tr()),
          if (house != null)
            ListTile(
              key: const Key('add_items_destination'),
              leading: Icon(HouseIcons.getIcon(house.iconName)),
              title: Text('items.add_sheet.destination'.tr()),
              subtitle: Text(house.displayName),
              trailing: const Icon(Icons.unfold_more),
              onTap: () => _chooseHouse(houses, house),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacingMd,
              vertical: context.spacingSm,
            ),
            child: Material(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
              child: InkWell(
                key: const Key('add_items_ai_scan'),
                borderRadius: BorderRadius.circular(
                  AppConstants.cardBorderRadius,
                ),
                onTap: house == null
                    ? null
                    : () => Navigator.of(context).pop(
                        AddItemsChoice(AddItemsMethod.aiScan, house.id),
                      ),
                child: Padding(
                  padding: EdgeInsets.all(context.spacingMd),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: context.iconSizeLg,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      SizedBox(width: context.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'items.add_sheet.ai_scan'.tr(),
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            SizedBox(height: context.spacingXs),
                            Text(
                              'items.add_sheet.ai_scan_hint'.tr(),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
            child: DsButton(
              key: const Key('add_items_manual'),
              label: 'items.add_sheet.manual'.tr(),
              icon: Icons.edit_outlined,
              variant: DsButtonVariant.secondary,
              expand: true,
              onPressed: house == null
                  ? null
                  : () => Navigator.of(context).pop(
                      AddItemsChoice(AddItemsMethod.manual, house.id),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Se `DsButton.onPressed` non è nullable, passa una closure che non fa nulla quando `house == null` (il foglio viene aperto solo con almeno una casa, vedi Task 6).

- [ ] **Step 5: Verifica che passino**

Run: `flutter test test/features/items/view/add_items_sheet_test.dart`
Expected: PASS (5 test).

- [ ] **Step 6: Commit**

```bash
git add lib/features/items/view/add_items_sheet.dart test/features/items/view/add_items_sheet_test.dart assets/translations/it-IT.json assets/translations/en-US.json
git commit -m "feat(items): foglio Aggiungi oggetti con casa di destinazione e scansione AI in primo piano"
```

---

### Task 3: Intestazione delle tab con avatar del profilo

**Files:**
- Create: `lib/shared/widgets/tab_header.dart`
- Modify: traduzioni (oggetto `navigation`)
- Test: `test/shared/widgets/tab_header_test.dart`

**Interfaces:**
- Consumes: `authNotifierProvider` (`lib/core/auth/auth_provider.dart`; stato `Authenticated(userId, email, displayName)` / `Unauthenticated()`), `totalUnsyncedCountProvider` (`lib/core/sync/sync_provider.dart`, `AsyncValue<int>`).
- Produces:
  - `String profileInitials(String? displayName, String email)`
  - `class ProfileAvatar extends StatelessWidget` — `({required String initials, required bool showSyncDot, required VoidCallback onTap})`, `Key('profile_avatar')` sull'area toccabile.
  - `class ProfileAvatarButton extends ConsumerWidget` — cablato su auth + sync, apre `/profile` con `context.push`.
  - `class TabHeader extends StatelessWidget` — `({required String title})`, titolo a sinistra + `ProfileAvatarButton` a destra.

- [ ] **Step 1: Traduzioni** — in `"navigation"`:
  - it-IT: `"open_profile": "Apri profilo", "add_items": "Aggiungi oggetti", "new_trip": "Nuovo viaggio", "create_house_first": "Crea prima una casa"`
  - en-US: `"open_profile": "Open profile", "add_items": "Add items", "new_trip": "New trip", "create_house_first": "Create a house first"`

(Le ultime tre servono al Task 6: aggiungile ora per fare un solo commit sulle chiavi di navigazione.)

- [ ] **Step 2: Test che falliscono** — `test/shared/widgets/tab_header_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/widgets/tab_header.dart';

void main() {
  group('profileInitials', () {
    test('nome e cognome', () {
      expect(profileInitials('Davide Rossi', 'd@x.it'), 'DR');
    });
    test('tre parole: prima e ultima', () {
      expect(profileInitials('Anna Maria Bianchi', 'a@x.it'), 'AB');
    });
    test('un solo nome', () {
      expect(profileInitials('  davide ', 'd@x.it'), 'D');
    });
    test('senza nome usa la email', () {
      expect(profileInitials(null, 'marco@x.it'), 'M');
      expect(profileInitials('', 'marco@x.it'), 'M');
    });
    test('niente di niente', () {
      expect(profileInitials(null, ''), '?');
    });
  });

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('mostra le iniziali e il pallino solo se richiesto', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(ProfileAvatar(initials: 'DR', showSyncDot: false, onTap: () => taps++)),
    );
    expect(find.text('DR'), findsOneWidget);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);

    await tester.tap(find.byKey(const Key('profile_avatar')));
    expect(taps, 1);

    await tester.pumpWidget(
      wrap(ProfileAvatar(initials: 'DR', showSyncDot: true, onTap: () {})),
    );
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
  });
}
```

- [ ] **Step 3: Verifica che falliscano**

Run: `flutter test test/shared/widgets/tab_header_test.dart`
Expected: errore di compilazione.

- [ ] **Step 4: Implementa** — `lib/shared/widgets/tab_header.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/sync/sync_provider.dart';
import '../theme/app_spacing.dart';

/// Iniziali per l'avatar: prima e ultima parola del nome, altrimenti la
/// prima lettera della email, altrimenti "?".
String profileInitials(String? displayName, String email) {
  final words = (displayName ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isNotEmpty) {
    final first = words.first[0];
    final last = words.length > 1 ? words.last[0] : '';
    return (first + last).toUpperCase();
  }
  final mail = email.trim();
  return mail.isNotEmpty ? mail[0].toUpperCase() : '?';
}

/// Intestazione comune delle tab della shell: titolo a sinistra, avatar del
/// profilo a destra.
class TabHeader extends StatelessWidget {
  final String title;

  const TabHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        context.spacingSm,
        context.spacingSm,
        context.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const ProfileAvatarButton(),
        ],
      ),
    );
  }
}

/// Avatar cablato su auth e sync. Apre il profilo sopra la shell.
class ProfileAvatarButton extends ConsumerWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final initials = switch (authState) {
      Authenticated(:final displayName, :final email) => profileInitials(
        displayName,
        email,
      ),
      Unauthenticated() => '?',
    };
    final unsynced = ref.watch(totalUnsyncedCountProvider).valueOrNull ?? 0;

    return ProfileAvatar(
      initials: initials,
      showSyncDot: unsynced > 0,
      onTap: () => context.push('/profile'),
    );
  }
}

/// Avatar puro (testabile senza provider).
class ProfileAvatar extends StatelessWidget {
  final String initials;
  final bool showSyncDot;
  final VoidCallback onTap;

  const ProfileAvatar({
    super.key,
    required this.initials,
    required this.showSyncDot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = context.responsive(40);

    return Semantics(
      button: true,
      label: 'navigation.open_profile'.tr(),
      child: InkResponse(
        key: const Key('profile_avatar'),
        onTap: onTap,
        radius: size,
        child: Padding(
          padding: EdgeInsets.all(context.spacingXs),
          child: Badge(
            isLabelVisible: showSyncDot,
            smallSize: context.responsive(10),
            backgroundColor: colorScheme.primary,
            child: CircleAvatar(
              radius: size / 2,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                initials,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Verifica l'import reale dello stato auth (`Authenticated`/`Unauthenticated`): cerca `class Authenticated` o `sealed class AuthState` sotto `lib/core/auth/` e correggi il path se diverso da `auth_state.dart`. `profile_screen.dart` usa già lo stesso `switch`: copia i suoi import.

- [ ] **Step 5: Verifica che passino**

Run: `flutter test test/shared/widgets/tab_header_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/tab_header.dart test/shared/widgets/tab_header_test.dart assets/translations/it-IT.json assets/translations/en-US.json
git commit -m "feat(shell): intestazione delle tab con avatar del profilo e pallino di sync"
```

---

### Task 4: Tab Case — intestazione e riga "Nuova casa"

**Files:**
- Create: `lib/shared/widgets/ds_dashed_box.dart`
- Create: `lib/features/houses/helpers/create_house_flow.dart`
- Create: `lib/features/houses/view/widgets/new_house_row.dart`
- Modify: `lib/features/houses/view/houses_screen.dart`
- Modify: `lib/features/tour/tour_keys.dart` (aggiungi `newHouseRow`)
- Modify: traduzioni (`houses.new_house_row`)
- Test: `test/features/houses/view/new_house_row_test.dart`

**Interfaces:**
- Consumes: `TabHeader` (Task 3), `showAddEditHouseSheet(BuildContext)` (`lib/features/houses/view/add_edit_house_screen.dart`), `postLoginOnboardingProvider`, `houseNotifierProvider`.
- Produces:
  - `class DsDashedBox extends StatelessWidget` — `({required Widget child, double radius = AppConstants.cardBorderRadius, Color? color})`
  - `Future<void> createHouseWithTourAdvance(BuildContext context, WidgetRef ref)`
  - `class NewHouseRow extends ConsumerWidget` — riga tratteggiata, `onTap` → `createHouseWithTourAdvance`.
  - `tourKeys.newHouseRow` (`GlobalKey`), assegnata alla `NewHouseRow` nella lista case.

- [ ] **Step 1: Traduzioni** — in `"houses"`: it-IT `"new_house_row": "Nuova casa"`, en-US `"new_house_row": "New house"`.

- [ ] **Step 2: Test che fallisce** — `test/features/houses/view/new_house_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/widgets/ds_dashed_box.dart';

void main() {
  testWidgets('DsDashedBox disegna il bordo tratteggiato attorno al figlio', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DsDashedBox(child: Text('Nuova casa'))),
      ),
    );
    expect(find.text('Nuova casa'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DsDashedBox),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
  });
}
```

- [ ] **Step 3: Verifica che fallisca**

Run: `flutter test test/features/houses/view/new_house_row_test.dart`
Expected: errore di compilazione.

- [ ] **Step 4: `DsDashedBox`** — `lib/shared/widgets/ds_dashed_box.dart`:

```dart
import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Contenitore con bordo tratteggiato: segnala uno "spazio vuoto, aggiungi
/// qui" senza usare colore d'accento.
class DsDashedBox extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color? color;

  const DsDashedBox({
    super.key,
    required this.child,
    this.radius = AppConstants.cardBorderRadius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: color ?? Theme.of(context).colorScheme.outline,
        radius: radius,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRRectPainter({required this.color, required this.radius});

  static const _dash = 6.0;
  static const _gap = 4.0;
  static const _stroke = 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect.deflate(_stroke / 2),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
```

- [ ] **Step 5: Verifica che passi**

Run: `flutter test test/features/houses/view/new_house_row_test.dart`
Expected: PASS.

- [ ] **Step 6: Flusso "crea casa" condiviso** — `lib/features/houses/helpers/create_house_flow.dart`. È la logica oggi in `MainShell._onCreateHouse` (righe 107-126), spostata qui così la usano la riga Nuova casa e lo stato vuoto:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tour/model/onboarding_state.dart';
import '../../tour/providers/post_login_onboarding_provider.dart';
import '../providers/house_provider.dart';
import '../view/add_edit_house_screen.dart';

/// Apre il form "nuova casa". Se il tour è sullo step `houseTooltip` e una
/// casa viene davvero creata, avanza il tour.
Future<void> createHouseWithTourAdvance(
  BuildContext context,
  WidgetRef ref,
) async {
  final onboardingStep = ref.read(postLoginOnboardingProvider).valueOrNull?.step;
  final housesBefore = ref.read(houseNotifierProvider).valueOrNull?.length ?? 0;

  await showAddEditHouseSheet(context);

  if (!context.mounted) return;
  if (onboardingStep == OnboardingStep.houseTooltip) {
    final housesAfter = ref.read(houseNotifierProvider).valueOrNull?.length ?? 0;
    if (housesAfter > housesBefore) {
      await ref.read(postLoginOnboardingProvider.notifier).advance();
    }
  }
}
```

- [ ] **Step 7: `NewHouseRow`** — `lib/features/houses/view/widgets/new_house_row.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_dashed_box.dart';
import '../../helpers/create_house_flow.dart';

/// Ultima riga della lista case: azione rara, quindi neutra (niente arancio).
class NewHouseRow extends ConsumerWidget {
  const NewHouseRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppConstants.cardBorderRadius);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacingMd,
        vertical: context.spacingSm,
      ),
      child: DsDashedBox(
        color: colorScheme.outlineVariant,
        child: InkWell(
          borderRadius: radius,
          onTap: () => createHouseWithTourAdvance(context, ref),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: context.responsive(72)),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: colorScheme.onSurfaceVariant),
                  SizedBox(width: context.spacingSm),
                  Text(
                    'houses.new_house_row'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: Chiave del tour** — in `lib/features/tour/tour_keys.dart` aggiungi dentro `_TourKeys`:

```dart
  /// Riga "Nuova casa" in fondo alla lista case. Target di
  /// [OnboardingStep.houseTooltip].
  final newHouseRow = GlobalKey();
```

- [ ] **Step 9: `HousesScreen`** — in `lib/features/houses/view/houses_screen.dart`:
  1. Avvolgi il `body` di `ShellTabScaffold` così:
     ```dart
     return ShellTabScaffold(
       body: Column(
         children: [
           TabHeader(title: 'navigation.houses'.tr()),
           Expanded(
             child: housesAsync.when(
               // ... contenuto attuale invariato ...
             ),
           ),
         ],
       ),
     );
     ```
  2. Nello stato vuoto, sostituisci `onPressed: () => showAddEditHouseSheet(context)` con `onPressed: () => createHouseWithTourAdvance(context, ref)`.
  3. Nel `ListView.builder`: `top: context.spacingSm` invece di `context.spacingMd` (l'intestazione ha già il suo respiro), `itemCount: sortedHouses.length + 1`, e:
     ```dart
     itemBuilder: (context, index) {
       if (index == sortedHouses.length) {
         return NewHouseRow(key: tourKeys.newHouseRow);
       }
       return _HouseCard(house: sortedHouses[index]);
     },
     ```
  4. Import: `../../../shared/widgets/tab_header.dart`, `../helpers/create_house_flow.dart`, `widgets/new_house_row.dart`, `../../tour/tour_keys.dart`. Togli l'import di `add_edit_house_screen.dart` se resta inutilizzato.

- [ ] **Step 10: Verifica**

Run: `dart analyze && flutter test test/features/houses/`
Expected: nessun issue, test verdi. Se un test esistente di `HousesScreen` ora fallisce perché `TabHeader` legge auth e sync, aggiungi agli override `totalUnsyncedCountProvider.overrideWith((ref) async => 0)` e lo stato auth come fanno gli altri test che montano schermate con `authNotifierProvider` (cerca un esempio con `grep -rn authNotifierProvider test`).

- [ ] **Step 11: Commit**

```bash
git add lib/shared/widgets/ds_dashed_box.dart lib/features/houses/ lib/features/tour/tour_keys.dart test/features/houses/view/new_house_row_test.dart assets/translations/
git commit -m "feat(houses): intestazione con avatar e riga Nuova casa tratteggiata in fondo alla lista"
```

---

### Task 5: Tab Viaggi — intestazione comune

**Files:**
- Modify: `lib/features/trips/view/trips_screen.dart` (build ~riga 137, `headerWidgets` ~righe 189-213)

**Interfaces:**
- Consumes: `TabHeader` (Task 3).

- [ ] **Step 1: Intestazione fissa** — nel `build`, avvolgi il body come nel Task 4:

```dart
return ShellTabScaffold(
  body: Column(
    children: [
      TabHeader(title: 'navigation.trips'.tr()),
      Expanded(
        child: tripsAsync.when(
          // ... invariato ...
        ),
      ),
    ],
  ),
);
```

- [ ] **Step 2: Togli il titolone** — in `_buildTripsContent`, da `headerWidgets` elimina il `Padding` con `Text('trips.welcome_title'.tr(), ...)` e il `SizedBox(height: context.spacingMd)` che lo segue. Restano le pill dei filtri e il loro `SizedBox` finale. Non cancellare la chiave `trips.welcome_title` dalle traduzioni (potrebbe servire al ridisegno della tab).

- [ ] **Step 3: Import** — `../../../shared/widgets/tab_header.dart`.

- [ ] **Step 4: Verifica**

Run: `dart analyze && flutter test test/features/trips/`
Expected: nessun issue, test verdi. Se un test cercava `trips.welcome_title`, aggiornalo a `TabHeader`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/view/trips_screen.dart test/features/trips/
git commit -m "feat(trips): intestazione comune con avatar al posto del titolone"
```

---

### Task 6: Shell con due luoghi e bottone d'azione; Profilo fuori dalla barra

**Files:**
- Create: `lib/shared/widgets/primary_action_button.dart`
- Rewrite: `lib/shared/widgets/main_shell.dart`
- Modify: `lib/core/routing/app_router.dart` (shell ~righe 145-180, chiavi navigator in testa al file)
- Modify: `lib/features/profile/view/profile_screen.dart` (build ~righe 219-240)
- Test: `test/shared/widgets/primary_action_button_test.dart`, `test/shared/widgets/main_shell_test.dart`

**Interfaces:**
- Consumes: `showAddItemsSheet`, `AddItemsChoice`, `AddItemsMethod` (Task 2); `CoreAnalyticsService.trackPrimaryActionTapped/trackAddItemsSheetChoice` via `coreAnalyticsServiceProvider` (Task 1); `showAddEditItemSheet(context, houseId:)`; `AppSnackBar.showWarning(context, message)` (`lib/shared/helpers/snack_bar_helper.dart`); `tourKeys.housesTab`, `tourKeys.tripsTab`, `tourKeys.houseFab`.
- Produces:
  - `class PrimaryActionButton extends StatefulWidget` — `({required IconData icon, required String label, required VoidCallback onPressed, bool enabled = true, Duration labelDuration = const Duration(seconds: 2)})`. Mostra l'etichetta all'avvio e ogni volta che `label` cambia, poi si richiude.
  - Keys: `Key('nav_houses')`, `Key('nav_trips')`, `Key('primary_action_button')`. `tourKeys.houseFab` resta sul bottone d'azione (il Task 7 la rinomina).
  - Rami shell: 0 = `/`, 1 = `/trips`. `/profile` è una `GoRoute` con `parentNavigatorKey: _rootNavigatorKey`.

- [ ] **Step 1: Test del bottone** — `test/shared/widgets/primary_action_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/widgets/primary_action_button.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('etichetta visibile all\'avvio, poi si richiude', (tester) async {
    await tester.pumpWidget(
      wrap(PrimaryActionButton(icon: Icons.add, label: 'Aggiungi', onPressed: () {})),
    );
    expect(find.text('Aggiungi'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Aggiungi'), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('cambiare etichetta la rimostra', (tester) async {
    await tester.pumpWidget(
      wrap(PrimaryActionButton(icon: Icons.add, label: 'A', onPressed: () {})),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing);

    await tester.pumpWidget(
      wrap(PrimaryActionButton(icon: Icons.add, label: 'B', onPressed: () {})),
    );
    await tester.pump();
    expect(find.text('B'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('spento: colore tonale ma risponde al tocco', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        PrimaryActionButton(
          icon: Icons.add,
          label: 'X',
          enabled: false,
          onPressed: () => taps++,
        ),
      ),
    );
    final scheme = Theme.of(tester.element(find.byType(PrimaryActionButton))).colorScheme;
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(PrimaryActionButton),
        matching: find.byType(Material),
      ).first,
    );
    expect(material.color, scheme.surfaceContainerHighest);

    await tester.tap(find.byType(PrimaryActionButton));
    expect(taps, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
```

- [ ] **Step 2: Verifica che falliscano**

Run: `flutter test test/shared/widgets/primary_action_button_test.dart`
Expected: errore di compilazione.

- [ ] **Step 3: Implementa** — `lib/shared/widgets/primary_action_button.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Bottone d'azione della shell, staccato dalla barra dei luoghi.
///
/// All'avvio e a ogni cambio di [label] si allarga mostrando l'etichetta per
/// [labelDuration], poi torna tondo con la sola icona. Con `enabled: false`
/// diventa tonale (non arancio) ma **risponde comunque al tocco**: chi lo usa
/// spiega perché l'azione non è disponibile.
class PrimaryActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final Duration labelDuration;

  const PrimaryActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.labelDuration = const Duration(seconds: 2),
  });

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton> {
  bool _showLabel = true;
  Timer? _collapseTimer;

  @override
  void initState() {
    super.initState();
    _scheduleCollapse();
  }

  @override
  void didUpdateWidget(PrimaryActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label) {
      setState(() => _showLabel = true);
      _scheduleCollapse();
    }
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(widget.labelDuration, () {
      if (mounted) setState(() => _showLabel = false);
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = widget.enabled
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final foreground = widget.enabled
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;
    final size = context.responsive(56);

    return Semantics(
      button: true,
      label: widget.label,
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        elevation: widget.enabled ? 3 : 0,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: widget.onPressed,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: Container(
              height: size,
              constraints: BoxConstraints(minWidth: size),
              padding: EdgeInsets.symmetric(
                horizontal: _showLabel ? context.spacingMd : 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: foreground, size: context.iconSizeMd),
                  if (_showLabel) ...[
                    SizedBox(width: context.spacingSm),
                    Text(
                      widget.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verifica che passino**

Run: `flutter test test/shared/widgets/primary_action_button_test.dart`
Expected: PASS.

- [ ] **Step 5: Router** — in `lib/core/routing/app_router.dart`:
  1. Elimina la dichiarazione di `_profileNavigatorKey` in testa al file.
  2. Nel `StatefulShellRoute.indexedStack` elimina il primo `StatefulShellBranch` (quello di `/profile`): restano Case (`/`) e Viaggi (`/trips`).
  3. Subito dopo lo `StatefulShellRoute`, aggiungi:
     ```dart
     GoRoute(
       path: '/profile',
       name: 'profile',
       parentNavigatorKey: _rootNavigatorKey,
       builder: (context, state) => const ProfileScreen(),
     ),
     ```

- [ ] **Step 6: Profilo con freccia indietro** — in `profile_screen.dart`, sostituisci `ShellTabScaffold(appBar: AppBar(..., automaticallyImplyLeading: false), body: ...)` con:

```dart
return Scaffold(
  appBar: AppBar(title: Text('settings.title'.tr())),
  body: SafeArea(
    top: false,
    bottom: false,
    child: RefreshIndicator(
      // ... body attuale invariato ...
    ),
  ),
);
```

Il `padding` del `ListView` resta com'è: fuori dalla shell `navBarReservedHeight` vale la sola gesture bar, che è proprio lo spazio da riservare. Aggiorna il commento sopra il padding (non parla più di nav bar flottante) e togli l'import di `shell_tab_scaffold.dart`. Aggiorna anche il doc-comment della classe se dice che è un tab della shell.

- [ ] **Step 7: Riscrivi `MainShell`** — sostituisci l'intero contenuto di `lib/shared/widgets/main_shell.dart`:

```dart
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/core_analytics_service.dart';
import '../../features/houses/providers/house_provider.dart';
import '../../features/items/view/add_edit_item_screen.dart';
import '../../features/items/view/add_items_sheet.dart';
import '../../features/tour/tour_keys.dart';
import '../constants/app_constants.dart';
import '../helpers/snack_bar_helper.dart';
import '../theme/app_spacing.dart';
import 'primary_action_button.dart';

/// Effetto vetro della barra (sfocatura dello sfondo). Se sul telefono la
/// sfocatura fa scattare lo scorrimento, metti `false`: la barra torna a una
/// superficie tonale piena.
const bool _kGlassNavBar = true;

/// Shell principale: barra flottante con due luoghi (Case, Viaggi) e, staccato,
/// il bottone d'azione della tab corrente.
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  static const _housesBranch = 0;
  static const _tripsBranch = 1;

  void _goBranch(int index) =>
      navigationShell.goBranch(index, initialLocation: false);

  Future<void> _onAddItems(
    BuildContext context,
    WidgetRef ref, {
    required bool hasHouses,
  }) async {
    final analytics = ref.read(coreAnalyticsServiceProvider);
    analytics.trackPrimaryActionTapped(
      tab: 'houses',
      action: 'add_items',
      enabled: hasHouses,
    );
    if (!hasHouses) {
      AppSnackBar.showWarning(context, 'navigation.create_house_first'.tr());
      return;
    }
    final choice = await showAddItemsSheet(context);
    if (choice == null || !context.mounted) return;
    switch (choice.method) {
      case AddItemsMethod.aiScan:
        analytics.trackAddItemsSheetChoice(choice: 'ai_scan');
        context.push('/houses/${choice.houseId}/ai-import');
      case AddItemsMethod.manual:
        analytics.trackAddItemsSheetChoice(choice: 'manual');
        await showAddEditItemSheet(context, houseId: choice.houseId);
    }
  }

  void _onNewTrip(BuildContext context, WidgetRef ref) {
    ref
        .read(coreAnalyticsServiceProvider)
        .trackPrimaryActionTapped(tab: 'trips', action: 'new_trip', enabled: true);
    context.push('/new-trip');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentIndex = navigationShell.currentIndex;
    final houses = ref.watch(houseNotifierProvider).valueOrNull;
    // Durante il caricamento il bottone resta acceso: spegnerlo per un frame
    // farebbe lampeggiare il colore a ogni avvio.
    final hasHouses = houses == null || houses.isNotEmpty;
    final onHouses = currentIndex == _housesBranch;

    final barHeight = context.responsive(56.0);
    final radius = context.responsiveBorderRadius(AppConstants.pillBorderRadius);

    Widget bar = Container(
      height: barHeight,
      decoration: BoxDecoration(
        color: _kGlassNavBar
            ? colorScheme.surfaceContainer.withValues(alpha: 0.78)
            : colorScheme.surfaceContainer,
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _NavItem(
              key: const Key('nav_houses'),
              anchorKey: tourKeys.housesTab,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'navigation.houses'.tr(),
              isSelected: onHouses,
              onTap: () => _goBranch(_housesBranch),
            ),
          ),
          Expanded(
            child: _NavItem(
              key: const Key('nav_trips'),
              anchorKey: tourKeys.tripsTab,
              icon: Icons.luggage_outlined,
              selectedIcon: Icons.luggage,
              label: 'navigation.trips'.tr(),
              isSelected: !onHouses,
              onTap: () => _goBranch(_tripsBranch),
            ),
          ),
        ],
      ),
    );
    if (_kGlassNavBar) {
      bar = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: bar,
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Anchor invisibile per gli step info-card del tour (nessun spotlight)
          Center(
            child: SizedBox(key: tourKeys.infoCardTarget, width: 1, height: 1),
          ),
          navigationShell,
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.spacingMd,
            0,
            context.spacingMd,
            context.spacingMd,
          ),
          child: Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: bar,
                ),
              ),
              SizedBox(width: context.spacingSm),
              PrimaryActionButton(
                key: const Key('primary_action_button'),
                icon: onHouses ? Icons.add : Icons.luggage,
                label: onHouses
                    ? 'navigation.add_items'.tr()
                    : 'navigation.new_trip'.tr(),
                enabled: !onHouses || hasHouses,
                onPressed: onHouses
                    ? () => _onAddItems(context, ref, hasHouses: hasHouses)
                    : () => _onNewTrip(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final GlobalKey anchorKey;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.anchorKey,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return InkWell(
      key: anchorKey,
      onTap: onTap,
      borderRadius: context.responsiveBorderRadius(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isSelected ? selectedIcon : icon, size: context.responsive(22), color: color),
          SizedBox(height: context.spacingXs / 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
```

Il bottone d'azione deve portare anche `tourKeys.houseFab` (usata dal tour fino al Task 7): avvolgi `PrimaryActionButton` in `KeyedSubtree(key: tourKeys.houseFab, child: PrimaryActionButton(...))`. Controlla con `grep -rn "houseFab\|profileTab" lib test` che nessun altro file usi `tourKeys.profileTab` (ora inutilizzata: la elimina il Task 7).

- [ ] **Step 8: Test della shell** — `test/shared/widgets/main_shell_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/items/view/add_items_sheet.dart';
import 'package:pack_log/shared/widgets/main_shell.dart';

class _MockAnalytics extends Mock implements AppAnalyticsService {}

class _FakeHouseNotifier extends HouseNotifier {
  _FakeHouseNotifier(this.houses);
  final List<HouseModel> houses;
  @override
  Future<List<HouseModel>> build() async => houses;
}

HouseModel _house(String id) => HouseModel(
  id: id,
  name: 'Casa $id',
  isPrimary: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late _MockAnalytics analytics;

  setUp(() {
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  GoRouter buildRouter() => GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const Text('HOUSES'))],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/trips', builder: (_, _) => const Text('TRIPS')),
            ],
          ),
        ],
      ),
      GoRoute(path: '/new-trip', builder: (_, _) => const Text('NEW TRIP')),
    ],
  );

  Future<void> pumpShell(WidgetTester tester, List<HouseModel> houses) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('it', 'IT')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        saveLocale: false,
        child: ProviderScope(
          overrides: [
            analyticsServiceProvider.overrideWithValue(analytics),
            houseNotifierProvider.overrideWith(() => _FakeHouseNotifier(houses)),
          ],
          child: MaterialApp.router(routerConfig: buildRouter()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settleLabel(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  testWidgets('la barra ha solo Case e Viaggi', (tester) async {
    await pumpShell(tester, [_house('a')]);
    expect(find.byKey(const Key('nav_houses')), findsOneWidget);
    expect(find.byKey(const Key('nav_trips')), findsOneWidget);
    expect(find.byIcon(Icons.person_3_outlined), findsNothing);
    await settleLabel(tester);
  });

  testWidgets('in Case il bottone apre il foglio Aggiungi oggetti', (tester) async {
    await pumpShell(tester, [_house('a')]);
    await tester.tap(find.byKey(const Key('primary_action_button')));
    await tester.pumpAndSettle();
    expect(find.byType(AddItemsSheet), findsOneWidget);
    verify(
      () => analytics.logEvent(
        'primary_action_tapped',
        properties: {'tab': 'houses', 'action': 'add_items', 'enabled': true},
      ),
    ).called(1);
    await settleLabel(tester);
  });

  testWidgets('senza case il bottone è spento e mostra un avviso', (tester) async {
    await pumpShell(tester, const []);
    await tester.tap(find.byKey(const Key('primary_action_button')));
    await tester.pump();
    expect(find.byType(AddItemsSheet), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    await settleLabel(tester);
  });

  testWidgets('in Viaggi il bottone apre Nuovo viaggio', (tester) async {
    await pumpShell(tester, [_house('a')]);
    await tester.tap(find.byKey(const Key('nav_trips')));
    await tester.pumpAndSettle();
    expect(find.text('TRIPS'), findsOneWidget);

    await tester.tap(find.byKey(const Key('primary_action_button')));
    await tester.pumpAndSettle();
    expect(find.text('NEW TRIP'), findsOneWidget);
    await settleLabel(tester);
  });
}
```

Se `AppSnackBar.showWarning` richiede uno `ScaffoldMessenger` diverso da quello del `MaterialApp.router`, il test lo rivela: in quel caso adatta il test, non l'helper.

- [ ] **Step 9: Verifica**

Run: `dart analyze && flutter test test/shared/ test/core/ test/features/profile/ test/features/tour/`
Expected: nessun issue, test verdi. Se `tour_orchestrator_test` usa ancora chiavi esistenti, passa: lo aggiorna il Task 7.

- [ ] **Step 10: Commit**

```bash
git add lib/shared/widgets/primary_action_button.dart lib/shared/widgets/main_shell.dart lib/core/routing/app_router.dart lib/features/profile/view/profile_screen.dart test/shared/widgets/
git commit -m "feat(shell): barra con Case e Viaggi, bottone d'azione contestuale, profilo fuori dalla barra"
```

---

### Task 7: Tour guidato sui nuovi bersagli

**Files:**
- Modify: `lib/features/tour/tour_keys.dart`
- Modify: `lib/features/tour/controllers/tour_orchestrator.dart` (`_showTooltip` ~righe 99-175, `_stepConfig` ~righe 177-200)
- Modify: `lib/shared/widgets/main_shell.dart` (chiave rinominata)
- Modify: `lib/features/houses/view/house_detail_screen.dart:253` (solo commento)
- Modify: traduzioni `tour.house_tooltip.body`, `tour.create_trip_tooltip.body`
- Test: `test/features/tour/controllers/tour_orchestrator_test.dart`

**Interfaces:**
- Consumes: `tourKeys.newHouseRow` (Task 4), `tourKeys.tripsTab` (Task 6).
- Produces: `tourKeys.primaryAction` (rinomina di `houseFab`); `profileTab` eliminata.

- [ ] **Step 1: Chiavi** — in `tour_keys.dart`: elimina `profileTab`; rinomina `houseFab` in `primaryAction` con doc-comment «Bottone d'azione della shell (Aggiungi oggetti / Nuovo viaggio).». Aggiorna i riferimenti: `grep -rn "houseFab" lib test` → `primaryAction` (in `main_shell.dart` il `KeyedSubtree`, nel commento di `house_detail_screen.dart:253` e nel commento di `tour_orchestrator.dart:47`).

- [ ] **Step 2: Bersagli** — in `_stepConfig`:
  - `houseTooltip` → `key: tourKeys.newHouseRow`
  - `createTripTooltip` → `key: tourKeys.tripsTab`

- [ ] **Step 3: Bersaglio visibile e passaggio a Viaggi** — in `_showTooltip`:
  1. Prima di creare `TutorialCoachMark`, porta in vista il bersaglio (la riga Nuova casa sta in fondo alla lista):
     ```dart
     final cfg = _stepConfig(onboarding.step);
     final targetContext = cfg.key.currentContext;
     if (targetContext != null) {
       await Scrollable.ensureVisible(
         targetContext,
         alignment: 0.5,
         duration: const Duration(milliseconds: 200),
       );
       if (!context.mounted) return;
     }
     ```
     Rendi `_showTooltip` `Future<void> ... async`; il chiamante nel `Future.delayed` resta invariato.
  2. Cattura il router prima del gap asincrono: `final router = GoRouter.maybeOf(context);` (import `package:go_router/go_router.dart`).
  3. Nella funzione locale `advance()`, dopo `notifier.advance();`:
     ```dart
     // Il tip "Crea il tuo primo viaggio" punta alla tab Viaggi: avanzare
     // (Avanti o tocco sul bersaglio) porta lì, dove c'è il bottone.
     if (onboarding.step == OnboardingStep.createTripTooltip) {
       router?.go('/trips');
     }
     ```
     Il bottone Avanti di uno step spotlight passa già da `advance()` (vedi `onNext`); verifica che anche `onClickTarget` lo chiami.

- [ ] **Step 4: Testi** —
  - it-IT `tour.house_tooltip.body`: `"Tocca «Nuova casa» in fondo all'elenco per aggiungere la tua prima casa."`
  - it-IT `tour.create_trip_tooltip.body`: `"Apri Viaggi e tocca + per creare il tuo primo viaggio."`
  - en-US `tour.house_tooltip.body`: `"Tap \"New house\" at the bottom of the list to add your first house."`
  - en-US `tour.create_trip_tooltip.body`: `"Open Trips and tap + to create your first trip."`

- [ ] **Step 5: Test** — in `tour_orchestrator_test.dart`, `shellScreen()` espone ora tutti i bersagli dei tip della shell:

```dart
  Widget shellScreen() => Scaffold(
    body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(key: tourKeys.newHouseRow, width: 48, height: 48),
        SizedBox(key: tourKeys.tripsTab, width: 48, height: 48),
        SizedBox(key: tourKeys.primaryAction, width: 48, height: 48),
      ],
    ),
  );
```

Sostituisci ogni altro `tourKeys.houseFab` nel file. Esegui `grep -rn "houseFab\|profileTab" lib test`: deve restituire zero righe.

- [ ] **Step 6: Verifica**

Run: `dart analyze && flutter test test/features/tour/`
Expected: nessun issue, test verdi.

- [ ] **Step 7: Commit**

```bash
git add lib/features/tour/ lib/shared/widgets/main_shell.dart lib/features/houses/view/house_detail_screen.dart assets/translations/ test/features/tour/
git commit -m "feat(tour): i tip puntano alla riga Nuova casa e alla tab Viaggi"
```

---

### Task 8: Screenshot, documentazione e verifica completa

**Files:**
- Modify: `test/screenshots/ui_screenshots_test.dart` (helper ~riga 75, scenari ~righe 313-331, ~righe 482-492, scenari profilo ~righe 860-930)
- Modify: `CLAUDE.md` (sezione Navigazione, riga "Branch mapping attuale") — file locale, non in git

- [ ] **Step 1: Harness** — in `ui_screenshots_test.dart`:
  1. Sostituisci `_openCreateMenu` con:
     ```dart
     Future<void> _openAddItemsSheet(ScreenshotApp app) async {
       await app.go('/');
       await app.tap(find.byKey(const Key('primary_action_button')));
     }
     ```
  2. Scenario 03-case n. 5: `'shell', 'menu-crea'` → `'aggiungi-oggetti', 'foglio'`, `source: 'lib/features/items/view/add_items_sheet.dart'`, `description: 'Bottone d\'azione in Case: casa di destinazione, Scansiona con AI, Scrivi a mano.'`, `steps: _openAddItemsSheet`.
  3. Scenario 03-case n. 6 (`casa-form nuova`): `description: 'Bottom sheet nuova casa (dalla riga in fondo alla lista).'`, steps:
     ```dart
     steps: (app) async {
       await app.go('/');
       await app.tap(find.text('houses.new_house_row'.tr()));
     },
     ```
  4. Scenario 05-oggetti n. 1: `description: 'Nuovo oggetto da Aggiungi oggetti → Scrivi a mano.'`, steps:
     ```dart
     steps: (app) async {
       await _openAddItemsSheet(app);
       await app.tap(find.byKey(const Key('add_items_manual')));
     },
     ```
  5. Scenari del profilo: ogni `app.go('/profile')` diventa `await app.go('/'); await app.push('/profile');` (con `steps: (app) async { ... }` dove serve).
  6. Aggiungi `import 'package:flutter/material.dart';` se `Key` non è già disponibile (lo è, il file importa material).

- [ ] **Step 2: Genera gli screenshot**

Run: `flutter test test/screenshots --dart-define=UI_SCREENSHOTS=true`
Expected: PASS; in `build/ui-screenshots/manifest.json` nessuno scenario con `issues` non vuoti. Guarda a mano `03-case/*-light.png`, `07-viaggi/*-light.png`, `10-profilo/01-*-light.png`: barra a due voci, bottone staccato, avatar in alto a destra, riga tratteggiata.

- [ ] **Step 3: CLAUDE.md** — sostituisci `Branch mapping attuale: 0=\`/profile\`, 1=\`/\`, 2=\`/trips\`.` con:

```
Branch mapping attuale: 0=`/` (Case), 1=`/trips` (Viaggi). Il Profilo (`/profile`) è una route sul navigator radice, aperta con `push` dall'avatar in alto a destra.
```

- [ ] **Step 4: Verifica completa**

Run: `dart format lib/ test/ && dart analyze && flutter test`
Expected: format senza modifiche residue, analyze pulito, suite completa verde (oggi ~848 test + quelli nuovi).

- [ ] **Step 5: Commit**

```bash
git add test/screenshots/ui_screenshots_test.dart
git commit -m "test(screenshots): scenari per bottone d'azione, riga Nuova casa e profilo da avatar"
```

(`CLAUDE.md` è in `.gitignore`: si modifica ma non si committa.)

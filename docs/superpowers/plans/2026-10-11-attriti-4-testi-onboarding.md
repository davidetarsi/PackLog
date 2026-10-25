# Attriti UI 4 · Testi e onboarding — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chiudere gli attriti #4, #6 e #11 di `docs/ui-flows.md`: un bottone "Salta" nell'onboarding, il testo sotto la destinazione del viaggio che cambia con la scelta (Casa / Altra località), e niente più stringhe scritte nel codice o in inglese nella UI italiana. Alla fine, segnare gli attriti risolti in `docs/ui-flows.md`.

**Architecture:** Tre interventi locali di UI e traduzioni. "Salta" riusa il completamento esistente (`onboardingStatusProvider.markCompleted()`): il redirect del router porta già al login quando l'onboarding risulta completato. Il testo della destinazione sceglie fra due chiavi di traduzione in base allo stato `_useHouseDestination` che il form ha già. Nessun cambio di provider, repository o schema.

**Tech Stack:** Flutter 3.38.5, Riverpod 2.5, easy_localization, shared_preferences.

**Decisioni prese (conversazione del 2026-10-11):**
- #4: "Salta" in alto a destra sulle prime due slide, nascosto sull'ultima (dove c'è già "Inizia"). Fa quello che fa "Inizia": segna l'onboarding come completato e il router porta al login.
- #6: con **Casa** selezionata resta il testo attuale; con **Altra località** il testo diventa un invito a scegliere Casa.
- #13 è stato spostato nel piano 3 (stesso file dei token di #10).

**Testi approvati dall'utente il 2026-10-11** ("Toiletries" resta in inglese anche in italiano, per scelta):

| Chiave | it-IT | en-US |
|---|---|---|
| `onboarding.skip` (nuova) | Salta | Skip |
| `onboarding.complete_failed` (nuova) | Non è stato possibile salvare. Riprova. | Couldn't save. Please try again. |
| `trips.destination_house_hint` (nuova) | Vai in una delle tue case? Scegli «Casa»: gli oggetti che porti compariranno lì come temporanei. | Going to one of your homes? Choose “House”: the things you pack will show up there as temporary. |
| `app_name` (era "Stuff Tracker") | Pack Log | Pack Log |
| `ai_import.title` (era "AI Scan") | Scansione AI | AI Scan |
| `spaces.default` (era "Default") | Senza spazio | No space |

**Prerequisito:** `build/ui-screenshots-before/` presente (Task 1 del piano 1). Per il resto il piano è indipendente dagli altri.

## Global Constraints

- Branch di lavoro: `fix/ui-frictions`, **senza upstream**: non fare `git push` senza indicare remoto e branch.
- Flutter **3.38.5**. Niente `git worktree add`.
- Testi UI **solo** via `.tr()`, con la chiave in `it-IT.json` **e** `en-US.json`. Le traduzioni si modificano con lo script Python indicato (il round-trip `json.dumps(indent=2, ensure_ascii=False)` + newline è identico byte per byte ai file attuali).
- I test dei widget non asseriscono su testo tradotto: senza `EasyLocalization` `.tr()` restituisce la chiave. Si cerca per `Key`, tipo o icona.
- Analytics solo via i servizi esistenti (`coreAnalyticsServiceProvider`, `analyticsServiceProvider.logEvent`), solo `userId` e proprietà non personali.
- Prima di ogni commit: `dart format lib/ test/`, `dart analyze` pulito, test toccati verdi. Commit appena è verde, messaggi conventional in italiano chiusi da `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Structure

**Creati**

| File | Responsabilità |
|---|---|
| `test/features/onboarding/view/onboarding_screen_test.dart` | "Salta" visibile solo prima dell'ultima slide; completa l'onboarding |
| `test/features/trips/view/trip_info_form_destination_hint_test.dart` | Il testo sotto la destinazione segue la pill selezionata |

**Modificati**

| File | Cosa cambia |
|---|---|
| `lib/features/onboarding/view/onboarding_screen.dart` | Bottone "Salta"; messaggio d'errore tradotto |
| `lib/features/trips/view/trip_info_form.dart:395-404` | Testo contestuale sotto la destinazione |
| `lib/features/auth/view/login_screen.dart:175` | `'Pack Log'` → `'app_name'.tr()` |
| `lib/features/items/widgets/category_pill.dart` (`_labelForCategory`) | Lettera derivata dal nome tradotto della categoria |
| `assets/translations/it-IT.json`, `en-US.json` | Chiavi della tabella sopra |
| `docs/ui-flows.md` | Attriti risolti segnati come tali (Task 5, dopo tutti i piani) |

---

### Task 1: "Salta" nell'onboarding (#4) e messaggio d'errore tradotto (#11 parte)

**Files:**
- Modify: `lib/features/onboarding/view/onboarding_screen.dart`
- Modify: `assets/translations/it-IT.json`, `en-US.json` (`onboarding.skip`, `onboarding.complete_failed`)
- Test: `test/features/onboarding/view/onboarding_screen_test.dart`

**Interfaces:**
- Consumes: `onboardingStatusProvider.notifier.markCompleted()`, `coreAnalyticsServiceProvider.trackOnboardingCompleted()`, `analyticsServiceProvider.logEvent(String, {Map<String, dynamic>? properties})`.
- Produces: bottone con `Key('onboarding_skip')`.

- [ ] **Step 1: Chiavi di traduzione**

```bash
python3 - <<'EOF'
import json
vals = {
    "it-IT": {"skip": "Salta", "complete_failed": "Non è stato possibile salvare. Riprova."},
    "en-US": {"skip": "Skip", "complete_failed": "Couldn't save. Please try again."},
}
for f, v in vals.items():
    p = f"assets/translations/{f}.json"
    d = json.load(open(p, encoding="utf-8"))
    d["onboarding"].update(v)
    open(p, "w", encoding="utf-8").write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
EOF
```

- [ ] **Step 2: Scrivere il test che fallisce**

`test/features/onboarding/view/onboarding_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/features/onboarding/view/onboarding_screen.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';

void main() {
  // AppAnalyticsService senza backend: logEvent è un no-op sicuro
  // (stesso approccio di login_screen_test.dart).
  Widget wrap() => ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(AppAnalyticsService(null)),
    ],
    child: const MaterialApp(home: OnboardingScreen()),
  );

  const skip = Key('onboarding_skip');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Salta completa l\'onboarding dalla prima slide', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(skip).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(skip));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isTrue);
  });

  testWidgets('sull\'ultima slide Salta non c\'è', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Due "Avanti" portano alla terza e ultima slide.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byType(DsButton));
      await tester.pumpAndSettle();
    }

    expect(find.byKey(skip).hitTestable(), findsNothing);
  });
}
```

- [ ] **Step 3: Eseguirlo e vederlo fallire**

Run: `flutter test test/features/onboarding/view/onboarding_screen_test.dart`
Expected: il primo test FAIL (nessun widget con `Key('onboarding_skip')`). Il secondo passa già: va bene, è il caso negativo.

Se il test fallisce per altri motivi (es. `ContentSlide` che prova ad aprire il video), guardare come lo gestisce l'harness in `test/screenshots/support/harness.dart` e replicare lo stesso accorgimento qui prima di proseguire.

- [ ] **Step 4: Implementare "Salta"**

In `_OnboardingScreenState`, sostituire `_handleComplete()` con:
```dart
  /// Segna l'onboarding come completato. Il router, vedendolo completato,
  /// porta al login: vale sia per "Inizia" sia per "Salta".
  Future<void> _handleComplete({bool skipped = false}) async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      if (skipped) {
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              'onboarding_skipped',
              properties: {'page_index': _currentPage},
            );
      } else {
        ref.read(coreAnalyticsServiceProvider).trackOnboardingCompleted();
      }
      await ref.read(onboardingStatusProvider.notifier).markCompleted();
      if (mounted && ref.read(onboardingStatusProvider) is AsyncError) {
        AppSnackBar.showError(context, 'onboarding.complete_failed'.tr());
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }
```

Nel `build`, come primo figlio della `Column` (prima del primo `const Spacer()`):
```dart
            // "Salta" sulle prime slide; sull'ultima c'è già "Inizia".
            // maintainSize: l'altezza non cambia fra le slide, quindi il
            // contenuto non salta quando il bottone sparisce.
            Align(
              alignment: Alignment.centerRight,
              child: Visibility(
                visible: !_isLastPage,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Padding(
                  padding: EdgeInsets.only(right: context.spacingSm),
                  child: TextButton(
                    key: const Key('onboarding_skip'),
                    onPressed: _isCompleting
                        ? null
                        : () => _handleComplete(skipped: true),
                    child: Text('onboarding.skip'.tr()),
                  ),
                ),
              ),
            ),
```

- [ ] **Step 5: Eseguire il test e vederlo passare**

Run: `flutter test test/features/onboarding/`
Expected: `All tests passed!` (anche `onboarding_status_provider_test.dart`).

Run: `grep -n "'[A-Z][a-z]*\. Riprova" lib -r`
Expected: nessun risultato.

- [ ] **Step 6: Commit**

```bash
dart format lib/ test/ && dart analyze
git add lib/features/onboarding/view/onboarding_screen.dart test/features/onboarding/view/onboarding_screen_test.dart assets/translations
git commit -m "feat: bottone Salta nell'onboarding

In alto a destra sulle prime due slide: completa l'onboarding come
\"Inizia\" e registra onboarding_skipped con la slide di partenza.
Il messaggio d'errore del completamento ora è tradotto.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Testo sotto la destinazione che segue la scelta (#6)

**Files:**
- Modify: `lib/features/trips/view/trip_info_form.dart` (il `Text('trips.destination_benefit'.tr(), …)` dopo la `Card` della destinazione)
- Modify: `assets/translations/it-IT.json`, `en-US.json` (`trips.destination_house_hint`)
- Test: `test/features/trips/view/trip_info_form_destination_hint_test.dart`

**Interfaces:**
- Produces: due `Key`: `destination_hint_house` (Casa selezionata) e `destination_hint_other` (Altra località).

- [ ] **Step 1: Chiave di traduzione**

```bash
python3 - <<'EOF'
import json
vals = {
    "it-IT": "Vai in una delle tue case? Scegli «Casa»: gli oggetti che porti compariranno lì come temporanei.",
    "en-US": "Going to one of your homes? Choose “House”: the things you pack will show up there as temporary.",
}
for f, v in vals.items():
    p = f"assets/translations/{f}.json"
    d = json.load(open(p, encoding="utf-8"))
    d["trips"]["destination_house_hint"] = v
    open(p, "w", encoding="utf-8").write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
EOF
```

Il nome dell'opzione nel testo ("Casa" / "House") deve restare uguale all'etichetta della pill (`common.destination_house`): se una delle due cambia, cambiare anche l'altra.

- [ ] **Step 2: Scrivere il test che fallisce**

`test/features/trips/view/trip_info_form_destination_hint_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/trips/view/trip_info_form.dart';

/// Nessuna casa: basta a far rispondere subito il ramo "Casa" del form,
/// senza database.
class _NoHouses extends HouseNotifier {
  @override
  Future<List<HouseModel>> build() async => const [];
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [houseNotifierProvider.overrideWith(_NoHouses.new)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TripInfoForm(
              onChanged:
                  ({
                    description,
                    departureDateTime,
                    returnDateTime,
                    destinationHouseId,
                    destinationLocation,
                    destinationName,
                    name,
                  }) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('con Altra località il testo invita a scegliere Casa', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(const Key('destination_hint_other')), findsOneWidget);
    expect(find.byKey(const Key('destination_hint_house')), findsNothing);
  });

  testWidgets('con Casa il testo spiega cosa succede agli oggetti', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('destination_hint_house')), findsOneWidget);
    expect(find.byKey(const Key('destination_hint_other')), findsNothing);
  });
}
```

`onChanged` è l'unico parametro obbligatorio di `TripInfoForm`.

- [ ] **Step 3: Eseguirlo e vederlo fallire**

Run: `flutter test test/features/trips/view/trip_info_form_destination_hint_test.dart`
Expected: FAIL, nessun widget con `Key('destination_hint_other')`.

- [ ] **Step 4: Testo contestuale**

In `lib/features/trips/view/trip_info_form.dart` sostituire
```dart
        SizedBox(height: context.spacingXs),
        // Sempre visibile, non dentro un errore: non è un errore, e un errore
        // si vede solo quando le cose vanno male.
        Text(
          'trips.destination_benefit'.tr(),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
```
con
```dart
        SizedBox(height: context.spacingXs),
        // Sempre visibile, non dentro un errore: non è un errore, e un errore
        // si vede solo quando le cose vanno male. Cambia con la pill: con
        // "Casa" spiega cosa succede agli oggetti; con "Altra località"
        // invita a scegliere Casa, invece di descrivere un campo che non è
        // quello sopra.
        Text(
          _useHouseDestination
              ? 'trips.destination_benefit'.tr()
              : 'trips.destination_house_hint'.tr(),
          key: Key(
            _useHouseDestination
                ? 'destination_hint_house'
                : 'destination_hint_other',
          ),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
```

- [ ] **Step 5: Eseguire il test e vederlo passare**

Run: `flutter test test/features/trips/view/`
Expected: `All tests passed!` (anche `trip_info_form_name_test.dart`).

- [ ] **Step 6: Commit**

```bash
dart format lib/ test/ && dart analyze
git add lib/features/trips/view/trip_info_form.dart test/features/trips/view/trip_info_form_destination_hint_test.dart assets/translations
git commit -m "fix: il testo sotto la destinazione segue la pill scelta

Con Altra località descriveva la casa di destinazione, e si leggeva
come la spiegazione del campo sopra. Ora con Altra località invita a
scegliere Casa; con Casa spiega cosa succede agli oggetti.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Niente stringhe scritte nel codice né in inglese nella UI italiana (#11)

**Files:**
- Modify: `lib/features/auth/view/login_screen.dart:175`
- Modify: `lib/features/items/widgets/category_pill.dart` (`_labelForCategory`)
- Modify: `assets/translations/it-IT.json`, `en-US.json` (`app_name`, `ai_import.title`, `spaces.default`)
- Test: `test/features/auth/view/login_screen_test.dart` (esistente, deve restare verde)

- [ ] **Step 1: Valori delle traduzioni**

```bash
python3 - <<'EOF'
import json
vals = {
    "it-IT": {("app_name",): "Pack Log", ("ai_import", "title"): "Scansione AI",
              ("spaces", "default"): "Senza spazio"},
    "en-US": {("app_name",): "Pack Log", ("ai_import", "title"): "AI Scan",
              ("spaces", "default"): "No space"},
}
for f, v in vals.items():
    p = f"assets/translations/{f}.json"
    d = json.load(open(p, encoding="utf-8"))
    for path, value in v.items():
        node = d
        for k in path[:-1]:
            node = node[k]
        assert path[-1] in node, path
        node[path[-1]] = value
    open(p, "w", encoding="utf-8").write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
EOF
git diff --stat assets/translations
```

Expected: solo righe modificate, nessuna aggiunta né rimossa.

`spaces.default` è solo un'etichetta: lo spazio predefinito non è un record con quel nome, sono gli oggetti con `spaceId == null` (`house_detail_screen.dart:689`). Cambiarla non tocca i dati.

- [ ] **Step 2: Nome dell'app nel login**

In `lib/features/auth/view/login_screen.dart`, alla riga 175:
```dart
                Text(
                  'app_name'.tr(),
```
al posto di `'Pack Log',`.

Run: `grep -rn "'Pack Log'\|\"Pack Log\"" lib | grep "\.dart:"`
Expected: nessun risultato.

- [ ] **Step 3: Lettera della categoria dal nome tradotto**

Le pill dell'input rapido mostrano l'iniziale della categoria, oggi scritta a mano in italiano (`'V'`, `'T'`, `'E'`, `'?'`): in inglese "V" non è l'iniziale di "Clothes". Derivandola dal nome tradotto, in italiano restano V, T, E e in inglese diventano C, T, E. In `lib/features/items/widgets/category_pill.dart` sostituire il corpo di `_labelForCategory` con:
```dart
  static String _labelForCategory(ItemCategory category) {
    // "Varie" resta un punto interrogativo: è la categoria "non so".
    if (category == ItemCategory.varie) return '?';
    return category.displayName.characters.first.toUpperCase();
  }
```

`displayName` viene da `ItemCategoryExtension` in `item_model.dart` (già importato dal file).

- [ ] **Step 4: Analizzare, testare, committare**

```bash
dart format lib/ test/
dart analyze
flutter test test/features/auth/ test/features/items/
git add lib/features/auth/view/login_screen.dart lib/features/items/widgets/category_pill.dart assets/translations
git commit -m "fix: niente testi scritti nel codice o in inglese nella UI italiana

Il nome dell'app nel login viene da app_name (era \"Stuff Tracker\"),
e in italiano: Scansione AI, Senza spazio. Le iniziali delle categorie
nell'input rapido derivano dal nome tradotto.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Verifica con gli screenshot

- [ ] **Step 1: Test completi**

```bash
dart format lib/ test/
dart analyze
flutter test
```
Expected: analyze pulito, tutti i test verdi.

- [ ] **Step 2: Screenshot "dopo" e confronto**

```bash
flutter test test/screenshots --dart-define=UI_SCREENSHOTS=true
```

Confrontare con `build/ui-screenshots-before/`:
- `01-primo-avvio/01-*` e `02-*`: "Salta" in alto a destra. `03-*`: non c'è, e il contenuto è alla stessa altezza delle slide precedenti.
- `01-primo-avvio/04-*`, `05-*`, `06-*`: titolo "Pack Log" invariato a video (ora viene da `app_name`).
- `08-nuovo-viaggio/01-nuovo-viaggio-passo1-vuoto-*`: sotto la destinazione "Vai in una delle tue case? Scegli «Casa»…". `03-nuovo-viaggio-destinazione-casa-*`: il testo originale sugli oggetti temporanei.
- `04-dettaglio-casa/01-*`: chip "Senza spazio (8)" al posto di "Default (8)"; "Toiletries" invariato.
- `04-dettaglio-casa/04-dettaglio-casa-rapid-fire-*`: iniziali V, T, E, ? (invariate in italiano).
- `06-import-ai/*`: titolo "Scansione AI".

---

### Task 5: Segnare gli attriti risolti in `docs/ui-flows.md`

Da eseguire **dopo** che tutti e quattro i piani sono chiusi.

**Files:**
- Modify: `docs/ui-flows.md` (sezione "Attriti UX e incoerenze visive")

- [ ] **Step 1: Annotare ogni attrito**

In fondo a ciascun punto numerato aggiungere una riga di stato, con l'hash corto del commit che lo chiude (`git log --oneline` sul branch):
- #1-#13, #15, #16: `**Risolto** in <hash>.` Per #11 aggiungere: `"Toiletries" resta in inglese per scelta (2026-10-11).`
- #14: `**Non si fa** (2026-10-11): il contenuto sotto la barra è voluto, niente sfumatura.`

Aggiornare anche le tabelle dei flussi dove le schermate sono cambiate:
- flusso 11 (creazione guidata): eliminare la sezione `### 11 · Creazione guidata da template`;
- nella nota finale "Non catturati in nessun flusso", togliere il riferimento alla rotta `/trips/:id/edit`.

- [ ] **Step 2: Commit**

`docs/` è in `.gitignore`: il file è tracciato perché aggiunto con `-f`, quindi `git add` serve con `-f`.

```bash
git add -f docs/ui-flows.md
git commit -m "docs: attriti UI risolti segnati in ui-flows.md

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

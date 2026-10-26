# Attriti UI 3 · Coerenza visiva e token — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chiudere gli attriti #8, #9, #10, #13, #15 e #16 di `docs/ui-flows.md`: contrasto del "Riprova" e colori di errore del tema, "Elimina account" non più l'elemento più evidente del profilo, selettore bagagli con le pill del design system, pill tab della stessa altezza ovunque, valori numerici riportati ai token e overflow dell'input rapido.

**Architecture:** Due correzioni stanno alla radice invece che nel singolo schermo: il tema dichiara `errorContainer`/`onErrorContainer` (oggi mancano, e Flutter ricade su `error`/`onError`, cioè rosso pieno), e la pill singola di `AppPillTab` diventa pubblica (`AppPill`) così la scelta multipla dei bagagli la riusa. Il resto è sostituzione di numeri fissi con token esistenti (`AppSpacing`, `context.spacing*`, `context.iconSize*`, `AppConstants`, `textTheme`). Nessun cambio di provider, repository o schema.

**Tech Stack:** Flutter 3.38.5, Riverpod 2.5, easy_localization.

**Decisioni prese (conversazione del 2026-10-11):**
- #14 (contenuto sotto la barra flottante): **non si fa**. Niente sfumatura: il comportamento è voluto (`navBarReservedHeight`).
- #15: "Esci" resta un bottone bordato a tutta larghezza; "Elimina il mio account" diventa un bottone testuale rosso, centrato, senza riempimento, con più spazio sopra.
- #16: "Riprova" prende il colore del testo del box d'errore (`onErrorContainer`), in grassetto e sottolineato.
- #13 è stato spostato qui dal piano 4: si corregge nello stesso file e nella stessa riga dei token di #10 (`rapid_fire_input.dart:174-185`).

**Prerequisiti:**
- Piano 1 eseguito: questo piano tocca `add_trip_screen.dart` e `trip_items_selector.dart` **dopo** che il piano 1 ne ha tolto il codice morto. I riferimenti a quei due file sono per nome di metodo, non per numero di riga.
- `build/ui-screenshots-before/` presente (Task 1 del piano 1).

## Global Constraints

- Branch di lavoro: `fix/ui-frictions`, **senza upstream**: non fare `git push` senza indicare remoto e branch.
- Flutter **3.38.5**. Niente `git worktree add`.
- Colori solo da `Theme.of(context).colorScheme` (o `context.appColors`); spacing da `context.spacing*`/`AppSpacing`; icone da `context.iconSize*`; raggi da `AppConstants`. Tipografia dal `textTheme` (è la fonte di verità, vedi `app_spacing.dart:20-30`).
- Testi UI **solo** via `.tr()`. Questo piano non aggiunge chiavi.
- I test dei widget non asseriscono su testo tradotto: si cerca per `Key`, tipo o icona.
- Prima di ogni commit: `dart format lib/ test/`, `dart analyze` pulito, test toccati verdi. Commit appena è verde, messaggi conventional in italiano chiusi da `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `ARCHITECTURE.md` e la skill `ui-design-system` si aggiornano solo per `AppPill` (nuovo componente pubblico) e per i colori d'errore del tema.

## File Structure

**Creati**

| File | Responsabilità |
|---|---|
| `test/shared/widgets/app_pill_test.dart` | `AppPill` chiama `onTap` e segna la selezione col bordo d'accento |
| `test/features/items/widgets/rapid_fire_input_test.dart` | Input espanso a 412 dp senza overflow |

**Modificati**

| File | Cosa cambia |
|---|---|
| `lib/shared/theme/app_theme.dart:57-58, 101-102` | `errorContainer` / `onErrorContainer` nei due temi |
| `test/shared/theme/app_theme_test.dart` | Gruppo sui colori d'errore |
| `lib/features/ai_input/view/ai_results_screen.dart` (box errore parziale) | "Riprova" in `onErrorContainer`, grassetto, sottolineato |
| `lib/features/profile/view/profile_screen.dart:378-395` | "Elimina il mio account" → bottone testuale rosso centrato |
| `lib/shared/widgets/app_pill_tab.dart` | `_RawPillTab` → `AppPill` pubblico |
| `lib/features/trips/view/add_trip_screen.dart` (`_buildLuggageSelector`) | `FilterChip` → `Wrap` di `AppPill` |
| `lib/features/houses/view/house_detail_screen.dart:738`, `lib/features/trips/view/trip_detail_screen.dart:113`, `lib/features/trips/view/trip_items_selector.dart` (`_buildFilters`) | Via `height: 40` |
| `lib/features/houses/view/houses_screen.dart:150-162, 210-256` | Raggio, icone e gap ai token |
| `lib/features/items/view/item_card.dart:45-80` | Icone e gap ai token |
| `lib/features/items/widgets/category_pill.dart:47-56` | Padding, icona, gap ai token |
| `lib/features/items/widgets/rapid_fire_input.dart:174-185, 310-322` | Token + riga categorie che non sfora |
| `lib/features/profile/widgets/sync_details_dialog.dart:62-65`, `lib/features/trips/view/trip_picker_sheet.dart:95-98` | `EdgeInsets.all(16)` → `context.spacingMd` |
| `lib/shared/widgets/main_shell.dart:411, 415` | `spacingSm + 2` e `responsiveFont(15)` ai token |
| `lib/shared/constants/app_constants.dart:4` | Esempio nel commento della regola sui raggi |
| `ARCHITECTURE.md`, `.claude/skills/ui-design-system/SKILL.md` | `AppPill`, colori d'errore |

---

### Task 1: Colori d'errore del tema e "Riprova" leggibile (#16)

**Files:**
- Modify: `lib/shared/theme/app_theme.dart:56-58` (light), `:100-102` (dark)
- Modify: `lib/features/ai_input/view/ai_results_screen.dart` (il `TextButton` "Riprova" nel box `colorScheme.errorContainer`, ~riga 665)
- Test: `test/shared/theme/app_theme_test.dart`

**Perché nel tema:** `ColorScheme.light()`/`.dark()` senza `errorContainer` lo fanno coincidere con `error`. Il box dell'errore parziale è quindi rosso pieno nel tema chiaro (testo bianco, "Riprova" arancione su rosso) e rosa nel tema scuro. Con i container d'errore dichiarati il box diventa un avviso tenue, e il testo ha un colore pensato per quello sfondo.

- [ ] **Step 1: Scrivere il test che fallisce**

In `test/shared/theme/app_theme_test.dart`, dentro `main()` in fondo, aggiungere:
```dart
  group('colori d\'errore', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final (hi, lo) = la > lb ? (la, lb) : (lb, la);
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final (name, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      test('$name: errorContainer è un avviso, non il rosso pieno', () {
        final cs = theme.colorScheme;
        expect(cs.errorContainer, isNot(cs.error));
        expect(cs.onErrorContainer, isNot(cs.onError));
      });

      test('$name: testo su errorContainer sopra AA (4.5:1)', () {
        final cs = theme.colorScheme;
        expect(
          contrast(cs.onErrorContainer, cs.errorContainer),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });
```

- [ ] **Step 2: Eseguirlo e vederlo fallire**

Run: `flutter test test/shared/theme/app_theme_test.dart`
Expected: FAIL su `light: errorContainer è un avviso…` e `dark: …` (oggi `errorContainer == error`).

- [ ] **Step 3: Dichiarare i container d'errore**

`lib/shared/theme/app_theme.dart`, tema chiaro, sotto `onError: Colors.white,`:
```dart
      // Container d'errore per avvisi (box di errore parziale): rosa tenue con
      // testo scuro. Senza, Flutter usa `error` pieno e il box diventa un
      // blocco rosso.
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF93000A),
```

Tema scuro, sotto `onError: Color(0xFF690005),`:
```dart
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
```

Sono i valori della palette d'errore baseline di Material 3, gli stessi da cui vengono `error`/`onError` già in uso.

- [ ] **Step 4: Eseguire il test e vederlo passare**

Run: `flutter test test/shared/theme/app_theme_test.dart`
Expected: `All tests passed!`.

- [ ] **Step 5: "Riprova" nel colore del box**

In `lib/features/ai_input/view/ai_results_screen.dart`, nel box dell'errore parziale, sostituire
```dart
                  TextButton(
                    onPressed: notifier.retryFailed,
                    child: Text('ai_import.retry'.tr()),
                  ),
```
con
```dart
                  TextButton(
                    key: const Key('ai_partial_error_retry'),
                    onPressed: notifier.retryFailed,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onErrorContainer,
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                    ),
                    child: Text('ai_import.retry'.tr()),
                  ),
```

- [ ] **Step 6: Analizzare, testare, committare**

```bash
dart format lib/ test/
dart analyze
flutter test test/shared/theme/ test/features/ai_input/
git add lib/shared/theme/app_theme.dart test/shared/theme/app_theme_test.dart lib/features/ai_input/view/ai_results_screen.dart
git commit -m "fix: box di errore tenue e Riprova leggibile

Il tema non dichiarava errorContainer: Flutter usava error pieno, e
\"Riprova\" era arancione su rosso. Ora il box è un avviso tenue e
Riprova usa onErrorContainer, in grassetto e sottolineato.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: "Elimina il mio account" non è più l'elemento più evidente (#15)

**Files:**
- Modify: `lib/features/profile/view/profile_screen.dart:378-395`

Non c'è un test di widget per `ProfileScreen` (dipende da auth, sync, analytics e preferenze). La verifica è lo screenshot `10-profilo/02-profilo-fine-pagina-*` e lo scenario `10-profilo/06-elimina-account-dialog-*`, che tocca il bottone per testo (`profile.delete_account_cta`) e deve continuare ad aprire il dialog.

- [ ] **Step 1: Sostituire il secondo `UniversalActionBar`**

Sostituire il blocco da `AppSpacing.gapSm,` (subito dopo il `Padding` di "Esci") fino alla fine della lista dei figli:
```dart
            AppSpacing.gapSm,

            // Cancellazione definitiva dell'account. Distruttivo e irreversibile,
            // protetto da dialog con conferma email.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
              child: UniversalActionBar(
                primaryLabel: 'profile.delete_account_cta'.tr(),
                primaryIcon: Icons.delete_forever,
                onPrimaryPressed: () => _handleDeleteAccount(context),
                isDestructive: true,
              ),
            ),

            // Gap sotto l'ultimo bottone = gap tra i due bottoni, per coerenza.
            AppSpacing.gapSm,
```
con
```dart
            AppSpacing.gapLg,

            // Cancellazione definitiva dell'account. Distruttivo e irreversibile:
            // si trova, ma non è un bottone pieno e non sta attaccato a "Esci",
            // così non è l'elemento più evidente della pagina. Protetto da
            // dialog con conferma email.
            Center(
              child: TextButton.icon(
                key: const Key('profile_delete_account'),
                onPressed: () => _handleDeleteAccount(context),
                icon: const Icon(Icons.delete_forever),
                label: Text('profile.delete_account_cta'.tr()),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ),

            AppSpacing.gapSm,
```

- [ ] **Step 2: Analizzare e committare**

```bash
dart format lib/ test/
dart analyze
flutter test test/features/profile/
git add lib/features/profile/view/profile_screen.dart
git commit -m "fix: Elimina account come azione testuale, staccata da Esci

Era un bottone rosso pieno a tutta larghezza subito sotto Esci: l'azione
irreversibile era l'elemento più evidente del profilo.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `AppPill` pubblico e selettore bagagli con le pill (#8)

**Files:**
- Modify: `lib/shared/widgets/app_pill_tab.dart` (`_RawPillTab` → `AppPill`)
- Modify: `lib/features/trips/view/add_trip_screen.dart` (`_buildLuggageSelector`)
- Test: `test/shared/widgets/app_pill_test.dart`

**Interfaces:**
- Produces: `class AppPill extends StatefulWidget { const AppPill({Key? key, required String label, required bool isSelected, required VoidCallback onTap, Widget? icon, Color? selectedColor, Color? unselectedColor, Color? selectedTextColor, Color? unselectedTextColor, double? horizontalPadding, double? verticalPadding}); }`. `AppPillTab` invariato nella firma.

**Perché non `AppPillTab`:** `AppPillTab` è a scelta singola (`selectedItem`), i bagagli sono a scelta multipla. La pill singola è già un widget a sé (`_RawPillTab`, "solo rendering"): renderla pubblica dà ai bagagli lo stesso aspetto di tutte le altre scelte a pillola senza aggiungere una modalità multipla ad `AppPillTab`.

- [ ] **Step 1: Scrivere il test che fallisce**

`test/shared/widgets/app_pill_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/app_pill_tab.dart';

void main() {
  testWidgets('AppPill chiama onTap e segna la selezione col bordo d\'accento', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Row(
            children: [
              AppPill(
                key: const Key('a'),
                label: 'A',
                isSelected: true,
                onTap: () {},
              ),
              AppPill(
                key: const Key('b'),
                label: 'B',
                isSelected: false,
                onTap: () => tapped++,
              ),
            ],
          ),
        ),
      ),
    );

    BoxDecoration decorationOf(String key) =>
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byKey(Key(key)),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;

    final primary = AppTheme.light.colorScheme.primary;
    expect((decorationOf('a').border! as Border).top.color, primary);
    expect((decorationOf('b').border! as Border).top.color, isNot(primary));

    await tester.tap(find.byKey(const Key('b')));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });
}
```

- [ ] **Step 2: Eseguirlo e vederlo fallire**

Run: `flutter test test/shared/widgets/app_pill_test.dart`
Expected: FAIL in compilazione, `AppPill` non definito.

- [ ] **Step 3: Rendere pubblica la pill**

In `lib/shared/widgets/app_pill_tab.dart`:
- rinominare `_RawPillTab` in `AppPill` e `_RawPillTabState` in `_AppPillState` (anche in `createState` e in `State<_RawPillTab>` → `State<AppPill>`);
- il costruttore diventa `const AppPill({super.key, required this.label, required this.isSelected, required this.onTap, this.icon, this.selectedColor, this.unselectedColor, this.selectedTextColor, this.unselectedTextColor, this.horizontalPadding, this.verticalPadding});`;
- nel `build` di `AppPillTab` `child: _RawPillTab(` → `child: AppPill(`;
- il commento della classe diventa:
```dart
/// Una singola pill del design system: lo stesso aspetto di [AppPillTab].
///
/// Si usa da sola quando la scelta non è "uno fra tanti" (es. selezione
/// multipla dei bagagli, in un `Wrap`). Solo rendering e animazione: lo
/// stato di selezione lo decide il chiamante.
```

- [ ] **Step 4: Eseguire il test e vederlo passare**

Run: `flutter test test/shared/widgets/app_pill_test.dart`
Expected: `All tests passed!`.

- [ ] **Step 5: Bagagli con `AppPill`**

In `lib/features/trips/view/add_trip_screen.dart`, in `_buildLuggageSelector()`, sostituire tutto il `return Wrap(...)` del ramo `data` (dalla riga `return Wrap(` alla `);` che chiude il `Wrap`, cioè il blocco con `FilterChip`) con:
```dart
        return Wrap(
          spacing: context.spacingSm,
          runSpacing: context.spacingSm,
          children: allLuggages.map((luggage) {
            final isSelected = _selectedLuggages.any((l) => l.id == luggage.id);
            return AppPill(
              key: ValueKey('luggage_pill_${luggage.id}'),
              label: '${luggage.name} (${luggage.effectiveVolumeLiters ?? 0}L)',
              icon: Icon(Icons.luggage, size: context.iconSizeSm),
              isSelected: isSelected,
              onTap: () => setState(() {
                _selectedLuggages = isSelected
                    ? _selectedLuggages.where((l) => l.id != luggage.id).toList()
                    : [..._selectedLuggages, luggage];
              }),
            );
          }).toList(),
        );
```

e aggiungere l'import `import '../../../shared/widgets/app_pill_tab.dart';`.

Run: `grep -rn "FilterChip\|ChoiceChip" lib | grep "\.dart:"`
Expected: nessun risultato.

- [ ] **Step 6: Analizzare, testare, committare**

```bash
dart format lib/ test/
dart analyze
flutter test test/shared/widgets/ test/features/trips/
git add lib/shared/widgets/app_pill_tab.dart test/shared/widgets/app_pill_test.dart lib/features/trips/view/add_trip_screen.dart
git commit -m "fix: selettore bagagli con le pill del design system

Usava FilterChip, unico nell'app. La pill di AppPillTab diventa AppPill
pubblica e i bagagli (scelta multipla) la usano in un Wrap.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Pill tab della stessa altezza ovunque (#9)

**Files:**
- Modify: `lib/features/houses/view/house_detail_screen.dart:738`
- Modify: `lib/features/trips/view/trip_detail_screen.dart:113`
- Modify: `lib/features/trips/view/trip_items_selector.dart` (`_buildFilters`, due `SizedBox(height: 40, …)`)

**Cosa cambia davvero:** la pill in sé ha sempre la sua altezza naturale; `height: 40` decide lo spazio verticale della riga. Nel dettaglio casa le due righe di filtri avevano quindi ritmi diversi (spazi: naturale; categorie: 40). Togliendo il valore fisso tutte le righe di pill usano l'altezza naturale, come nel tab Viaggi.

- [ ] **Step 1: Togliere i valori fissi**

- `house_detail_screen.dart`, in `_CategoryFilterPills.build`: eliminare la riga `        height: 40,`.
- `trip_detail_screen.dart`, nell'`AppPillTab<TripItemFilterTab>`: eliminare la riga `                  height: 40,`.
- `trip_items_selector.dart`, in `_buildFilters`: sostituire
```dart
        SizedBox(
          height: 40,
          child: housesAsync.when(
```
con
```dart
        housesAsync.when(
```
togliendo anche la parentesi `),` che chiudeva quel `SizedBox` dopo `error: …`; e allo stesso modo sostituire
```dart
        SizedBox(
          height: 40,
          child: AppPillTab<_CategoryFilterOption>(
```
con
```dart
        AppPillTab<_CategoryFilterOption>(
```
togliendo la `),` del `SizedBox` corrispondente.

Run: `grep -rn "height: 40" lib | grep "\.dart:"`
Expected: restano solo `trip_date_range_screen.dart` (celle del calendario, non pill) e `skeleton_screens.dart` (segnaposto).

- [ ] **Step 2: Analizzare, testare, committare**

```bash
dart format lib/ test/
dart analyze
flutter test test/features/trips/ test/features/houses/
git add lib/features/houses/view/house_detail_screen.dart lib/features/trips/view/trip_detail_screen.dart lib/features/trips/view/trip_items_selector.dart
git commit -m "fix: stessa altezza per tutte le righe di pill tab

height: 40 fisso in tre schermate e default altrove: nel dettaglio casa
le due righe di filtri avevano spaziature diverse.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Input rapido senza overflow e ai token (#13, #10 parte)

**Files:**
- Modify: `lib/features/items/widgets/rapid_fire_input.dart:172-185, 310-322`
- Modify: `lib/features/items/widgets/category_pill.dart:47-56`
- Test: `test/features/items/widgets/rapid_fire_input_test.dart`

- [ ] **Step 1: Scrivere il test che fallisce**

`test/features/items/widgets/rapid_fire_input_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/widgets/category_pill.dart';
import 'package:pack_log/features/items/widgets/rapid_fire_input.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

void main() {
  testWidgets('input espanso: la riga delle categorie non sfora a 412 dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: RapidFireInput(houseId: 'h1'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(
      find.byType(CategoryPill),
      findsNWidgets(ItemCategory.values.length),
    );
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Eseguirlo e vederlo fallire**

Run: `flutter test test/features/items/widgets/rapid_fire_input_test.dart`
Expected: FAIL con `A RenderFlex overflowed by … pixels on the right` dalla `Row` di `rapid_fire_input.dart:175`. (Il font di test è più largo di Roboto, quindi l'overflow può essere maggiore dei 15 px dello screenshot: va bene, conta che ci sia.)

Se il test passa già, fermarsi: significa che il test non riproduce la larghezza reale. Ridurre la larghezza utile (es. `horizontal: 24`) finché fallisce sul codice attuale, poi proseguire.

- [ ] **Step 3: Riga categorie che si adatta, con i token**

In `rapid_fire_input.dart`, sostituire
```dart
                      child: Padding(
                        // Spazio visivo tra le categorie fluttuanti e l'input sottostante
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final category in ItemCategory.values) ...[
                              if (category != ItemCategory.values.first)
                                SizedBox(width: context.responsive(6)),
```
con
```dart
                      child: Padding(
                        // Spazio visivo tra le categorie fluttuanti e l'input sottostante
                        padding: EdgeInsets.only(bottom: context.spacingSm),
                        // scaleDown: su schermi stretti (o con testo grande di
                        // sistema) la riga si rimpicciolisce invece di sforare.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final category in ItemCategory.values) ...[
                              if (category != ItemCategory.values.first)
                                SizedBox(width: context.spacingXs),
```
e chiudere il `FittedBox` con una `),` in più dopo la `)` che chiude la `Row`. `dart format` sistemerà l'indentazione.

Nel bottone d'invio (righe ~310-322) sostituire
```dart
        width: 32,
        height: 32,
```
con
```dart
        width: context.iconSizeLg,
        height: context.iconSizeLg,
```
`const EdgeInsets.all(6)` con `EdgeInsets.all(context.spacingXs)` e `Icon(Icons.arrow_upward, size: 18, color: iconColor)` con `Icon(Icons.arrow_upward, size: context.iconSizeSm, color: iconColor)`.

In `category_pill.dart` sostituire
```dart
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
```
con
```dart
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingSm + context.spacingXs,
          vertical: context.spacingSm,
        ),
```
(12 invece di 14: la somma di due token, come già fa `main_shell.dart:400-401`), `size: 16` dell'icona con `size: context.iconSizeSm` e `const SizedBox(width: 6)` con `SizedBox(width: context.spacingXs)`. `category_pill.dart` non importa ancora i token: aggiungere `import '../../../shared/theme/app_spacing.dart';`.

- [ ] **Step 4: Eseguire il test e vederlo passare**

Run: `flutter test test/features/items/widgets/rapid_fire_input_test.dart`
Expected: `All tests passed!`.

- [ ] **Step 5: Commit**

```bash
dart format lib/ test/ && dart analyze
git add lib/features/items/widgets/rapid_fire_input.dart lib/features/items/widgets/category_pill.dart test/features/items/widgets/rapid_fire_input_test.dart
git commit -m "fix: la riga delle categorie dell'input rapido non sfora

A 412 dp sforava di 15 px. Ora si rimpicciolisce se serve
(FittedBox scaleDown) e padding, gap e icone usano i token.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Gli altri valori fissi ai token (#10)

**Files:**
- Modify: `lib/features/houses/view/houses_screen.dart:150-162, 210-256`
- Modify: `lib/features/items/view/item_card.dart:45-80`
- Modify: `lib/features/profile/widgets/sync_details_dialog.dart:62-65`
- Modify: `lib/features/trips/view/trip_picker_sheet.dart:95-98`
- Modify: `lib/shared/widgets/main_shell.dart:411, 415`
- Modify: `lib/shared/constants/app_constants.dart:4`

Sono sostituzioni senza logica: la verifica è `dart analyze`, la suite esistente e il confronto degli screenshot del Task 7.

- [ ] **Step 1: `houses_screen.dart`**

- Le due occorrenze di
```dart
        borderRadius: context.responsiveBorderRadius(
          AppConstants.cardBorderRadius + 4,
        ),
```
(nel `RoundedRectangleBorder` della `Card` e nell'`InkWell`) diventano
```dart
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
```
(la card casa era l'unica col raggio maggiorato: ora è come tutte le altre card).
- `Icons.location_on_outlined` con `size: 14` → `size: context.iconSizeSm`.
- `Icons.inventory_2_outlined` con `size: 16` → `size: context.iconSizeSm`.
- `const SizedBox(width: 4)` e `const SizedBox(width: 6)` in quelle due righe → `SizedBox(width: context.spacingXs)`.

Run: `grep -n "size: 1[0-9]\b\|width: [0-9]\b\|+ 4" lib/features/houses/view/houses_screen.dart`
Expected: nessun risultato.

- [ ] **Step 2: `item_card.dart`**

Le icone `Icons.flight_takeoff` accompagnano testo `bodySmall` (12): prendono la sua dimensione invece di un numero.
```dart
              Icon(
                Icons.flight_takeoff,
                size: Theme.of(context).textTheme.bodySmall?.fontSize,
                color: colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: context.spacingXs),
```
(entrambe le occorrenze, al posto di `size: 12` e `const SizedBox(width: 4)`).

- [ ] **Step 3: padding dei caricamenti**

`sync_details_dialog.dart` e `trip_picker_sheet.dart`, nel ramo `loading:`:
```dart
          loading: () => Padding(
            padding: EdgeInsets.all(context.spacingMd),
            child: const Center(child: CircularProgressIndicator()),
          ),
```
In entrambi i file il ramo `loading:` sta dentro `build`, quindi `context` è disponibile; il `const` si sposta dal `Padding` al `Center`.

- [ ] **Step 4: `main_shell.dart`**

Riga 411: `SizedBox(width: context.spacingSm + 2),` → `SizedBox(width: context.spacingSm),`.
Righe 413-418: lo stile dell'etichetta
```dart
                style: TextStyle(
                  fontSize: context.responsiveFont(15),
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
```
diventa
```dart
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
```
(`titleSmall` = 14, w600: lo slot del textTheme più vicino a 15/w600).

- [ ] **Step 5: commento della regola sui raggi**

`lib/shared/constants/app_constants.dart:4`: `// - Valori contestuali/magici (es. cardBorderRadius + 4) → context.responsiveBorderRadius(X).` → `// - Valori contestuali/magici (es. raggi derivati da un'altra misura) → context.responsiveBorderRadius(X).`

- [ ] **Step 6: Analizzare, testare, committare**

```bash
dart format lib/ test/
dart analyze
flutter test
git add lib/features/houses/view/houses_screen.dart lib/features/items/view/item_card.dart lib/features/profile/widgets/sync_details_dialog.dart lib/features/trips/view/trip_picker_sheet.dart lib/shared/widgets/main_shell.dart lib/shared/constants/app_constants.dart
git commit -m "refactor: valori numerici fissi riportati ai token

Raggio della card casa, icone, gap e padding dei caricamenti usano
AppConstants, context.spacing* e context.iconSize*; l'etichetta del
menu Crea usa titleSmall invece di responsiveFont(15).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Documentazione e verifica con gli screenshot

**Files:**
- Modify: `ARCHITECTURE.md` (tabella "Regole Architetturali dei Widget Condivisi")
- Modify: `.claude/skills/ui-design-system/SKILL.md`

- [ ] **Step 1: Documentazione**

`ARCHITECTURE.md`, nella tabella dei widget condivisi aggiungere:
```markdown
| `AppPillTab` / `AppPill` | Scelte a pillola: `AppPillTab<T>` per "uno fra tanti" (anche `.nullable`), `AppPill` in un `Wrap` per la scelta multipla. Mai `FilterChip`/`ChoiceChip`. Nessuna `height` fissa: le righe di pill hanno tutte l'altezza naturale. |
```

`.claude/skills/ui-design-system/SKILL.md`, dopo la regola `- Tab: AppPillTab<T>, mai SegmentedButton`:
```markdown
- Scelta multipla a pillola: `Wrap` di `AppPill`, mai `FilterChip`
- Avvisi d'errore dentro la pagina: `errorContainer` + `onErrorContainer` (anche per l'azione, es. "Riprova"); mai `primary` sopra un container d'errore
```

- [ ] **Step 2: Test completi**

```bash
dart format lib/ test/
dart analyze
flutter test
```
Expected: analyze pulito, tutti i test verdi.

- [ ] **Step 3: Screenshot "dopo" e confronto**

```bash
flutter test test/screenshots --dart-define=UI_SCREENSHOTS=true
```

Expected: nel manifest nessun `issues` non vuoto:
```bash
python3 -c "import json;m=json.load(open('build/ui-screenshots/manifest.json'));print([s['file'] for s in m['screens'] if s['issues']])"
```
→ `[]`.

Confrontare con `build/ui-screenshots-before/`:
- `06-import-ai/06-ai-risultati-errore-parziale-light.png`: box rosa tenue con testo rosso scuro, "Riprova" dello stesso colore, sottolineato. `-dark.png`: box rosso scuro con testo rosa.
- `10-profilo/02-profilo-fine-pagina-*`: "Esci" bordato; sotto, staccato, "Elimina il mio account" come testo rosso con icona. `10-profilo/06-elimina-account-dialog-*`: il dialog si apre ancora.
- `04-dettaglio-casa/04-dettaglio-casa-rapid-fire-*`: le quattro categorie in una riga, senza taglio a destra.
- `04-dettaglio-casa/01-*`, `09-dettaglio-viaggio/01-*`, `07-viaggi/02-*`: righe di pill con la stessa spaziatura.
- `03-case/03-case-elenco-*`: card casa con il raggio delle altre card.
- `03-case/05-shell-menu-crea-*`: etichette del menu Crea leggibili, senza tagli.

Il selettore bagagli (passo 2 del wizard) non è negli screenshot: prova manuale con `flutter run`, Crea → Viaggio, compilare il passo 1, Avanti. Atteso: bagagli come pill (bordo d'accento e fill tenue quando selezionati), selezione multipla.

- [ ] **Step 4: Commit**

```bash
git add ARCHITECTURE.md .claude/skills/ui-design-system/SKILL.md
git commit -m "docs: AppPill e colori d'errore nelle regole del design system

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Fuori da questo piano (annotato, non fatto)

- #14 (contenuto che scorre sotto la barra flottante): deciso di non intervenire.
- `main_shell.dart:398-401` usa altre somme di token (`spacingMd + spacingXs`, `responsive(22)` per l'icona). Non erano nell'elenco dell'attrito e sono già commentate come scelta voluta; restano.

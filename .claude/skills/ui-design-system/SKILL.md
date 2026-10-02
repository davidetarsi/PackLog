---
name: ui-design-system
description: Use when creating or modifying UI screens, widgets, forms, or bottom sheets. Covers Material 3 theme usage, responsive spacing extensions, shared widget catalog, screen templates (list, detail, form), and design system compliance rules. Activate whenever the task mentions screen, widget, form, bottom sheet, layout, UI, colors, spacing, or creating/modifying a view.
---

# UI Design System — Conventions

## Quando si attiva

Qualunque task che riguardi:
- Creare una nuova schermata (list, detail, form)
- Creare/modificare un widget
- Aggiungere un bottom sheet o form
- Cambiare layout, spacing, colori
- Debug di problemi visual/UI

## Regola zero

**Mai colori o spacing hardcoded.** Se stai scrivendo `Colors.orange`, `EdgeInsets.all(16)`, o `fontSize: 14`, fermati. Usa le extension (`context.spacingMd`, `colorScheme.primary`, `context.fontSizeSm`) e le costanti (`AppConstants.cardBorderRadius`).

## Template: List Screen

```dart
// file: lib/features/<feature>/view/<feature>_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:stuff_tracker_2/shared/theme/app_spacing.dart';
import 'package:stuff_tracker_2/shared/widgets/widgets.dart';
import '../providers/<feature>_provider.dart';

class <Feature>Screen extends ConsumerStatefulWidget {
  const <Feature>Screen({super.key});

  @override
  ConsumerState<<Feature>Screen> createState() => _<Feature>ScreenState();
}

class _<Feature>ScreenState extends ConsumerState<<Feature>Screen> {
  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(<feature>NotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: asyncData.when(
          data: (items) {
            if (items.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(<feature>NotifierProvider.future),
                child: LayoutBuilder(
                  builder: (_, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: EmptyState(
                        icon: Icons.xxx_outlined,
                        title: '<feature>.no_items'.tr(),
                      ),
                    ),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(<feature>NotifierProvider.future),
              color: colorScheme.primary,
              child: ListView.builder(
                padding: EdgeInsets.only(
                  top: context.spacingMd,
                  bottom: context.navBarReservedHeight,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _<Feature>Tile(item: items[index]),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => ErrorState(
            error: error,
            onRetry: () =>
                ref.read(<feature>NotifierProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}
```

Regole:
- `ConsumerStatefulWidget` (o `ConsumerWidget` se non serve stato locale)
- `ref.watch()` per dati, `ref.read()` per azioni
- `AsyncValue.when()` con tutti e tre i branch — mai `.value!`
- `EmptyState` wrappato in `LayoutBuilder` + `SingleChildScrollView` con `AlwaysScrollableScrollPhysics` per pull-to-refresh su lista vuota
- `ErrorState` con callback retry
- Padding bottom con `context.navBarReservedHeight` per floating tab bar
- Colori sempre da `Theme.of(context).colorScheme`

## Template: Detail Screen con selezione multipla

```dart
// file: lib/features/<feature>/view/<feature>_detail_screen.dart
class <Feature>DetailScreen extends ConsumerStatefulWidget {
  final String <feature>Id;
  const <Feature>DetailScreen({super.key, required this.<feature>Id});

  @override
  ConsumerState<<Feature>DetailScreen> createState() =>
      _<Feature>DetailScreenState();
}

class _<Feature>DetailScreenState
    extends ConsumerState<<Feature>DetailScreen> {
  final Set<String> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StickyCtaScaffold(
      appBar: DsContextualAppBar(
        normalAppBar: AppBar(title: Text('Titolo')),
        selectionAppBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _selectedIds.clear()),
          ),
          title: Text('${_selectedIds.length} selezionati'),
        ),
        isInSelectionMode: _isSelectionMode,
        switchDuration: const Duration(milliseconds: 220),
      ),
      body: /* lista contenuto */,
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _isSelectionMode
            ? UniversalActionBar(
                key: const ValueKey('selection'),
                primaryLabel: 'Azione bulk',
                onPrimaryPressed: _handleBulkAction,
                leftAction: CircularActionButton(
                  icon: Icons.delete,
                  onPressed: _handleBulkDelete,
                  color: colorScheme.error,
                ),
              )
            : UniversalActionBar(
                key: const ValueKey('normal'),
                primaryLabel: 'Aggiungi',
                onPrimaryPressed: _handleAdd,
              ),
      ),
    );
  }
}
```

Regole:
- `StickyCtaScaffold` per layout con action bar persistente in basso
- `DsContextualAppBar` per switch normal/selection (220ms)
- `AnimatedSwitcher` per bottom bar con `ValueKey` distinte per animazione corretta
- `UniversalActionBar` con slot laterali `CircularActionButton`
- Colore errore da `colorScheme.error`, mai hardcoded

## Template: Form Bottom Sheet

```dart
// file: lib/features/<feature>/view/add_edit_<feature>_sheet.dart

// --- Entry point ---
Future<void> showAddEdit<Feature>Sheet(
  BuildContext context, {
  String? <feature>Id,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddEdit<Feature>Sheet(<feature>Id: <feature>Id),
  );
}

// --- Sheet widget ---
class AddEdit<Feature>Sheet extends ConsumerStatefulWidget {
  final String? <feature>Id;
  const AddEdit<Feature>Sheet({super.key, this.<feature>Id});

  @override
  ConsumerState<AddEdit<Feature>Sheet> createState() =>
      _AddEdit<Feature>SheetState();
}

class _AddEdit<Feature>SheetState
    extends ConsumerState<AddEdit<Feature>Sheet> {
  final GlobalKey<<Feature>FormContentState> _formKey = GlobalKey();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return StandardBottomSheetLayout(
      title: widget.<feature>Id != null
          ? '<feature>.edit'.tr()
          : '<feature>.new'.tr(),
      showDeleteButton: widget.<feature>Id != null,
      onSave: () => _formKey.currentState?.save(),
      onDelete: _handleDelete,
      isLoading: _isLoading,
      child: <Feature>FormContent(
        key: _formKey,
        <feature>Id: widget.<feature>Id,
        onLoadingChanged: (loading) =>
            setState(() => _isLoading = loading),
      ),
    );
  }
}

// --- Form content (widget separato) ---
class <Feature>FormContent extends ConsumerStatefulWidget {
  final String? <feature>Id;
  final ValueChanged<bool> onLoadingChanged;
  const <Feature>FormContent({
    super.key,
    this.<feature>Id,
    required this.onLoadingChanged,
  });

  @override
  ConsumerState<<Feature>FormContent> createState() =>
      <Feature>FormContentState();
}

class <Feature>FormContentState
    extends ConsumerState<<Feature>FormContent> {
  // TextEditingController, form state...

  void save() {
    // validazione + salvataggio via provider
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(/* ... */),
        AppSpacing.gapMd,
        // Picker
        InkWell(
          onTap: () => DsPickerSheet.show<Category>(/* ... */),
          child: /* display valore selezionato */,
        ),
        AppSpacing.gapMd,
        // Toggle
        AppPillTab<bool>(
          items: const [true, false],
          selectedItem: _option,
          getLabel: (b) => b ? 'label_a'.tr() : 'label_b'.tr(),
          onSelected: (b) => setState(() => _option = b),
        ),
        AppSpacing.gapLg,
      ],
    );
  }
}
```

Regole:
- Entry point come funzione top-level `showAddEdit<Feature>Sheet()`
- `StandardBottomSheetLayout` wrappa il form — mai bottom sheet custom con handle manuale
- Form content come widget separato con `GlobalKey` per delegare `save()`
- Gap tra sezioni: `AppSpacing.gapMd` (intra-sezione) / `AppSpacing.gapLg` (inter-sezione)
- Picker: `DsPickerSheet.show<T>()`, mai `showModalBottomSheet` raw
- Tab: `AppPillTab<T>`, mai `SegmentedButton`

## Checklist: Design System Compliance

Ogni widget/screen DEVE rispettare tutte queste regole.

**Spacing:**
- `context.spacingXs` (4), `context.spacingSm` (8), `context.spacingMd` (16), `context.spacingLg` (24)
- Mai `EdgeInsets.all(16)` o `SizedBox(height: 8)` con numeri magic
- Gap tra widget: `AppSpacing.gapSm`, `AppSpacing.gapMd`, `AppSpacing.gapLg`
- Padding orizzontale screen: `context.spacingMd` (= gutter standard 16px)
- Ritmo verticale: `spacingSm` (8) interno al modulo, `spacingMd` (16) tra sezioni, `spacingLg` (24) tra gruppi

**Colori:**
- `colorScheme.primary`, `.secondary`, `.surface`, `.error`, `.onSurface`, `.onSurfaceVariant`
- `context.appColors.xxx` per colori semantici custom (success, itemTemporary)
- Mai `Colors.orange`, `Colors.blue`, `Colors.grey` o qualsiasi `Colors.xxx`
- Opacita' testo: 1.0 (primario), 0.70 (secondario/onSurfaceVariant), 0.50 (terziario), 0.38 (disabled)

**Font size:**
- `context.fontSizeXxs` (12), `context.fontSizeSm` (16), `context.fontSizeMd` (18), ecc.
- Mai `fontSize: N` hardcoded

**Card e bordi:**
- Padding card: `context.cardPaddingHero` (16) o `context.cardPaddingDense` (8)
- Border radius: `AppConstants.cardBorderRadius` (16), `.pillBorderRadius` (30), `.inputBorderRadius` (12), `.badgeBorderRadius` (8), `.modalBorderRadius` (20)

## Catalogo widget condivisi

Usa il widget condiviso giusto per lo scenario. Mai reimplementare da zero.

| Scenario | Widget | NON usare |
|---|---|---|
| Lista con CTA fisso in basso | `StickyCtaScaffold` | Scaffold custom con Stack |
| AppBar con mode switch | `DsContextualAppBar` | AnimatedSwitcher manuale su AppBar |
| Barra azioni primaria | `UniversalActionBar` | Row custom di bottoni |
| Bottone circolare laterale | `CircularActionButton` | IconButton custom |
| Tab/filtri a pill | `AppPillTab<T>` | `SegmentedButton`, `ChoiceChip` |
| Form in bottom sheet | `StandardBottomSheetLayout` | Bottom sheet custom con handle |
| Picker selezione | `DsPickerSheet<T>` | `showModalBottomSheet` + ListView raw |
| Tile lista universale | `UniversalItemTile` | ListTile o Row custom |
| Stato vuoto | `EmptyState` | Column inline con Icon + Text |
| Stato errore | `ErrorState` | Text('Errore') inline |
| Badge quantita' | `DsQuantityBadge` | Text('x$qty') custom |
| Badge stato | `DsStatusBadge` | Container + Text custom |
| Badge info | `DsInfoBadge` | Row(Icon, Text) custom |
| Stepper quantita' | `QuantityStepper` | Row(IconButton, Text, IconButton) |
| Handle bottom sheet | `BottomSheetHandle` | Container custom |
| Grid selezione icone | `DsIconPicker` | GridView custom |

## Red flags

- `Colors.orange`, `Colors.blue`, qualsiasi `Colors.xxx` fuori da definizioni tema
- `EdgeInsets.all(N)` / `SizedBox(height: N)` con numeri magic (usa spacing extensions)
- `fontSize: N` hardcoded (usa `context.fontSizeXxx`)
- `SegmentedButton` invece di `AppPillTab`
- `showModalBottomSheet` + handle custom invece di `StandardBottomSheetLayout`
- Empty state inline `Column(children: [Icon(size: 80), Text()])` invece di `EmptyState`
- `QuantityStepper` reimplementato inline con bottoni +/-
- `.value!` su AsyncValue senza `.when()`
- `Navigator.push()` / `Navigator.pop()` invece di `context.push()` / `context.pop()`

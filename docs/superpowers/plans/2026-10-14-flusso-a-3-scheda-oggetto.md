# Flusso A · Blocco 3: scheda dell'oggetto a righe di impostazioni

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sostituire il modulo dell'oggetto (sei campi bordati, tre bottoni) con una scheda di sola modifica: nome come titolo, un blocco di righe (Categoria, Quantità, Spazio), "Aggiungi una nota", "Sposta in un'altra casa" ed "Elimina" nel "⋯", un solo bottone "Salva".

**Architecture:** Due componenti condivisi del kit, `DsSettingsGroup` e `DsSettingsRow` (costruita su `ListTile`), e una scheda nuova `ItemSheet` che li usa con `DsPickerSheet`, `QuantityStepper`, `DsButton`, `BulkMoveSheet` e `DialogHelpers` già esistenti. Dopo il blocco 2 l'unico punto che apre la scheda è la riga dell'oggetto (`ItemCard`), sempre in modifica: il vecchio `AddEditItemSheet` + `ItemFormContent` (creazione e modifica) si cancella.

**Tech Stack:** Flutter 3.38, Riverpod 2.5, easy_localization; test di widget con l'harness degli screenshot.

**Spec:** `docs/superpowers/specs/2026-10-14-flusso-a-dettaglio-casa-design.md`, sezione 5 e "Regole per il kit" punto 3.

**Parte da:** `develop` con i blocchi 1 e 2 dentro. Prima di iniziare verifica con `grep -rn "showAddEditItemSheet\|AddEditItemSheet\|ItemFormContent" lib test` che gli unici usi rimasti siano `item_card.dart`, i due file da cancellare e `ui_screenshots_test.dart` (solo come stringa `source:`). Se ce ne sono altri, fermati e segnalalo.

## Global Constraints

- Branch `feat/casa-scheda-oggetto` da `origin/develop`; PR verso `develop` (squash).
- Niente colori, spaziature o font scritti a mano.
- `DsSettingsGroup`: angoli `AppConstants.cardBorderRadius`, sfondo `surfaceContainerLowest` in chiaro e `surfaceContainer` in scuro, linee interne `Divider(height: 1)` rientrate di `spacingMd` a sinistra e a destra, colore `outlineVariant`.
- `DsSettingsRow`: altezza minima `context.responsive(56)`, etichetta `bodyLarge` a sinistra; a destra o un controllo (`trailing`) o un valore `bodyLarge` `onSurfaceVariant` seguito, se la riga si tocca, da `Icons.chevron_right` `iconSizeSm` `onSurfaceVariant`.
- Nella scheda l'unico arancio è "Salva": `QuantityStepper(accentColor: colorScheme.onSurface)`, link "Aggiungi una nota" in `onSurfaceVariant`, "Elimina" nel menu in `error`.
- Nome: campo senza bordo, `headlineSmall`, da 1 a 3 righe, obbligatorio (`common.name_required_validation`).
- Riga "Spazio" visibile solo se la casa ha almeno uno spazio o l'oggetto ne ha uno.
- Stringhe nuove in `it-IT.json` **e** `en-US.json`: `items.add_note` ("Aggiungi una nota" / "Add a note"), `items.move_to_house` ("Sposta in un'altra casa" / "Move to another house"), `items.select_category` ("Scegli la categoria" / "Choose a category").
- Dopo ogni task: `dart analyze` pulito e test verdi; commit (italiano, riga `Co-Authored-By:` del modello che scrive il commit).

---

### Task 1: `DsSettingsGroup` e `DsSettingsRow`

**Files:**
- Create: `lib/shared/widgets/ds_settings.dart`
- Modify: `lib/shared/widgets/widgets.dart` (export, in ordine alfabetico)
- Test: `test/shared/widgets/ds_settings_test.dart`

**Interfaces:**
- Produces: `DsSettingsGroup({Key? key, required List<Widget> children})`, `DsSettingsRow({Key? key, required String label, String? value, Widget? trailing, VoidCallback? onTap})`.

- [ ] **Step 1: test che falliscono**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_settings.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {ThemeData? theme}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: theme ?? AppTheme.light,
          home: Scaffold(body: child),
        ),
      );

  testWidgets('riga con valore toccabile: valore e chevron', (tester) async {
    var taps = 0;
    await pump(
      tester,
      DsSettingsRow(label: 'Categoria', value: 'Vestiti', onTap: () => taps++),
    );
    expect(find.text('Categoria'), findsOneWidget);
    expect(find.text('Vestiti'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('Vestiti'));
    expect(taps, 1);
  });

  testWidgets('riga con controllo: niente chevron', (tester) async {
    await pump(
      tester,
      const DsSettingsRow(label: 'Quantità', trailing: Text('7')),
    );
    expect(find.text('7'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('il gruppo mette una linea tra le righe, non prima né dopo', (
    tester,
  ) async {
    await pump(
      tester,
      const DsSettingsGroup(
        children: [
          DsSettingsRow(label: 'A', value: '1'),
          DsSettingsRow(label: 'B', value: '2'),
          DsSettingsRow(label: 'C', value: '3'),
        ],
      ),
    );
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('sfondo bianco in chiaro, grigio in scuro', (tester) async {
    Color groupColor() => tester
        .widget<Material>(
          find
              .descendant(
                of: find.byType(DsSettingsGroup),
                matching: find.byType(Material),
              )
              .first,
        )
        .color!;

    await pump(tester, const DsSettingsGroup(children: [SizedBox()]));
    expect(groupColor(), AppTheme.light.colorScheme.surfaceContainerLowest);

    await pump(
      tester,
      const DsSettingsGroup(children: [SizedBox()]),
      theme: AppTheme.dark,
    );
    expect(groupColor(), AppTheme.dark.colorScheme.surfaceContainer);
  });
}
```

- [ ] **Step 2:** `flutter test test/shared/widgets/ds_settings_test.dart` → FAIL.

- [ ] **Step 3: implementazione**

```dart
import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// Blocco di righe di impostazioni: il componente standard dei moduli
/// (oggetto, casa, spazio, bagaglio, viaggio). Le righe sono separate da
/// linee rientrate, il blocco ha angoli arrotondati e uno sfondo appena
/// diverso dalla pagina.
class DsSettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const DsSettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // In chiaro bianco sulla pagina crema; in scuro un grigio più chiaro
    // della pagina, come i gruppi di Revolut.
    final background = theme.brightness == Brightness.light
        ? cs.surfaceContainerLowest
        : cs.surfaceContainer;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: context.spacingMd,
                endIndent: context.spacingMd,
                color: cs.outlineVariant,
              ),
            child,
          ],
        ],
      ),
    );
  }
}

/// Riga di un [DsSettingsGroup]: etichetta a sinistra; a destra un
/// controllo ([trailing]) oppure il valore corrente ([value]) con la freccia
/// se la riga apre una scelta.
class DsSettingsRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const DsSettingsRow({
    super.key,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final value = this.value;
    final end =
        trailing ??
        (value == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  if (onTap != null) ...[
                    SizedBox(width: context.spacingXs),
                    Icon(
                      Icons.chevron_right,
                      size: context.iconSizeSm,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ],
              ));

    return ListTile(
      minTileHeight: context.responsive(56),
      contentPadding: EdgeInsets.symmetric(horizontal: context.spacingMd),
      title: Text(label, style: textTheme.bodyLarge),
      trailing: end,
      onTap: onTap,
    );
  }
}
```

Export in `widgets.dart`: `export 'ds_settings.dart';` (dopo `ds_section_header.dart`).

- [ ] **Step 4:** stesso comando → PASS (4 test).

- [ ] **Step 5: commit**

```bash
git add lib/shared/widgets/ds_settings.dart lib/shared/widgets/widgets.dart test/shared/widgets/ds_settings_test.dart
git commit -m "feat(ds): DsSettingsGroup e DsSettingsRow, righe di impostazioni per i moduli"
```

---

### Task 2: `ItemSheet`, la scheda di modifica

**Files:**
- Create: `lib/features/items/view/item_sheet.dart`
- Modify: `lib/features/items/view/item_card.dart` (apre `showItemSheet`)
- Delete: `lib/features/items/view/add_edit_item_screen.dart`, `lib/features/items/view/item_form_content.dart`
- Modify: `assets/translations/it-IT.json`, `assets/translations/en-US.json` (tre stringhe dei Global Constraints)
- Test: `test/features/items/view/item_sheet_test.dart`

**Interfaces:**
- Consumes: `DsSettingsGroup`, `DsSettingsRow` (task 1); `BulkMoveSheet.show(context, itemCount:, sourceHouseId:)` → `BulkMoveDestination?`; `itemNotifierProvider(houseId).notifier` con `updateItem(item)`, `deleteItem(itemId, houseId)`, `bulkMove(ids, houseId, spaceId:)`; `ErrorRetryDialog.executeWithRetry(context:, operation:, errorTitle:, errorMessage:)` → `Future<bool>`; `DialogHelpers.showDeleteConfirmation(context:, itemType:, itemName:)`.
- Produces: `Future<void> showItemSheet(BuildContext context, {required String houseId, required String itemId})`.

- [ ] **Step 1: test che falliscono** — `test/features/items/view/item_sheet_test.dart`, con l'harness (Casa Milano: "Calzini" è Vestiti, quantità 7, spazio Cassettiera; verificalo in `test/screenshots/support/seed.dart`):

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screenshots/support/harness.dart';
import '../../../screenshots/support/seed.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });

  Future<ScreenshotApp> openCalzini(WidgetTester tester) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    await app.go('/');
    await app.push('/houses/$kHomeId');
    await app.tap(find.text('Calzini'));
    return app;
  }

  String nameText(WidgetTester tester) => tester
      .widget<TextFormField>(find.byKey(const Key('item_sheet_name')))
      .controller!
      .text;

  testWidgets('mostra nome, categoria, quantità e spazio', (tester) async {
    final app = await openCalzini(tester);
    expect(nameText(tester), 'Calzini');
    expect(
      find.descendant(
        of: find.byKey(const Key('item_sheet_category')),
        matching: find.text('Vestiti'),
      ),
      findsOneWidget,
    );
    expect(find.text('7'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('item_sheet_space')),
        matching: find.text('Cassettiera'),
      ),
      findsOneWidget,
    );
    await app.finish();
  });

  testWidgets('+ e Salva aggiornano la quantità nella lista', (tester) async {
    final app = await openCalzini(tester);
    await app.tap(find.byIcon(Icons.add_circle_outline));
    await app.tap(find.byKey(const Key('item_sheet_save')));
    expect(find.byKey(const Key('item_sheet_name')), findsNothing);
    expect(find.text('x8'), findsOneWidget);
    await app.finish();
  });

  testWidgets('senza nome non salva', (tester) async {
    final app = await openCalzini(tester);
    await app.enterText(find.byKey(const Key('item_sheet_name')), '  ');
    await app.tap(find.byKey(const Key('item_sheet_save')));
    expect(find.byKey(const Key('item_sheet_name')), findsOneWidget);
    expect(find.text('common.name_required_validation'.tr()), findsOneWidget);
    await app.finish();
  });

  testWidgets('Aggiungi una nota apre il campo', (tester) async {
    final app = await openCalzini(tester);
    await app.tap(find.byKey(const Key('item_sheet_add_note')));
    expect(find.byKey(const Key('item_sheet_note')), findsOneWidget);
    await app.finish();
  });

  testWidgets('Elimina dal menu, con conferma, toglie l oggetto', (
    tester,
  ) async {
    final app = await openCalzini(tester);
    await app.tap(find.byKey(const Key('item_sheet_menu')));
    await app.tap(find.text('Elimina').last);
    // Conferma nel dialog.
    await app.tap(find.text('Elimina').last);
    expect(find.byKey(const Key('item_sheet_name')), findsNothing);
    expect(find.text('Calzini'), findsNothing);
    await app.finish();
  });

  testWidgets('solo Salva è arancio: il − e il + sono neutri', (tester) async {
    final app = await openCalzini(tester);
    final plus = tester.widget<Icon>(find.byIcon(Icons.add_circle_outline));
    expect(plus.color, isNot(AppTheme.light.colorScheme.primary));
    await app.finish();
  });
}
```

Se `useSystemSqlite` non è esportato da `harness.dart`, importalo da dove sta (`support/fakes.dart`), come fa `test/features/houses/view/house_detail_screen_test.dart`.

- [ ] **Step 2:** `flutter test test/features/items/view/item_sheet_test.dart` → FAIL.

- [ ] **Step 3: `item_sheet.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/constants/space_icons.dart';
import '../../../shared/helpers/dialog_helpers.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_bottom_sheet_handle.dart';
import '../../../shared/widgets/ds_button.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../../../shared/widgets/ds_settings.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/quantity_stepper.dart';
import '../../spaces/model/space_model.dart';
import '../../spaces/providers/space_provider.dart';
import '../model/item_model.dart';
import '../providers/item_provider.dart';
import 'bulk_move_sheet.dart';

/// Apre la scheda di un oggetto esistente.
Future<void> showItemSheet(
  BuildContext context, {
  required String houseId,
  required String itemId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ItemSheet(houseId: houseId, itemId: itemId),
  );
}

/// Opzione del picker spazio. `id == null` è "Senza spazio": non si può
/// usare `null` come valore, per [DsPickerSheet] vuol dire "chiuso".
typedef _SpaceOption = ({String? id, String name, IconData icon});

enum _ItemMenu { move, delete }

/// Scheda di modifica di un oggetto. Il nome è il titolo; categoria,
/// quantità e spazio sono righe di impostazioni; spostare in un'altra casa ed
/// eliminare stanno nel "⋯". L'unico arancio è "Salva".
///
/// La creazione non passa di qui: si fa dal rapid fire (nome, categoria,
/// quantità 1) e si corregge poi da questa scheda.
class ItemSheet extends ConsumerStatefulWidget {
  final String houseId;
  final String itemId;

  const ItemSheet({super.key, required this.houseId, required this.itemId});

  @override
  ConsumerState<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<ItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  ItemCategory _category = ItemCategory.varie;
  int _quantity = 1;
  String? _spaceId;
  bool _showNote = false;
  bool _loaded = false;
  bool _isSaving = false;

  ItemModel? _item() =>
      (ref.read(itemNotifierProvider(widget.houseId)).valueOrNull ??
              const <ItemModel>[])
          .where((i) => i.id == widget.itemId)
          .firstOrNull;

  @override
  void initState() {
    super.initState();
    final item = _item();
    if (item == null) return;
    _nameController.text = item.name;
    _noteController.text = item.description ?? '';
    _category = item.category;
    _quantity = item.quantity ?? 1;
    _spaceId = item.spaceId;
    _showNote = item.description != null;
    _loaded = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final picked = await DsPickerSheet.show<ItemCategory>(
      context: context,
      title: 'items.select_category'.tr(),
      items: ItemCategory.values,
      getLabel: (c) => c.displayName,
      getIcon: (c) => c.icon,
      selected: _category,
    );
    if (picked != null && mounted) setState(() => _category = picked);
  }

  Future<void> _pickSpace(List<SpaceModel> spaces) async {
    final options = <_SpaceOption>[
      (id: null, name: 'spaces.default'.tr(), icon: Icons.inventory_2),
      for (final space in spaces)
        (
          id: space.id,
          name: space.name,
          icon: space.iconName != null
              ? SpaceIcons.getIcon(space.iconName!)
              : Icons.meeting_room,
        ),
    ];
    final picked = await DsPickerSheet.show<_SpaceOption>(
      context: context,
      title: 'items.select_space'.tr(),
      items: options,
      getLabel: (o) => o.name,
      getIcon: (o) => o.icon,
      selected: options.firstWhere(
        (o) => o.id == _spaceId,
        orElse: () => options.first,
      ),
    );
    if (picked != null && mounted) setState(() => _spaceId = picked.id);
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final item = _item();
    if (item == null) return;
    final note = _noteController.text.trim();
    final updated = item.copyWith(
      name: _nameController.text.trim(),
      description: note.isEmpty ? null : note,
      category: _category,
      quantity: _quantity,
      spaceId: _spaceId,
      updatedAt: DateTime.now(),
    );
    setState(() => _isSaving = true);
    final ok = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => ref
          .read(itemNotifierProvider(widget.houseId).notifier)
          .updateItem(updated),
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: 'errors.save_item_failed'.tr(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final typed = _nameController.text.trim();
    final name = typed.isEmpty ? 'items.this_item'.tr() : typed;
    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: 'common.item_type'.tr(),
      itemName: name,
    );
    if (confirmed != true || !mounted) return;
    final ok = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => ref
          .read(itemNotifierProvider(widget.houseId).notifier)
          .deleteItem(widget.itemId, widget.houseId),
      errorTitle: 'common.error'.tr(),
      errorMessage: 'errors.delete_item_failed'.tr(args: [name]),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _moveToHouse() async {
    final dest = await BulkMoveSheet.show(
      context,
      itemCount: 1,
      sourceHouseId: widget.houseId,
    );
    if (dest == null || !mounted) return;
    final ok = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => ref
          .read(itemNotifierProvider(widget.houseId).notifier)
          .bulkMove([widget.itemId], dest.houseId, spaceId: dest.spaceId),
      errorTitle: 'common.error'.tr(),
      errorMessage: 'errors.save_error'.tr(),
    );
    if (!ok || !mounted) return;
    AppSnackBar.showSuccess(
      context,
      'items.bulk_move_success'.tr(args: ['1', dest.houseDisplayName]),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spaces =
        ref.watch(spaceNotifierProvider(widget.houseId)).valueOrNull ??
        const <SpaceModel>[];
    final spaceName =
        spaces.where((s) => s.id == _spaceId).firstOrNull?.name ??
        'spaces.default'.tr();
    const noBorder = InputBorder.none;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppConstants.modalBorderRadius),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              context.spacingMd,
              0,
              context.spacingMd,
              context.spacingMd,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DsBottomSheetHandle(),
                  Row(
                    children: [
                      IconButton(
                        key: const Key('item_sheet_close'),
                        icon: const Icon(Icons.close),
                        tooltip: 'common.close'.tr(),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      PopupMenuButton<_ItemMenu>(
                        key: const Key('item_sheet_menu'),
                        icon: const Icon(Icons.more_horiz),
                        onSelected: (choice) => switch (choice) {
                          _ItemMenu.move => _moveToHouse(),
                          _ItemMenu.delete => _delete(),
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: _ItemMenu.move,
                            child: Text('items.move_to_house'.tr()),
                          ),
                          PopupMenuItem(
                            value: _ItemMenu.delete,
                            child: Text(
                              'common.delete'.tr(),
                              style: TextStyle(color: cs.error),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  TextFormField(
                    key: const Key('item_sheet_name'),
                    controller: _nameController,
                    style: textTheme.headlineSmall,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      border: noBorder,
                      enabledBorder: noBorder,
                      focusedBorder: noBorder,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: context.spacingXs,
                      ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'common.name_required_validation'.tr()
                        : null,
                  ),
                  SizedBox(height: context.spacingMd),
                  DsSettingsGroup(
                    children: [
                      DsSettingsRow(
                        key: const Key('item_sheet_category'),
                        label: 'items.category_label'.tr(),
                        value: _category.displayName,
                        onTap: _pickCategory,
                      ),
                      DsSettingsRow(
                        label: 'items.quantity'.tr(),
                        trailing: QuantityStepper(
                          value: _quantity,
                          minValue: 1,
                          // Neutro: nella scheda l'arancio è solo di "Salva".
                          accentColor: cs.onSurface,
                          onChanged: (v) => setState(() => _quantity = v),
                        ),
                      ),
                      if (spaces.isNotEmpty || _spaceId != null)
                        DsSettingsRow(
                          key: const Key('item_sheet_space'),
                          label: 'items.space_label'.tr(),
                          value: spaceName,
                          onTap: () => _pickSpace(spaces),
                        ),
                    ],
                  ),
                  if (_showNote)
                    Padding(
                      padding: EdgeInsets.only(top: context.spacingMd),
                      child: TextFormField(
                        key: const Key('item_sheet_note'),
                        controller: _noteController,
                        autofocus: _noteController.text.isEmpty,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'items.description_label'.tr(),
                        ),
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('item_sheet_add_note'),
                        style: TextButton.styleFrom(
                          foregroundColor: cs.onSurfaceVariant,
                        ),
                        onPressed: () => setState(() => _showNote = true),
                        icon: Icon(Icons.add, size: context.iconSizeSm),
                        label: Text('items.add_note'.tr()),
                      ),
                    ),
                  SizedBox(height: context.spacingSm),
                  DsButton(
                    key: const Key('item_sheet_save'),
                    label: 'common.save'.tr(),
                    expand: true,
                    isLoading: _isSaving,
                    onPressed: _save,
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

Verifica i nomi prima di scrivere: `DsBottomSheetHandle` (`lib/shared/widgets/ds_bottom_sheet_handle.dart`), `AppSnackBar.showSuccess` (`lib/shared/helpers/snack_bar_helper.dart`), `DialogHelpers` (`lib/shared/helpers/dialog_helpers.dart`), `ErrorRetryDialog` (`lib/shared/widgets/error_retry_dialog.dart`), `SpaceIcons.getIcon`, `DsButton(expand:, isLoading:)`. Se un percorso è diverso, usa quello reale.

- [ ] **Step 4: `item_card.dart`** — `showAddEditItemSheet(context, houseId: item.houseId, itemId: item.id)` diventa `showItemSheet(context, houseId: item.houseId, itemId: item.id)`, import `item_sheet.dart` al posto di `add_edit_item_screen.dart`. Cancella `add_edit_item_screen.dart` e `item_form_content.dart` (`git rm`). Rilancia il grep del preambolo: in `lib` non deve restare nulla. Le chiavi di traduzione usate solo dal vecchio modulo (es. `common.select_quantity`) restano: le pulisce il blocco finale se inutilizzate.

- [ ] **Step 5: verifica**

Run: `flutter test test/features/items && dart analyze && flutter test`
Expected: tutto verde, analisi pulita.

- [ ] **Step 6: commit**

```bash
git add lib/features/items assets/translations test/features/items
git commit -m "feat(oggetti): scheda di modifica a righe di impostazioni, via il vecchio modulo"
```

---

### Task 3: screenshot e documentazione

**Files:**
- Modify: `test/screenshots/ui_screenshots_test.dart` (flusso `05-oggetti`, scenario 2)
- Modify: `docs/ui-flows.md` (`git add -f`); `ARCHITECTURE.md` solo locale

- [ ] **Step 1:** scenario 2 del flusso `05-oggetti`: `screen: 'oggetto-scheda'`, `state: 'modifica'`, `source: 'lib/features/items/view/item_sheet.dart'`, descrizione `'Tocco su un oggetto: nome come titolo, righe Categoria / Quantità / Spazio, solo Salva arancio.'` (passi invariati). Aggiungi lo scenario 3 `'oggetto-scheda', 'menu'` con gli stessi passi più `await app.tap(find.byKey(const Key('item_sheet_menu')));`.
- [ ] **Step 2:** `flutter test test/screenshots/ui_screenshots_test.dart --dart-define=UI_SCREENSHOTS=true` → verdi, manifest senza problemi; guarda 05/02 e 05/03 in chiaro e scuro.
- [ ] **Step 3:** `docs/ui-flows.md`: la scheda dell'oggetto nuova. `ARCHITECTURE.md`: `DsSettingsGroup`/`DsSettingsRow` come standard dei moduli; la scheda oggetto è solo modifica, la creazione passa dal rapid fire.
- [ ] **Step 4: commit**

```bash
git add test/screenshots/ui_screenshots_test.dart
git add -f docs/ui-flows.md
git commit -m "test(screenshot): scheda oggetto nuova; flussi UI aggiornati"
```

---

### Task 4: PR

- [ ] `git push -u origin feat/casa-scheda-oggetto`; PR verso `develop` "Oggetti: scheda di modifica a righe di impostazioni", con chiusura `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

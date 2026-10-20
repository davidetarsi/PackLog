import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/constants/space_icons.dart';
import '../../../shared/helpers/dialog_helpers.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_button.dart';
import '../../../shared/widgets/ds_field.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../../../shared/widgets/ds_section_title.dart';
import '../../../shared/widgets/ds_sheet_header.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/quantity_stepper.dart';
import '../../spaces/model/space_model.dart';
import '../../spaces/providers/space_provider.dart';
import '../model/item_model.dart';
import '../providers/item_provider.dart';
import '../services/category_infer_service.dart';
import '../widgets/category_pill.dart';
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

/// Apre la scheda per creare un oggetto nella casa [houseId], con il nome già
/// scritto ([initialName]). Restituisce l'oggetto creato, o `null` se la
/// scheda si chiude senza crearlo.
Future<ItemModel?> showNewItemSheet(
  BuildContext context, {
  required String houseId,
  String initialName = '',
  required String submitLabel,
  IconData? submitIcon,
  String? footnote,
}) {
  return showModalBottomSheet<ItemModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ItemSheet.create(
      houseId: houseId,
      initialName: initialName,
      submitLabel: submitLabel,
      submitIcon: submitIcon,
      footnote: footnote,
    ),
  );
}

/// Opzione del picker spazio. `id == null` è "Senza spazio": non si può
/// usare `null` come valore, per [DsPickerSheet] vuol dire "chiuso".
typedef _SpaceOption = ({String? id, String name, IconData icon});

enum _ItemMenu { move, delete }

/// Scheda di un oggetto, la stessa per crearlo e per modificarlo: nome,
/// categorie su una riga, quantità, spazio (se la casa ne ha) e dettagli.
///
/// Le categorie sono le pillole della pagina "Aggiungi" della casa: bordata è
/// la proposta dedotta dal nome, piena la scelta dell'utente. Nella modifica
/// la categoria dell'oggetto è già una scelta. Spostare in un'altra casa ed
/// eliminare stanno nel "⋯", solo nella modifica.
class ItemSheet extends ConsumerStatefulWidget {
  final String houseId;

  /// Oggetto da modificare; `null` per crearne uno.
  final String? itemId;

  /// Nome con cui parte la creazione.
  final String initialName;

  /// Etichetta e icona del bottone della creazione.
  final String? submitLabel;
  final IconData? submitIcon;

  /// Riga di aiuto sopra il bottone della creazione.
  final String? footnote;

  const ItemSheet({
    super.key,
    required this.houseId,
    required String this.itemId,
  }) : initialName = '',
       submitLabel = null,
       submitIcon = null,
       footnote = null;

  const ItemSheet.create({
    super.key,
    required this.houseId,
    this.initialName = '',
    required String this.submitLabel,
    this.submitIcon,
    this.footnote,
  }) : itemId = null;

  @override
  ConsumerState<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<ItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  /// Categoria scelta toccando una pillola. Nella creazione, finché è `null`,
  /// vale quella dedotta dal nome.
  ItemCategory? _chosenCategory;
  int _quantity = 1;
  String? _spaceId;
  bool _loaded = false;
  bool _isSaving = false;

  bool get _isNew => widget.itemId == null;

  ItemModel? _item() =>
      (ref.read(itemNotifierProvider(widget.houseId)).valueOrNull ??
              const <ItemModel>[])
          .where((i) => i.id == widget.itemId)
          .firstOrNull;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _nameController.text = widget.initialName;
      _loaded = true;
      return;
    }
    final item = _item();
    if (item == null) {
      // Oggetto non trovato (es. cancellato da un altro dispositivo): il foglio
      // si chiude invece di restare vuoto.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    _nameController.text = item.name;
    _noteController.text = item.description ?? '';
    _chosenCategory = item.category;
    _quantity = item.quantity ?? 1;
    _spaceId = item.spaceId;
    _loaded = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Categoria dedotta dal nome, solo nella creazione e finché l'utente non
  /// ne sceglie una. [service] è `null` finché il dizionario non è pronto.
  ItemCategory? _inferredCategory(CategoryInferService? service) {
    if (!_isNew || _chosenCategory != null) return null;
    return service?.infer(_nameController.text.trim()).category;
  }

  /// Nella creazione, toccare la pillola già scelta torna alla proposta, come
  /// nella pagina "Aggiungi". Nella modifica una categoria c'è sempre.
  void _tapCategory(ItemCategory category) {
    setState(() {
      _chosenCategory = _isNew && _chosenCategory == category ? null : category;
    });
  }

  CategoryPillState _pillState(ItemCategory category, ItemCategory? inferred) {
    if (_chosenCategory == category) return CategoryPillState.forced;
    if (inferred == category) return CategoryPillState.inferred;
    return CategoryPillState.inactive;
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
    if (_isNew) return _create();
    final item = _item();
    if (item == null) {
      AppSnackBar.showError(context, 'errors.save_item_failed'.tr());
      Navigator.pop(context);
      return;
    }
    final note = _noteController.text.trim();
    final updated = item.copyWith(
      name: _nameController.text.trim(),
      description: note.isEmpty ? null : note,
      category: _chosenCategory ?? item.category,
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

  /// Crea l'oggetto con la categoria scelta, altrimenti quella dedotta dal
  /// nome, altrimenti "Varie": la stessa regola della pagina "Aggiungi".
  Future<void> _create() async {
    final note = _noteController.text.trim();
    final now = DateTime.now();
    final item = ItemModel(
      id: const Uuid().v4(),
      houseId: widget.houseId,
      name: _nameController.text.trim(),
      category:
          _chosenCategory ??
          _inferredCategory(
            ref.read(categoryInferServiceProvider).valueOrNull,
          ) ??
          ItemCategory.varie,
      description: note.isEmpty ? null : note,
      quantity: _quantity,
      spaceId: _spaceId,
      createdAt: now,
      updatedAt: now,
    );
    setState(() => _isSaving = true);
    final ok = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () =>
          ref.read(itemNotifierProvider(widget.houseId).notifier).addItem(item),
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: 'errors.create_item_failed'.tr(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) Navigator.pop(context, item);
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
          .deleteItem(widget.itemId!, widget.houseId),
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
          .bulkMove([widget.itemId!], dest.houseId, spaceId: dest.spaceId),
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
    final inferred = _inferredCategory(
      ref.watch(categoryInferServiceProvider).valueOrNull,
    );
    final footnote = widget.footnote;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DsSheetHeader(
                title: _isNew ? 'items.new_item'.tr() : 'items.edit_item'.tr(),
                onClose: () => Navigator.pop(context),
                actions: [
                  if (!_isNew)
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
              Flexible(
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
                        DsSectionTitle('items.name_label'.tr()),
                        TextFormField(
                          key: const Key('item_sheet_name'),
                          controller: _nameController,
                          minLines: 1,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: dsFieldDecoration(context),
                          // Ridisegna la proposta di categoria.
                          onChanged: (_) => setState(() {}),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'common.name_required_validation'.tr()
                              : null,
                        ),
                        DsSectionTitle('items.category_label'.tr()),
                        SizedBox(
                          key: const Key('item_sheet_category'),
                          height: context.responsive(
                            AppConstants.categoryRowHeight,
                          ),
                          child: Row(
                            children: [
                              for (final category in ItemCategory.values) ...[
                                if (category != ItemCategory.values.first)
                                  SizedBox(width: context.spacingXs),
                                Expanded(
                                  child: CategoryPill(
                                    category: category,
                                    pillState: _pillState(category, inferred),
                                    onTap: () => _tapCategory(category),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _InlineField(
                          label: 'items.quantity'.tr(),
                          child: QuantityStepper(
                            value: _quantity,
                            minValue: 1,
                            // Neutro: nella scheda l'arancio è del bottone e
                            // della categoria scelta.
                            accentColor: cs.onSurface,
                            onChanged: (v) => setState(() => _quantity = v),
                          ),
                        ),
                        if (spaces.isNotEmpty || _spaceId != null)
                          _InlineField(
                            label: 'items.space_label'.tr(),
                            child: InkWell(
                              key: const Key('item_sheet_space'),
                              borderRadius: BorderRadius.circular(
                                AppConstants.inputBorderRadius,
                              ),
                              onTap: () => _pickSpace(spaces),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: context.spacingSm,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(spaceName, style: textTheme.bodyLarge),
                                    Icon(
                                      Icons.chevron_right,
                                      size: context.iconSizeMd,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        DsSectionTitle('items.details_label'.tr()),
                        TextFormField(
                          key: const Key('item_sheet_note'),
                          controller: _noteController,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: dsFieldDecoration(
                            context,
                            hintText: 'items.add_note'.tr(),
                          ),
                        ),
                        if (footnote != null)
                          Padding(
                            padding: EdgeInsets.only(top: context.spacingMd),
                            child: Text(
                              footnote,
                              style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        SizedBox(height: context.spacingLg),
                        DsButton(
                          key: const Key('item_sheet_save'),
                          label: widget.submitLabel ?? 'common.save'.tr(),
                          icon: widget.submitIcon,
                          expand: true,
                          isLoading: _isSaving,
                          onPressed: _save,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etichetta come [DsSectionTitle] con il controllo sulla stessa riga, a
/// destra: per i valori brevi (quantità, spazio) che non chiedono un campo.
class _InlineField extends StatelessWidget {
  final String label;
  final Widget child;

  const _InlineField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.spacingLg),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: DsSectionTitle.textStyle(context)),
          ),
          child,
        ],
      ),
    );
  }
}

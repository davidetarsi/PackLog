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

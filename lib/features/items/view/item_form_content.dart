import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../model/item_model.dart';
import '../providers/item_provider.dart';
import '../../houses/providers/house_provider.dart';
import '../../houses/model/house_model.dart';
import '../../spaces/model/space_model.dart';
import '../../spaces/providers/space_provider.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/constants/space_icons.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/universal_action_bar.dart';

/// Form Content riutilizzabile per item (condiviso tra bottom sheet e full screen)
class ItemFormContent extends ConsumerStatefulWidget {
  final String? houseId;
  final String? itemId;
  final String? initialName;
  final ItemCategory? initialCategory;
  final void Function(String itemId, String houseId)? onSaved;
  final bool showButtons;

  const ItemFormContent({
    super.key,
    this.houseId,
    this.itemId,
    this.initialName,
    this.initialCategory,
    this.onSaved,
    this.showButtons = true,
  });

  @override
  ConsumerState<ItemFormContent> createState() => ItemFormContentState();
}

/// Opzione del picker spazio. `id == null` è lo spazio predefinito: non si
/// può usare `null` come valore dell'opzione, perché per [DsPickerSheet]
/// `null` vuol dire "chiuso senza scegliere".
typedef _SpaceOption = ({String? id, String name, IconData icon});

class ItemFormContentState extends ConsumerState<ItemFormContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  ItemCategory _selectedCategory = ItemCategory.vestiti;
  int _selectedQuantity = 1;
  bool _isSaving = false;
  String? _selectedHouseId;
  String? _selectedSpaceId;

  /// Chiamato dal parent sheet via GlobalKey.
  /// Ritorna il record (itemId, houseId) se salvato, null altrimenti.
  Future<({String itemId, String houseId})?> save() => _saveItem();

  /// Espone il nome corrente dell'item (per dialog conferma elimina)
  String get itemName => _nameController.text.trim();

  static const List<int> _quantityOptions = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    15,
    20,
    25,
    50,
    100,
  ];

  @override
  void initState() {
    super.initState();
    _selectedHouseId = widget.houseId;
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.itemId != null && widget.houseId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadItem();
      });
    }
  }

  Future<void> _loadItem() async {
    if (_selectedHouseId == null) return;
    final itemsAsync = ref.read(itemNotifierProvider(_selectedHouseId!));
    itemsAsync.whenData((items) {
      final matchingItems = items.where((i) => i.id == widget.itemId);
      if (matchingItems.isEmpty) return;

      final item = matchingItems.first;
      setState(() {
        _nameController.text = item.name;
        _descriptionController.text = item.description ?? '';
        _selectedQuantity = item.quantity ?? 1;
        _selectedCategory = item.category;
        _selectedSpaceId = item.spaceId;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _showQuantityPicker() async {
    final selected = await DsPickerSheet.show<int>(
      context: context,
      title: 'common.select_quantity'.tr(),
      items: _quantityOptions,
      getLabel: (q) => q.toString(),
      selected: _selectedQuantity,
    );
    if (selected != null) {
      setState(() => _selectedQuantity = selected);
    }
  }

  Future<({String itemId, String houseId})?> _saveItem() async {
    if (!_formKey.currentState!.validate()) return null;
    if (_selectedHouseId == null) {
      AppSnackBar.showWarning(context, 'common.select_house'.tr());
      return null;
    }

    final now = DateTime.now();
    final quantity = _selectedQuantity;
    final houseId = _selectedHouseId!;
    final itemId = widget.itemId ?? const Uuid().v4();

    final item = widget.itemId != null
        ? (() {
            final itemsAsync = ref.read(itemNotifierProvider(houseId));
            final items = itemsAsync.value;
            if (items == null) {
              throw StateError('Oggetto non trovato');
            }
            return items
                .firstWhere((i) => i.id == widget.itemId)
                .copyWith(
                  name: _nameController.text.trim(),
                  description: _descriptionController.text.trim().isEmpty
                      ? null
                      : _descriptionController.text.trim(),
                  category: _selectedCategory,
                  quantity: quantity,
                  spaceId: _selectedSpaceId,
                  updatedAt: now,
                );
          })()
        : ItemModel(
            id: itemId,
            houseId: houseId,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            category: _selectedCategory,
            quantity: quantity,
            spaceId: _selectedSpaceId,
            createdAt: now,
            updatedAt: now,
          );

    final isEditing = widget.itemId != null;
    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () async {
        if (isEditing) {
          await ref
              .read(itemNotifierProvider(houseId).notifier)
              .updateItem(item);
        } else {
          await ref.read(itemNotifierProvider(houseId).notifier).addItem(item);
        }
      },
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: isEditing
          ? 'errors.save_item_failed'.tr()
          : 'errors.create_item_failed'.tr(),
    );

    if (!success) return null;
    return (itemId: item.id, houseId: houseId);
  }

  @override
  Widget build(BuildContext context) {
    final housesAsync = ref.watch(houseNotifierProvider);
    // Only show the space selector when the selected house has user-created
    // spaces. Houses with only the implicit default space get no selector.
    final hasSpaces =
        _selectedHouseId != null &&
        (ref
                .watch(spaceNotifierProvider(_selectedHouseId!))
                .valueOrNull
                ?.isNotEmpty ??
            false);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: context.spacingMd),
          TextFormField(
            controller: _nameController,
            autofocus: widget.houseId != null,
            decoration: InputDecoration(
              labelText: 'items.name_label'.tr(),
              border: OutlineInputBorder(
                borderRadius: context.responsiveBorderRadius(
                  AppConstants.inputBorderRadius,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'common.name_required_validation'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: context.spacingMd),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<ItemCategory>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'items.category_label'.tr(),
                    border: OutlineInputBorder(
                      borderRadius: context.responsiveBorderRadius(
                        AppConstants.inputBorderRadius,
                      ),
                    ),
                  ),
                  items: ItemCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
              ),
              SizedBox(width: context.spacingSm + 4),
              Expanded(
                child: InkWell(
                  borderRadius: context.responsiveBorderRadius(
                    AppConstants.inputBorderRadius,
                  ),
                  onTap: _showQuantityPicker,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'items.quantity_label'.tr(),
                      border: OutlineInputBorder(
                        borderRadius: context.responsiveBorderRadius(
                          AppConstants.inputBorderRadius,
                        ),
                      ),
                    ),
                    child: Text(
                      _selectedQuantity.toString(),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacingMd),
          housesAsync.when(
            data: (houses) => _buildHouseSelector(houses),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('${'common.error'.tr()}: $e'),
          ),
          SizedBox(height: context.spacingMd),
          if (hasSpaces) ...[
            _buildSpaceSelector(),
            SizedBox(height: context.spacingMd),
          ],
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'items.description_label'.tr(),
              border: OutlineInputBorder(
                borderRadius: context.responsiveBorderRadius(
                  AppConstants.inputBorderRadius,
                ),
              ),
            ),
            maxLines: 2,
          ),
          if (widget.showButtons) ...[
            AppSpacing.gapXl,
            UniversalActionBar(
              primaryLabel: widget.itemId != null
                  ? 'common.save'.tr()
                  : 'common.create'.tr(),
              isLoading: _isSaving,
              onPrimaryPressed: _isSaving
                  ? null
                  : () async {
                      setState(() => _isSaving = true);
                      final result = await _saveItem();
                      if (mounted) {
                        setState(() => _isSaving = false);
                        if (result != null) {
                          widget.onSaved?.call(result.itemId, result.houseId);
                        }
                      }
                    },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHouseSelector(List<HouseModel> houses) {
    if (houses.isEmpty) {
      return Container(
        padding: context.responsiveScreenPadding,
        decoration: BoxDecoration(
          border: Border.all(color: context.appColors.warning),
          borderRadius: context.responsiveBorderRadius(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: context.appColors.warning,
              size: context.iconSizeMd,
            ),
            SizedBox(width: context.spacingSm),
            Expanded(
              child: Text(
                'items.no_houses_available'.tr(),
                style: TextStyle(color: context.appColors.warning),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      borderRadius: context.responsiveBorderRadius(
        AppConstants.inputBorderRadius,
      ),
      onTap: () => _showHousePicker(houses),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'items.house_label'.tr(),
          border: OutlineInputBorder(
            borderRadius: context.responsiveBorderRadius(
              AppConstants.inputBorderRadius,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedHouseId != null
                  ? houses
                        .firstWhere(
                          (h) => h.id == _selectedHouseId,
                          orElse: () => houses.first,
                        )
                        .displayName
                  : 'items.select_house_prompt'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: _selectedHouseId == null ? context.textDisabled : null,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: context.iconSizeMd),
          ],
        ),
      ),
    );
  }

  Future<void> _showHousePicker(List<HouseModel> houses) async {
    final selected = await DsPickerSheet.show<HouseModel>(
      context: context,
      title: 'common.select_house'.tr(),
      items: houses,
      getLabel: (h) => h.displayName,
      getSubtitle: (h) => h.description,
      getIcon: (_) => Icons.home_outlined,
      selected: houses.where((h) => h.id == _selectedHouseId).firstOrNull,
    );
    if (selected != null) {
      setState(() {
        _selectedHouseId = selected.id;
        _selectedSpaceId = null;
      });
    }
  }

  Widget _buildSpaceSelector() {
    final spacesAsync = ref.watch(spaceNotifierProvider(_selectedHouseId!));

    return spacesAsync.when(
      data: (spaces) {
        return InkWell(
          borderRadius: context.responsiveBorderRadius(
            AppConstants.inputBorderRadius,
          ),
          onTap: () => _showSpacePicker(spaces),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'items.space_label'.tr(),
              border: OutlineInputBorder(
                borderRadius: context.responsiveBorderRadius(
                  AppConstants.inputBorderRadius,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedSpaceId != null
                      ? spaces
                            .firstWhere(
                              (s) => s.id == _selectedSpaceId,
                              orElse: () => spaces.first,
                            )
                            .name
                      : 'spaces.default'.tr(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Icon(Icons.arrow_drop_down, size: context.iconSizeMd),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Future<void> _showSpacePicker(List<SpaceModel> spaces) async {
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

    final selected = await DsPickerSheet.show<_SpaceOption>(
      context: context,
      title: 'items.select_space'.tr(),
      items: options,
      getLabel: (o) => o.name,
      getIcon: (o) => o.icon,
      selected: options.firstWhere(
        (o) => o.id == _selectedSpaceId,
        orElse: () => options.first,
      ),
    );
    if (selected != null) {
      setState(() => _selectedSpaceId = selected.id);
    }
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../model/item_model.dart';
import '../providers/item_provider.dart';
import '../../houses/providers/house_provider.dart';
import '../../houses/model/house_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/error_retry_dialog.dart';

/// Form Content riutilizzabile per item (condiviso tra bottom sheet e full screen)
class ItemFormContent extends ConsumerStatefulWidget {
  final String? houseId;
  final String? itemId;
  final void Function(String itemId, String houseId) onSaved;

  const ItemFormContent({
    super.key,
    this.houseId,
    this.itemId,
    required this.onSaved,
  });

  @override
  ConsumerState<ItemFormContent> createState() => _ItemFormContentState();
}

class _ItemFormContentState extends ConsumerState<ItemFormContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  ItemCategory _selectedCategory = ItemCategory.vestiti;
  int _selectedQuantity = 1;
  bool _isLoading = false;
  String? _selectedHouseId;

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

  bool get _needsHouseSelection => widget.houseId == null;

  @override
  void initState() {
    super.initState();
    _selectedHouseId = widget.houseId;
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
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'common.select_quantity'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _quantityOptions.length,
              itemBuilder: (context, index) {
                final quantity = _quantityOptions[index];
                return ListTile(
                  title: Text(quantity.toString()),
                  trailing: _selectedQuantity == quantity
                      ? const Icon(Icons.check, color: AppColors.success)
                      : null,
                  onTap: () => Navigator.pop(context, quantity),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
    if (selected != null) {
      setState(() => _selectedQuantity = selected);
    }
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedHouseId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('common.select_house'.tr())));
        return;
      }

      setState(() => _isLoading = true);

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
              createdAt: now,
              updatedAt: now,
            );

      final isEditing = widget.itemId != null;
      final success = await ErrorRetryDialog.executeWithRetry(
        context: context,
        operation: () async {
          if (isEditing) {
            await ref.read(itemNotifierProvider(houseId).notifier).updateItem(item);
          } else {
            await ref.read(itemNotifierProvider(houseId).notifier).addItem(item);
          }
        },
        errorTitle: 'errors.save_error'.tr(),
        errorMessage: isEditing
            ? 'errors.save_item_failed'.tr()
            : 'errors.create_item_failed'.tr(),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          widget.onSaved(item.id, houseId);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final housesAsync = ref.watch(houseNotifierProvider);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_needsHouseSelection) ...[
            housesAsync.when(
              data: (houses) => _buildHouseSelector(houses),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('${' common.error'.tr()}: $e'),
            ),
            SizedBox(height: context.spacingMd),
          ],
          TextFormField(
            controller: _nameController,
            autofocus: !_needsHouseSelection,
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
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveItem,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: context.spacingMd),
              shape: RoundedRectangleBorder(
                borderRadius: context.responsiveBorderRadius(
                  AppConstants.inputBorderRadius,
                ),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    height: context.responsive(20),
                    width: context.responsive(20),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.itemId != null ? 'common.save'.tr() : 'common.create'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseSelector(List<HouseModel> houses) {
    if (houses.isEmpty) {
      return Container(
        padding: context.responsiveScreenPadding,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.warning),
          borderRadius: context.responsiveBorderRadius(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: AppColors.warning,
              size: context.iconSizeMd,
            ),
            SizedBox(width: context.spacingSm),
            Expanded(
              child: Text(
                'items.no_houses_available'.tr(),
                style: TextStyle(color: AppColors.warning),
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
                        .name
                  : 'items.select_house_prompt'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: _selectedHouseId == null ? AppColors.disabled : null,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: context.iconSizeMd),
          ],
        ),
      ),
    );
  }

  Future<void> _showHousePicker(List<HouseModel> houses) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: sheetContext.responsiveScreenPadding,
            child: Text(
              'common.select_house'.tr(),
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: houses.length,
              itemBuilder: (itemContext, index) {
                final house = houses[index];
                return ListTile(
                  leading: Icon(Icons.home, size: itemContext.iconSizeMd),
                  title: Text(house.name),
                  subtitle: house.description != null
                      ? Text(house.description!)
                      : null,
                  trailing: _selectedHouseId == house.id
                      ? Icon(
                          Icons.check,
                          color: AppColors.success,
                          size: itemContext.iconSizeMd,
                        )
                      : null,
                  onTap: () => Navigator.pop(itemContext, house.id),
                );
              },
            ),
          ),
          SizedBox(height: sheetContext.spacingMd),
        ],
      ),
    );
    if (selected != null) {
      setState(() => _selectedHouseId = selected);
    }
  }
}

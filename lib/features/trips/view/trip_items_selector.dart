import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../houses/providers/house_provider.dart';
import '../../houses/model/house_model.dart';
import '../../items/providers/item_provider.dart';
import '../../items/model/item_model.dart';
import '../model/trip_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/app_pill_tab.dart';

/// Widget riutilizzabile per selezionare gli oggetti da portare in viaggio.
/// 
/// Contiene:
/// - Filtri per casa e categoria
/// - Lista oggetti con icona, nome, quantità e bottoni +/-
class TripItemsSelector extends ConsumerStatefulWidget {
  /// Oggetti già selezionati
  final List<TripItem> selectedItems;
  
  /// Callback quando la selezione cambia
  final void Function(List<TripItem> items) onSelectionChanged;
  
  /// Se true, il widget si adatta al contenuto (per uso in scroll parent)
  final bool shrinkWrap;

  const TripItemsSelector({
    super.key,
    required this.selectedItems,
    required this.onSelectionChanged,
    this.shrinkWrap = false,
  });

  @override
  ConsumerState<TripItemsSelector> createState() => _TripItemsSelectorState();
}

class _TripItemsSelectorState extends ConsumerState<TripItemsSelector> {
  String? _selectedHouseId;
  ItemCategory? _selectedCategory;
  late List<TripItem> _items;

  // Colore arancione per le icone
  static const Color _accentColor = Colors.orange;
  
  // Lista di opzioni categoria (include "Tutto" = null)
  static final List<_CategoryFilterOption> _categoryOptions = [
    _CategoryFilterOption('common.all'.tr(), null),
    ...ItemCategory.values.map(
      (cat) => _CategoryFilterOption(cat.displayName, cat),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.selectedItems);
  }

  @override
  void didUpdateWidget(covariant TripItemsSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedItems != oldWidget.selectedItems) {
      _items = List.from(widget.selectedItems);
    }
  }

  int _getSelectedQuantity(String itemId) {
    final selected = _items.where((i) => i.id == itemId).firstOrNull;
    return selected?.quantity ?? 0;
  }

  void _updateItemQuantity(ItemModel item, String houseId, int newQuantity) {
    setState(() {
      _items.removeWhere((i) => i.id == item.id);
      if (newQuantity > 0) {
        _items.add(TripItem(
          id: item.id,
          name: item.name,
          category: item.category,
          quantity: newQuantity,
          originHouseId: houseId,
        ));
      }
    });
    widget.onSelectionChanged(_items);
  }

  IconData _getCategoryIcon(ItemCategory category) {
    switch (category) {
      case ItemCategory.vestiti:
        return Icons.checkroom;
      case ItemCategory.toiletries:
        return Icons.shower;
      case ItemCategory.elettronica:
        return Icons.devices;
      case ItemCategory.varie:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final housesAsync = ref.watch(houseNotifierProvider);

    if (widget.shrinkWrap) {
      // Modalità shrinkWrap per embedding in scroll parent
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilters(context, colorScheme, housesAsync),
          SizedBox(height: context.spacingSm),
          _buildItemsListShrinkWrap(context, colorScheme),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilters(context, colorScheme, housesAsync),
        SizedBox(height: context.spacingSm),
        Expanded(
          child: _buildItemsList(context, colorScheme),
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context, ColorScheme colorScheme, AsyncValue<List<HouseModel>> housesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filtro casa
        Text(
          'common.select_house'.tr(),
          style: TextStyle(
            fontSize: context.fontSizeSm,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: context.spacingXs),
        SizedBox(
          height: 40,
          child: housesAsync.when(
            data: (houses) {
              // Trova l'house selezionato (può essere null)
              final selectedHouse = houses.cast<HouseModel?>().firstWhere(
                (h) => h?.id == _selectedHouseId,
                orElse: () => null,
              );
              
              return AppPillTab<HouseModel>.nullable(
                items: houses,
                selectedItem: selectedHouse,
                getLabel: (house) => house.name,
                getIcon: (house) => Icon(Icons.home_outlined, size: 16),
                onSelected: (house) {
                  setState(() {
                    _selectedHouseId = house?.id;
                  });
                },
                // Rimosso selectedColor per usare il theme default
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('${'common.error'.tr()}: $e'),
          ),
        ),
        
        SizedBox(height: context.spacingMd),
        
        // Filtro categoria
        Text(
          'common.category'.tr(),
          style: TextStyle(
            fontSize: context.fontSizeSm,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: context.spacingXs),
        SizedBox(
          height: 40,
          child: AppPillTab<_CategoryFilterOption>(
            items: _categoryOptions,
            selectedItem: _categoryOptions.firstWhere(
              (opt) => opt.category == _selectedCategory,
            ),
            getLabel: (opt) => opt.label,
            onSelected: (opt) {
              setState(() {
                _selectedCategory = opt.category;
              });
            },
            // Rimossi tutti i colori custom per usare il theme default
          ),
        ),
      ],
    );
  }


  Widget _buildItemsList(BuildContext context, ColorScheme colorScheme) {
    if (_selectedHouseId == null) {
      return _buildEmptyHouseState(context);
    }

    final itemsAsync = ref.watch(itemNotifierProvider(_selectedHouseId!));

    return itemsAsync.when(
      data: (items) {
        final filteredItems = _selectedCategory == null
            ? items
            : items.where((i) => i.category == _selectedCategory).toList();

        if (filteredItems.isEmpty) {
          return _buildEmptyItemsState(context);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 120), // Spazio per floating bar
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return _buildItemCard(context, colorScheme, item);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${'common.error'.tr()}: $e')),
    );
  }

  Widget _buildItemsListShrinkWrap(BuildContext context, ColorScheme colorScheme) {
    if (_selectedHouseId == null) {
      // In shrinkWrap mode, NO SingleChildScrollView - il parent gestisce lo scroll
      return _buildEmptyHouseStateShrinkWrap(context);
    }

    final itemsAsync = ref.watch(itemNotifierProvider(_selectedHouseId!));

    return itemsAsync.when(
      data: (items) {
        final filteredItems = _selectedCategory == null
            ? items
            : items.where((i) => i.category == _selectedCategory).toList();

        if (filteredItems.isEmpty) {
          // In shrinkWrap mode, NO SingleChildScrollView - il parent gestisce lo scroll
          return _buildEmptyItemsStateShrinkWrap(context);
        }

        // Usa Column invece di ListView per shrinkWrap
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...filteredItems.map((item) => 
              _buildItemCard(context, colorScheme, item)
            ),
          ],
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.all(context.spacingLg),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: EdgeInsets.all(context.spacingLg),
        child: Center(child: Text('${'common.error'.tr()}: $e')),
      ),
    );
  }

  /// Stato vuoto casa - versione shrinkWrap (NO scroll interno)
  Widget _buildEmptyHouseStateShrinkWrap(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacingLg),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.home_outlined,
              size: context.iconSizeHero,
              color: _accentColor.withValues(alpha: 0.5),
            ),
            SizedBox(height: context.spacingMd),
            Text(
              'trips.select_house_to_view_items'.tr(),
              style: TextStyle(
                color: AppColors.disabled,
                fontSize: context.fontSizeMd,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Stato vuoto items - versione shrinkWrap (NO scroll interno)
  Widget _buildEmptyItemsStateShrinkWrap(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacingLg),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: context.iconSizeHero,
              color: _accentColor.withValues(alpha: 0.5),
            ),
            SizedBox(height: context.spacingMd),
            Text(
              _selectedCategory == null
                  ? 'common.no_items_in_house'.tr()
                  : 'common.no_items_in_category'.tr(namedArgs: {'category': _selectedCategory!.displayName}),
              style: TextStyle(
                color: AppColors.disabled,
                fontSize: context.fontSizeMd,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHouseState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacingLg),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.home_outlined,
                size: context.iconSizeHero,
                color: _accentColor.withValues(alpha: 0.5),
              ),
              SizedBox(height: context.spacingMd),
              Text(
                'trips.select_house_to_view_items'.tr(),
                style: TextStyle(
                  color: AppColors.disabled,
                  fontSize: context.fontSizeMd,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyItemsState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacingLg),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: context.iconSizeHero,
                color: _accentColor.withValues(alpha: 0.5),
              ),
              SizedBox(height: context.spacingMd),
              Text(
                _selectedCategory == null
                    ? 'common.no_items_in_house'.tr()
                    : 'common.no_items_in_category'.tr(namedArgs: {'category': _selectedCategory!.displayName}),
                style: TextStyle(
                  color: AppColors.disabled,
                  fontSize: context.fontSizeMd,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, ColorScheme colorScheme, ItemModel item) {
    final selectedQuantity = _getSelectedQuantity(item.id);
    final maxQuantity = item.quantity ?? 1;
    final isSelected = selectedQuantity > 0;

    return Card(
      margin: EdgeInsets.only(bottom: context.spacingSm),
      shape: RoundedRectangleBorder(
        borderRadius: context.responsiveBorderRadius(AppConstants.cardBorderRadius),
        side: BorderSide(
          color: isSelected 
              ? _accentColor.withValues(alpha: 0.5)
              : colorScheme.outline.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected 
          ? _accentColor.withValues(alpha: 0.1)
          : colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(context.spacingSm),
        child: Row(
          children: [
            // Icona categoria
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: context.responsiveBorderRadius(12),
              ),
              child: Icon(
                _getCategoryIcon(item.category),
                color: _accentColor,
              ),
            ),
            
            SizedBox(width: context.spacingSm),
            
            // Nome
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: context.fontSizeMd,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'common.available_quantity'.tr(args: [maxQuantity.toString()]),
                    style: TextStyle(
                      fontSize: context.fontSizeSm,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            
            // Controlli quantità
            if (maxQuantity == 1)
              // Checkbox per quantità singola
              Checkbox(
                value: isSelected,
                activeColor: _accentColor,
                onChanged: (_) {
                  _updateItemQuantity(
                    item, 
                    _selectedHouseId!, 
                    isSelected ? 0 : 1,
                  );
                },
              )
            else
              // Bottoni +/- per quantità multiple
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: selectedQuantity > 0 
                          ? _accentColor 
                          : colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    onPressed: selectedQuantity > 0
                        ? () => _updateItemQuantity(
                            item, 
                            _selectedHouseId!, 
                            selectedQuantity - 1,
                          )
                        : null,
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      '$selectedQuantity',
                      style: TextStyle(
                        fontSize: context.fontSizeLg,
                        fontWeight: FontWeight.bold,
                        color: isSelected 
                            ? _accentColor 
                            : colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: selectedQuantity < maxQuantity 
                          ? _accentColor 
                          : colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    onPressed: selectedQuantity < maxQuantity
                        ? () => _updateItemQuantity(
                            item, 
                            _selectedHouseId!, 
                            selectedQuantity + 1,
                          )
                        : null,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Helper class per rappresentare un'opzione di filtro categoria.
/// Wrappa ItemCategory? per essere usata con AppPillTab.
class _CategoryFilterOption {
  final String label;
  final ItemCategory? category;

  const _CategoryFilterOption(this.label, this.category);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CategoryFilterOption &&
          runtimeType == other.runtimeType &&
          category == other.category;

  @override
  int get hashCode => category.hashCode;
}

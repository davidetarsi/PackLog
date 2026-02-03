import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/houses/providers/house_provider.dart';
import '../../features/houses/model/house_model.dart';
import '../../features/items/providers/item_provider.dart';
import '../../features/items/model/item_model.dart';
import '../../features/trips/model/trip_model.dart';
import '../constants/app_constants.dart';
import '../theme/theme.dart';

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
          category: item.category.displayName,
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
          'Seleziona casa',
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
            data: (houses) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                children: houses.map((house) {
                  final isSelected = _selectedHouseId == house.id;
                  return Padding(
                    padding: EdgeInsets.only(right: context.spacingSm),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: context.responsiveBorderRadius(20),
                        onTap: () {
                          setState(() {
                            _selectedHouseId = isSelected ? null : house.id;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            horizontal: context.spacingMd,
                            vertical: context.spacingSm,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _accentColor
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: context.responsiveBorderRadius(20),
                            border: Border.all(
                              color: isSelected
                                  ? _accentColor
                                  : colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.home_outlined,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : _accentColor,
                              ),
                              SizedBox(width: context.spacingXs),
                              Text(
                                house.name,
                                style: TextStyle(
                                  fontSize: context.fontSizeMd,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Errore: $e'),
          ),
        ),
        
        SizedBox(height: context.spacingMd),
        
        // Filtro categoria
        Text(
          'Categoria',
          style: TextStyle(
            fontSize: context.fontSizeSm,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: context.spacingXs),
        SizedBox(
          height: 40,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: [
                _buildCategoryChip(context, colorScheme, null, 'Tutto'),
                ...ItemCategory.values.map((cat) => 
                  _buildCategoryChip(context, colorScheme, cat, cat.displayName),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(BuildContext context, ColorScheme colorScheme, ItemCategory? category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: EdgeInsets.only(right: context.spacingSm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: context.responsiveBorderRadius(20),
          onTap: () {
            setState(() {
              _selectedCategory = category;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: context.spacingMd,
              vertical: context.spacingSm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? _accentColor.withValues(alpha: 0.2)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: context.responsiveBorderRadius(20),
              border: Border.all(
                color: isSelected
                    ? _accentColor
                    : colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: context.fontSizeMd,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? _accentColor
                    : colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ),
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
      error: (e, _) => Center(child: Text('Errore: $e')),
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
        child: Center(child: Text('Errore: $e')),
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
              'Seleziona una casa per vedere gli oggetti',
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
                  ? 'Nessun oggetto in questa casa'
                  : 'Nessun oggetto in "${_selectedCategory!.displayName}"',
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
                'Seleziona una casa per vedere gli oggetti',
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
                    ? 'Nessun oggetto in questa casa'
                    : 'Nessun oggetto in "${_selectedCategory!.displayName}"',
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
                    'Disponibili: $maxQuantity',
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

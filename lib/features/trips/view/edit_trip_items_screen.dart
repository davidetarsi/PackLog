import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../../houses/providers/house_provider.dart';
import '../../houses/model/house_model.dart';
import '../../items/providers/item_provider.dart';
import '../../items/model/item_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';

/// Schermata per modificare solo gli oggetti del viaggio.
class EditTripItemsScreen extends ConsumerStatefulWidget {
  final String tripId;

  const EditTripItemsScreen({super.key, required this.tripId});

  @override
  ConsumerState<EditTripItemsScreen> createState() => _EditTripItemsScreenState();
}

class _EditTripItemsScreenState extends ConsumerState<EditTripItemsScreen> {
  bool _isLoading = false;
  TripModel? _trip;
  List<TripItem> _selectedItems = [];
  String? _selectedHouseId;
  ItemCategory? _selectedCategory;

  static const Color _accentColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  void _loadTrip() {
    final tripsAsync = ref.read(tripNotifierProvider);
    tripsAsync.whenData((trips) {
      final trip = trips.where((t) => t.id == widget.tripId).firstOrNull;
      if (trip != null) {
        setState(() {
          _trip = trip;
          _selectedItems = List.from(trip.items);
        });
      }
    });
  }

  Future<void> _saveChanges() async {
    if (_trip == null) return;

    setState(() => _isLoading = true);

    final updatedTrip = _trip!.copyWith(
      items: _selectedItems,
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(tripNotifierProvider.notifier).updateTrip(updatedTrip);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _getSelectedQuantity(String itemId) {
    final selected = _selectedItems.where((i) => i.id == itemId).firstOrNull;
    return selected?.quantity ?? 0;
  }

  void _updateItemQuantity(ItemModel item, String houseId, int newQuantity) {
    setState(() {
      _selectedItems.removeWhere((i) => i.id == item.id);
      if (newQuantity > 0) {
        _selectedItems.add(TripItem(
          id: item.id,
          name: item.name,
          category: item.category.displayName,
          quantity: newQuantity,
          originHouseId: houseId,
        ));
      }
    });
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

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modifica oggetti')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifica oggetti'),
        actions: [
          Center(
            child: Container(
              margin: EdgeInsets.only(right: context.spacingMd),
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingSm,
                vertical: context.spacingXs,
              ),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: context.responsiveBorderRadius(12),
              ),
              child: Text(
                '${_selectedItems.length} oggetti',
                style: TextStyle(
                  fontSize: context.fontSizeSm,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Contenuto scrollabile
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                left: context.spacingSm,
                right: context.spacingSm,
                top: context.spacingSm,
                bottom: 130, // Spazio per il bottone fisso
              ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filtri
                _buildFilters(context, colorScheme, housesAsync),
                SizedBox(height: context.spacingMd),
                // Items
                _buildItemsContent(context, colorScheme),
              ],
            ),
          ),
          
          // Bottone fisso in basso
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(context.spacingMd),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: _buildSaveButton(context, colorScheme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, ColorScheme colorScheme, AsyncValue<List<HouseModel>> housesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                            color: isSelected ? _accentColor : colorScheme.surfaceContainerHighest,
                            borderRadius: context.responsiveBorderRadius(20),
                            border: Border.all(
                              color: isSelected ? _accentColor : colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.home_outlined,
                                size: 16,
                                color: isSelected ? Colors.white : _accentColor,
                              ),
                              SizedBox(width: context.spacingXs),
                              Text(
                                house.name,
                                style: TextStyle(
                                  fontSize: context.fontSizeMd,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.8),
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
          onTap: () => setState(() => _selectedCategory = category),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: context.spacingMd,
              vertical: context.spacingSm,
            ),
            decoration: BoxDecoration(
              color: isSelected ? _accentColor.withValues(alpha: 0.2) : colorScheme.surfaceContainerHighest,
              borderRadius: context.responsiveBorderRadius(20),
              border: Border.all(
                color: isSelected ? _accentColor : colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: context.fontSizeMd,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? _accentColor : colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemsContent(BuildContext context, ColorScheme colorScheme) {
    if (_selectedHouseId == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacingXl),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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

    final itemsAsync = ref.watch(itemNotifierProvider(_selectedHouseId!));

    return itemsAsync.when(
      data: (items) {
        final filteredItems = _selectedCategory == null
            ? items
            : items.where((i) => i.category == _selectedCategory).toList();

        if (filteredItems.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacingXl),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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

        // Usa Column, NON ListView - tutto scorre insieme
        return Column(
          children: filteredItems.map((item) => _buildItemCard(context, colorScheme, item)).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text('Errore: $e')),
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
          color: isSelected ? _accentColor.withValues(alpha: 0.5) : colorScheme.outline.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected ? _accentColor.withValues(alpha: 0.1) : colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(context.spacingSm),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: context.responsiveBorderRadius(12),
              ),
              child: Icon(_getCategoryIcon(item.category), color: _accentColor),
            ),
            SizedBox(width: context.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(fontSize: context.fontSizeMd, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Disponibili: $maxQuantity',
                    style: TextStyle(fontSize: context.fontSizeSm, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            if (maxQuantity == 1)
              Checkbox(
                value: isSelected,
                activeColor: _accentColor,
                onChanged: (_) => _updateItemQuantity(item, _selectedHouseId!, isSelected ? 0 : 1),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: selectedQuantity > 0 ? _accentColor : colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    onPressed: selectedQuantity > 0 ? () => _updateItemQuantity(item, _selectedHouseId!, selectedQuantity - 1) : null,
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$selectedQuantity',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.fontSizeLg,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? _accentColor : colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: selectedQuantity < maxQuantity ? _accentColor : colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    onPressed: selectedQuantity < maxQuantity ? () => _updateItemQuantity(item, _selectedHouseId!, selectedQuantity + 1) : null,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(28),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _isLoading ? null : _saveChanges,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colorScheme.primary, width: 2),
          ),
          child: Center(
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, color: colorScheme.onSurfaceVariant),
                      SizedBox(width: context.spacingSm),
                      Text(
                        'Salva oggetti',
                        style: TextStyle(
                          fontSize: context.fontSizeLg,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

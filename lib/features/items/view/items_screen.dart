import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stuff_tracker_2/features/items/view/item_category_section.dart';
import '../providers/item_provider.dart';
import '../model/item_model.dart';
import '../../trips/providers/trip_items_status_provider.dart';
import '../../houses/providers/house_provider.dart';
import '../../spaces/providers/space_provider.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/helpers/design_system.dart';
import 'in_transit_section.dart';

class ItemsScreen extends ConsumerStatefulWidget {
  final String houseId;
  final String houseName;

  const ItemsScreen({
    super.key,
    required this.houseId,
    required this.houseName,
  });

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  String? _selectedSpaceId;

  String _getSpaceFilterLabel(String? spaceId, List spaces, int generalPoolCount, Map<String, int> spaceCounts) {
    if (spaceId == null) {
      return 'spaces.all_items'.tr();
    } else if (spaceId == 'general_pool') {
      return '${'spaces.general_pool'.tr()} ($generalPoolCount)';
    } else {
      final space = spaces.firstWhere((s) => s.id == spaceId);
      return '${space.name} (${spaceCounts[spaceId] ?? 0})';
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemNotifierProvider(widget.houseId));
    final spacesAsync = ref.watch(spacesByHouseProvider(widget.houseId));
    final itemQuantitiesOnTrip = ref.watch(
      itemQuantitiesOnTripFromHouseProvider(widget.houseId),
    );
    final temporaryItems = ref.watch(temporaryItemsInHouseProvider(widget.houseId));
    final housesAsync = ref.watch(houseNotifierProvider);

    return Column(
      children: [
        Expanded(
          child: itemsAsync.when(
            data: (allItems) {
              final hasTemporaryItems = temporaryItems.isNotEmpty;

              return spacesAsync.when(
                data: (spaces) {
                  // Filtra items in base allo spazio selezionato
                  final List<ItemModel> filteredItems;
                  if (_selectedSpaceId == null) {
                    filteredItems = allItems;
                  } else if (_selectedSpaceId == 'general_pool') {
                    filteredItems = allItems.where((item) => item.spaceId == null).toList();
                  } else {
                    filteredItems = allItems.where((item) => item.spaceId == _selectedSpaceId).toList();
                  }

                  if (filteredItems.isEmpty && !hasTemporaryItems && _selectedSpaceId != null) {
                    return EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'items.no_items'.tr(),
                      subtitle: 'items.no_items_in_space'.tr(),
                    );
                  }

                  if (allItems.isEmpty && !hasTemporaryItems) {
                    return EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'items.no_items'.tr(),
                      subtitle: 'items.no_items_subtitle'.tr(),
                    );
                  }

                  // Raggruppa items filtrati per categoria
                  final itemsByCategory = <ItemCategory, List<ItemModel>>{};
                  for (final item in filteredItems) {
                    itemsByCategory.putIfAbsent(item.category, () => []).add(item);
                  }

                  // Calcola conteggi per ogni spazio
                  final spaceCounts = <String, int>{};
                  for (final space in spaces) {
                    spaceCounts[space.id] = allItems.where((item) => item.spaceId == space.id).length;
                  }
                  final generalPoolCount = allItems.where((item) => item.spaceId == null).length;

                  return housesAsync.when(
                    data: (houses) {
                      final colorScheme = Theme.of(context).colorScheme;
                      
                      return Column(
                        children: [
                          // Space Filter Tabs
                          if (spaces.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.only(
                                left: context.spacingMd,
                                top: context.spacingSm,
                                bottom: context.spacingSm,
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    null,
                                    'general_pool',
                                    ...spaces.map((s) => s.id),
                                  ].map((spaceId) {
                                    final isSelected = _selectedSpaceId == spaceId;
                                    final label = _getSpaceFilterLabel(
                                      spaceId,
                                      spaces,
                                      generalPoolCount,
                                      spaceCounts,
                                    );

                                    return Padding(
                                      padding: EdgeInsets.only(right: context.spacingSm),
                                      child: FilterChip(
                                        label: Text(label),
                                        selected: isSelected,
                                        showCheckmark: false,
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedSpaceId = spaceId;
                                          });
                                        },
                                        backgroundColor: Colors.transparent,
                                        selectedColor: colorScheme.primary,
                                        labelStyle: TextStyle(
                                          color: isSelected
                                              ? colorScheme.onPrimary
                                              : colorScheme.onSurface.withValues(alpha: 0.8),
                                        ),
                                        side: BorderSide(
                                          color: isSelected
                                              ? colorScheme.primary
                                              : colorScheme.outline.withValues(alpha: 0.3),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                          Expanded(
                            child: ListView(
                              padding: context.responsiveScreenPadding,
                              children: [
                                // Sezione items temporanei (da viaggi attivi)
                                if (hasTemporaryItems && _selectedSpaceId == null) ...[
                                  InTransitSection(
                                    items: temporaryItems,
                                    houses: houses,
                                  ),
                                  SizedBox(height: context.spacingMd),
                                ],
                                if (itemsByCategory.isNotEmpty) ...[
                                  SizedBox(height: context.spacingSm),
                                  Text(
                                    'common.at_house'.tr(),
                                    style: TextStyle(
                                      fontSize: context.fontSizeLg,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: context.spacingSm),
                                  // Items raggruppati per categoria
                                  ...itemsByCategory.entries.map((entry) {
                                    final category = entry.key;
                                    final categoryItems = entry.value;

                                    return ItemCategorySection(
                                      category: category,
                                      items: categoryItems,
                                      houseId: widget.houseId,
                                      itemQuantitiesOnTrip: itemQuantitiesOnTrip,
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Text('common.error_loading_houses'.tr(namedArgs: {'error': error.toString()})),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => const SizedBox.shrink(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => ErrorState(
              error: error,
              onRetry: () => ref.read(itemNotifierProvider(widget.houseId).notifier).refresh(widget.houseId),
            ),
          ),
        ),
      ],
    );
  }

}

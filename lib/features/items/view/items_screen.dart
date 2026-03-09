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
import '../../../shared/widgets/app_pill_tab.dart';
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
                  // Verifica se lo spazio selezionato esiste ancora
                  // (potrebbe essere stato eliminato)
                  if (_selectedSpaceId != null && 
                      _selectedSpaceId != 'default' && 
                      !spaces.any((s) => s.id == _selectedSpaceId)) {
                    // Spazio eliminato: resetta a "tutti gli items"
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _selectedSpaceId = null);
                      }
                    });
                  }
                  
                  // Filtra items in base allo spazio selezionato
                  final List<ItemModel> filteredItems;
                  if (_selectedSpaceId == null) {
                    filteredItems = allItems;
                  } else if (_selectedSpaceId == 'default') {
                    filteredItems = allItems.where((item) => item.spaceId == null).toList();
                  } else {
                    filteredItems = allItems.where((item) => item.spaceId == _selectedSpaceId).toList();
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
                      // Crea lista tabs: All Items + Default + Spaces
                      final List<String?> tabItems = [
                        null, // All items
                        'default', // Default space
                        ...spaces.map((s) => s.id),
                      ];
                      
                      return Column(
                        children: [
                          // Space Filter Tabs (usa AppPillTab per coerenza)
                          if (spaces.isNotEmpty) ...[
                            Padding(
                              padding: EdgeInsets.only(
                                left: context.spacingMd,
                                top: context.spacingSm,
                                bottom: context.spacingSm,
                              ),
                              child: AppPillTab<String?>.nullable(
                                items: tabItems,
                                selectedItem: _selectedSpaceId,
                                getLabel: (spaceId) {
                                if (spaceId == null) {
                                  return 'spaces.all_items'.tr();
                                } else if (spaceId == 'default') {
                                  return '${'spaces.default'.tr()} ($generalPoolCount)';
                                  } else {
                                    final space = spaces.firstWhere((s) => s.id == spaceId);
                                    return '${space.name} (${spaceCounts[spaceId] ?? 0})';
                                  }
                                },
                                onSelected: (String? spaceId) {
                                  setState(() {
                                    _selectedSpaceId = spaceId;
                                  });
                                },
                                scrollPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                          Expanded(
                            child: () {
                              // Mostra empty state se nessun item filtrato
                              if (filteredItems.isEmpty && !hasTemporaryItems) {
                                return EmptyState(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'items.no_items'.tr(),
                                  subtitle: _selectedSpaceId != null
                                      ? 'items.no_items_in_space'.tr()
                                      : 'items.no_items_subtitle'.tr(),
                                );
                              }
                              
                              return ListView(
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
                              );
                            }(),
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

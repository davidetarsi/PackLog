import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stuff_tracker_2/features/items/view/item_category_section.dart';
import '../providers/item_provider.dart';
import '../model/item_model.dart';
import '../../trips/providers/trip_items_status_provider.dart';
import '../../houses/providers/house_provider.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/helpers/design_system.dart';
import 'in_transit_section.dart';

class ItemsScreen extends ConsumerWidget {
  final String houseId;
  final String houseName;

  const ItemsScreen({
    super.key,
    required this.houseId,
    required this.houseName,
  });


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemNotifierProvider(houseId));
    final itemQuantitiesOnTrip = ref.watch(
      itemQuantitiesOnTripFromHouseProvider(houseId),
    );
    final temporaryItems = ref.watch(temporaryItemsInHouseProvider(houseId));
    final housesAsync = ref.watch(houseNotifierProvider);

    return Column(
      children: [
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              final hasTemporaryItems = temporaryItems.isNotEmpty;

              if (items.isEmpty && !hasTemporaryItems) {
                return EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'items.no_items'.tr(),
                  subtitle: 'items.no_items_subtitle'.tr(),
                );
              }

              // Raggruppa per categoria
              final itemsByCategory = <ItemCategory, List<ItemModel>>{};
              for (final item in items) {
                itemsByCategory.putIfAbsent(item.category, () => []).add(item);
              }

              return housesAsync.when(
                data: (houses) {
                  return ListView(
                    padding: context.responsiveScreenPadding,
                    children: [
                      // Sezione items temporanei (da viaggi attivi) - COLLASSABILE
                      if (hasTemporaryItems) ...[
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
                      // Items normali raggruppati per categoria - COLLASSABILI
                      ...itemsByCategory.entries.map((entry) {
                        final category = entry.key;
                        final categoryItems = entry.value;

                        return ItemCategorySection(
                          category: category,
                          items: categoryItems,
                          houseId: houseId,
                          itemQuantitiesOnTrip: itemQuantitiesOnTrip,
                        );
                      }),
                    ],],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text('common.error_loading_houses'.tr(namedArgs: {'error': error.toString()})),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => ErrorState(
              error: error,
              onRetry: () => ref.read(itemNotifierProvider(houseId).notifier).refresh(houseId),
            ),
          ),
        ),
      ],
    );
  }

}

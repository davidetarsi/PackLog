import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/features/items/view/item_category_section.dart';
import '../../../shared/widgets/skeleton/skeleton.dart';

import '../providers/item_provider.dart';
import '../model/item_model.dart';
import '../../trips/providers/trip_items_status_provider.dart';
import '../../trips/providers/trip_provider.dart';
import '../../houses/providers/house_provider.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/helpers/design_system.dart';
import 'in_transit_section.dart';
import 'item_card.dart';

/// Body della house detail: lista item filtrata per spazio e/o categoria.
///
/// Lo stato dei filtri vive nel parent ([HouseDetailScreen]) che passa:
/// - [selectedSpaceId]: null = tutti, 'default' = pool generale, spaceId = spazio specifico
/// - [categoryFilter]: null = tutte le categorie con sezioni, altrimenti lista piatta
class ItemsScreen extends ConsumerStatefulWidget {
  final String houseId;
  final String houseName;
  final String? selectedSpaceId;
  final ItemCategory? categoryFilter;

  const ItemsScreen({
    super.key,
    required this.houseId,
    required this.houseName,
    this.selectedSpaceId,
    this.categoryFilter,
  });

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(tripNotifierProvider);
    });
  }

  Future<void> _onRefresh() => Future.wait([
    ref.refresh(itemNotifierProvider(widget.houseId).future),
    ref.refresh(tripNotifierProvider.future),
  ]);

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemNotifierProvider(widget.houseId));
    final itemQuantitiesOnTrip = ref.watch(
      itemQuantitiesOnTripFromHouseProvider(widget.houseId),
    );
    final temporaryItems = ref.watch(
      temporaryItemsInHouseProvider(widget.houseId),
    );
    final housesAsync = ref.watch(houseNotifierProvider);

    return Column(
      children: [
        Expanded(
          child: itemsAsync.when(
            data: (allItems) {
              final hasTemporaryItems = temporaryItems.isNotEmpty;

              // ── Filtro per spazio ─────────────────────────────────────────
              final List<ItemModel> spaceFiltered;
              if (widget.selectedSpaceId == null) {
                spaceFiltered = allItems;
              } else if (widget.selectedSpaceId == 'default') {
                spaceFiltered = allItems
                    .where((i) => i.spaceId == null)
                    .toList();
              } else {
                spaceFiltered = allItems
                    .where((i) => i.spaceId == widget.selectedSpaceId)
                    .toList();
              }

              // ── Vista per singola categoria (lista piatta) ────────────────
              if (widget.categoryFilter != null) {
                final categoryItems = spaceFiltered
                    .where((i) => i.category == widget.categoryFilter)
                    .toList();

                if (categoryItems.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: Theme.of(context).colorScheme.primary,
                    child: LayoutBuilder(
                      builder: (_, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: DsEmptyState(
                            icon: widget.categoryFilter!.icon,
                            title: 'items.no_items'.tr(),
                            subtitle: widget.selectedSpaceId != null
                                ? 'items.no_items_in_space'.tr()
                                : 'items.no_items_subtitle'.tr(),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: Theme.of(context).colorScheme.primary,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          context.spacingMd,
                          context.spacingMd,
                          context.spacingMd,
                          0,
                        ),
                        sliver: SliverList.builder(
                          itemCount: categoryItems.length,
                          itemBuilder: (context, index) => ItemCard(
                            item: categoryItems[index],
                            houseId: widget.houseId,
                            quantityOnTrip:
                                itemQuantitiesOnTrip[categoryItems[index].id] ??
                                0,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: context.spacingMd),
                      ),
                    ],
                  ),
                );
              }

              // ── Vista tutte le categorie con sezioni ──────────────────────
              final itemsByCategory = <ItemCategory, List<ItemModel>>{};
              for (final item in spaceFiltered) {
                itemsByCategory.putIfAbsent(item.category, () => []).add(item);
              }

              if (spaceFiltered.isEmpty && !hasTemporaryItems) {
                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: Theme.of(context).colorScheme.primary,
                  child: LayoutBuilder(
                    builder: (_, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: constraints.maxHeight,
                        child: DsEmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'items.no_items'.tr(),
                          subtitle: widget.selectedSpaceId != null
                              ? 'items.no_items_in_space'.tr()
                              : 'items.no_items_subtitle'.tr(),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return housesAsync.when(
                data: (houses) {
                  final categoryEntries = itemsByCategory.entries.toList()
                    ..sort((a, b) => a.key.index.compareTo(b.key.index));

                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: Theme.of(context).colorScheme.primary,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // ── Sezione In Transito ───────────────────────────
                        if (hasTemporaryItems &&
                            widget.selectedSpaceId == null) ...[
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              context.spacingMd,
                              context.spacingMd,
                              context.spacingMd,
                              0,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: InTransitSection(
                                items: temporaryItems,
                                houses: houses,
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(height: context.spacingMd),
                          ),
                        ],

                        // ── Intestazione "In casa" ────────────────────────
                        if (itemsByCategory.isNotEmpty)
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              context.spacingMd,
                              (hasTemporaryItems &&
                                      widget.selectedSpaceId == null)
                                  ? context.spacingSm
                                  : context.spacingMd,
                              context.spacingMd,
                              context.spacingSm,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                'common.at_house'.tr(),
                                style: TextStyle(
                                  fontSize: context.fontSizeLg,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                        // ── Categorie ─────────────────────────────────────
                        for (final entry in categoryEntries)
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.spacingMd,
                            ),
                            sliver: ItemCategorySection(
                              category: entry.key,
                              items: entry.value,
                              houseId: widget.houseId,
                              itemQuantitiesOnTrip: itemQuantitiesOnTrip,
                            ),
                          ),

                        SliverToBoxAdapter(
                          child: SizedBox(height: context.spacingMd),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SkeletonSimpleList(),
                error: (error, stack) => DsErrorState(
                  error: error,
                  onRetry: () => ref.invalidate(houseNotifierProvider),
                  message: 'common.error_loading_houses'.tr(
                    namedArgs: {'error': error.toString()},
                  ),
                ),
              );
            },
            loading: () => const SkeletonItemsBody(),
            error: (error, stack) => DsErrorState(
              error: error,
              onRetry: () => ref
                  .read(itemNotifierProvider(widget.houseId).notifier)
                  .refresh(widget.houseId),
            ),
          ),
        ),
      ],
    );
  }
}

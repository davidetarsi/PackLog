import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/features/items/view/item_category_section.dart';
import 'package:pack_log/shared/helpers/search_match.dart';
import '../../../shared/widgets/skeleton/skeleton.dart';

import '../providers/item_provider.dart';
import '../model/item_model.dart';
import '../../trips/providers/trip_items_status_provider.dart';
import '../../trips/providers/trip_provider.dart';
import '../../houses/providers/house_provider.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/helpers/design_system.dart';
import 'in_transit_section.dart';
import '../widgets/items_empty_state.dart';

/// Body della house detail: lista item filtrata per spazio e ricerca.
///
/// Lo stato dei filtri vive nel parent ([HouseDetailScreen]) che passa:
/// - [selectedSpaceId]: null = tutti, 'default' = pool generale, spaceId = spazio specifico
/// - [searchQuery]: testo cercato tra gli oggetti; null o vuoto = nessun filtro
class ItemsScreen extends ConsumerStatefulWidget {
  final String houseId;
  final String houseName;
  final String? selectedSpaceId;

  /// Testo della ricerca nella casa; `null` o vuoto = nessun filtro.
  final String? searchQuery;

  /// Key per l'etichetta del primo gruppo (il tour la usa come bersaglio).
  final Key? firstGroupKey;

  /// Con la ricerca attiva: un risultato è stato aperto. `position` parte
  /// da 1, nell'ordine in cui le righe sono a schermo.
  final void Function(int position)? onSearchResultOpened;

  const ItemsScreen({
    super.key,
    required this.houseId,
    required this.houseName,
    this.selectedSpaceId,
    this.searchQuery,
    this.firstGroupKey,
    this.onSearchResultOpened,
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
    final query = widget.searchQuery ?? '';
    final isSearching = query.trim().isNotEmpty;
    final temporaryItems = ref
        .watch(temporaryItemsInHouseProvider(widget.houseId))
        .where((i) => matchesSearch(i.name, query))
        .toList();
    final housesAsync = ref.watch(houseNotifierProvider);

    return Column(
      children: [
        Expanded(
          child: itemsAsync.when(
            data: (loadedItems) {
              final allItems = loadedItems
                  .where((i) => matchesSearch(i.name, query))
                  .toList();
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

              // Il gruppo Temporanei non passa dal filtro spazio: con uno spazio
              // scelto non compare, quindi non conta come contenuto visibile.
              final showsTemporaries =
                  hasTemporaryItems && widget.selectedSpaceId == null;

              // ── Vista tutte le categorie con sezioni ──────────────────────
              final itemsByCategory = <ItemCategory, List<ItemModel>>{};
              for (final item in spaceFiltered) {
                itemsByCategory.putIfAbsent(item.category, () => []).add(item);
              }

              if (isSearching && spaceFiltered.isEmpty && !showsTemporaries) {
                return ItemsEmptyState(
                  onRefresh: _onRefresh,
                  icon: Icons.search_off,
                  title: 'items.no_search_results'.tr(),
                );
              }

              if (spaceFiltered.isEmpty && !showsTemporaries) {
                return ItemsEmptyState(
                  key: widget.firstGroupKey,
                  onRefresh: _onRefresh,
                  icon: Icons.inventory_2_outlined,
                  // Niente sottotitolo: l'invito a creare è scritto sul
                  // bottone, ripeterlo sopra era solo rumore.
                  title: widget.selectedSpaceId != null
                      ? 'items.no_items_in_space'.tr()
                      : 'items.no_items'.tr(),
                  houseId: widget.houseId,
                );
              }

              return housesAsync.when(
                data: (houses) {
                  final categoryEntries = itemsByCategory.entries.toList()
                    ..sort((a, b) => a.key.index.compareTo(b.key.index));
                  // Posizione del primo oggetto di ogni gruppo nell'ordine a
                  // schermo, per l'evento del risultato aperto.
                  final offsets = <int>[];
                  var running = 0;
                  for (final entry in categoryEntries) {
                    offsets.add(running);
                    running += entry.value.length;
                  }

                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: Theme.of(context).colorScheme.primary,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // ── Gruppo Temporanei ─────────────────────────────
                        if (showsTemporaries)
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.spacingMd,
                            ),
                            sliver: InTransitSection(
                              items: temporaryItems,
                              houses: houses,
                              headerKey: widget.firstGroupKey,
                            ),
                          ),

                        // ── Categorie ─────────────────────────────────────
                        for (final (i, entry) in categoryEntries.indexed)
                          SliverPadding(
                            key: ValueKey(entry.key),
                            padding: EdgeInsets.symmetric(
                              horizontal: context.spacingMd,
                            ),
                            sliver: ItemCategorySection(
                              category: entry.key,
                              items: entry.value,
                              houseId: widget.houseId,
                              itemQuantitiesOnTrip: itemQuantitiesOnTrip,
                              headerKey: i == 0 && !showsTemporaries
                                  ? widget.firstGroupKey
                                  : null,
                              onItemOpened:
                                  isSearching &&
                                      widget.onSearchResultOpened != null
                                  ? (index) => widget.onSearchResultOpened!(
                                      offsets[i] + index + 1,
                                    )
                                  : null,
                            ),
                          ),

                        SliverToBoxAdapter(
                          child: SizedBox(
                            height:
                                context.spacingMd + context.ctaReservedHeight,
                          ),
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

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/features/items/view/item_category_section.dart';

import '../providers/item_provider.dart';
import '../model/item_model.dart';
import '../../trips/providers/trip_items_status_provider.dart';
import '../../trips/providers/trip_provider.dart';
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
  void initState() {
    super.initState();
    // Invalida i viaggi per ricalcolare lo stato (active/completed)
    // ogni volta che la schermata viene montata
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(tripNotifierProvider);
    });
  }

  /// Aggiorna simultaneamente gli item della casa e lo stato dei viaggi.
  ///
  /// Entrambi i provider vengono ricaricati in parallelo per garantire che:
  /// - la lista item sia aggiornata (aggiunte/modifiche esterne)
  /// - i badge "in viaggio" / "ospite" riflettano lo stato corrente dei viaggi
  Future<void> _onRefresh() => Future.wait([
        ref.refresh(itemNotifierProvider(widget.houseId).future),
        ref.refresh(tripNotifierProvider.future),
      ]);

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
                                return RefreshIndicator(
                                  onRefresh: _onRefresh,
                                  color: Theme.of(context).colorScheme.primary,
                                  child: LayoutBuilder(
                                    builder: (_, constraints) =>
                                        SingleChildScrollView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      child: SizedBox(
                                        height: constraints.maxHeight,
                                        child: EmptyState(
                                          icon: Icons.inventory_2_outlined,
                                          title: 'items.no_items'.tr(),
                                          subtitle: _selectedSpaceId != null
                                              ? 'items.no_items_in_space'.tr()
                                              : 'items.no_items_subtitle'.tr(),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Snapshot della mappa ordinato per indice enum:
                              // garantisce l'ordine canonico vestiti → toiletries →
                              // elettronica → varie indipendentemente dall'ordine
                              // con cui le categorie compaiono nella lista (che può
                              // variare dopo spostamenti/eliminazioni bulk).
                              final categoryEntries = itemsByCategory.entries
                                  .toList()
                                ..sort((a, b) => a.key.index.compareTo(b.key.index));

                              return RefreshIndicator(
                                onRefresh: _onRefresh,
                                color: Theme.of(context).colorScheme.primary,
                                child: CustomScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  slivers: [
                                    // ── Sezione In Transito ──────────────
                                    if (hasTemporaryItems &&
                                        _selectedSpaceId == null) ...[
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
                                        child:
                                            SizedBox(height: context.spacingMd),
                                      ),
                                    ],

                                    // ── Intestazione "In casa" ───────────
                                    if (itemsByCategory.isNotEmpty)
                                      SliverPadding(
                                        padding: EdgeInsets.fromLTRB(
                                          context.spacingMd,
                                          // Se la sezione InTransito non è
                                          // presente, aggiungi il top padding
                                          // dell'intera lista.
                                          (hasTemporaryItems &&
                                                  _selectedSpaceId == null)
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
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),

                                    // ── Categorie (SliverMainAxisGroup, items lazy) ──
                                    // Ogni ItemCategorySection è un
                                    // SliverMainAxisGroup: il SliverList.builder
                                    // interno non usa shrinkWrap e istanzia le
                                    // ItemCard solo quando entrano nel viewport,
                                    // eliminando il Raster Jank del precedente
                                    // ExpansionTile + shrinkWrap.
                                    for (final entry in categoryEntries)
                                      SliverPadding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: context.spacingMd,
                                        ),
                                        sliver: ItemCategorySection(
                                          category: entry.key,
                                          items: entry.value,
                                          houseId: widget.houseId,
                                          itemQuantitiesOnTrip:
                                              itemQuantitiesOnTrip,
                                        ),
                                      ),

                                    // ── Spaziatura finale ─────────────────
                                    SliverToBoxAdapter(
                                      child: SizedBox(height: context.spacingMd),
                                    ),
                                  ],
                                ),
                              ); // RefreshIndicator
                            }(),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(houseNotifierProvider),
              message: 'common.error_loading_houses'.tr(
                namedArgs: {'error': error.toString()},
              ),
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

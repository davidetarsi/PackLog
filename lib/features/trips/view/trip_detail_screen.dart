import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pack_log/shared/widgets/sticky_cta_scaffold.dart';
import '../providers/trip_provider.dart';
import '../model/trip_model.dart';
import '../../houses/providers/house_provider.dart';
import '../../items/model/item_model.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/ds_badge.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/trip_info_badges.dart';
import '../../../shared/widgets/app_pill_tab.dart';
import '../../../shared/widgets/circular_action_button.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../../../shared/widgets/universal_item_tile.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/widgets/skeleton/skeleton.dart';

/// Enum per le tab di filtro delle categorie
enum TripItemFilterTab {
  all('trips.filter_all', null),
  vestiti('categories.vestiti', ItemCategory.vestiti),
  toiletries('categories.toiletries', ItemCategory.toiletries),
  elettronica('categories.elettronica', ItemCategory.elettronica),
  varie('categories.varie', ItemCategory.varie);

  final String labelKey;
  final ItemCategory? categoryFilter;
  const TripItemFilterTab(this.labelKey, this.categoryFilter);

  String get label => labelKey.tr();
}

class TripDetailScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  TripItemFilterTab _selectedTab = TripItemFilterTab.all;

  /// Filtra gli items in base alla tab selezionata
  List<TripItem> _filterItems(List<TripItem> items) {
    if (_selectedTab.categoryFilter == null) {
      return items;
    }
    return items
        .where((item) => item.category == _selectedTab.categoryFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripNotifierProvider);
    final housesAsync = ref.watch(houseNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return tripsAsync.when(
      data: (trips) {
        final matchingTrips = trips.where((t) => t.id == widget.tripId);
        if (matchingTrips.isEmpty) {
          return _buildNotFoundScreen(context);
        }

        final trip = matchingTrips.first;
        final filteredItems = _filterItems(trip.items);
        final bool hasItems = trip.items.isNotEmpty;

        final house = housesAsync.valueOrNull
            ?.where((h) => h.id == trip.destinationHouseId)
            .firstOrNull;
        final displayDestination =
            house?.displayName ?? trip.destinationDisplayName ?? '';

        return StickyCtaScaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Text(displayDestination),
          ),
          // Builder: ctaReservedHeight legge CtaReservedSpaceScope, che
          // StickyCtaScaffold inserisce come discendente di `body` — serve un
          // context interno a questo subtree, non quello del metodo build
          // esterno (che sta sopra lo scope e non lo vedrebbe mai).
          body: Builder(
            builder: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge informativi: date, destinazione, bagagli
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacingMd,
                    vertical: context.spacingMd,
                  ),
                  child: TripInfoBadges(trip: trip, direction: Axis.vertical),
                ),

                // Pill tabs per filtrare per categoria
                AppPillTab<TripItemFilterTab>(
                  items: TripItemFilterTab.values,
                  selectedItem: _selectedTab,
                  getLabel: (tab) => tab.label,
                  onSelected: (tab) => setState(() => _selectedTab = tab),
                  height: 40,
                  scrollPadding: EdgeInsets.symmetric(
                    horizontal: context.spacingSm,
                  ),
                ),
                SizedBox(height: context.spacingMd),

                // Lista items
                Expanded(
                  child: filteredItems.isEmpty
                      ? _buildEmptyItemsState(context, colorScheme)
                      : ListView.builder(
                          padding: EdgeInsets.all(context.spacingSm).copyWith(
                            // spacingMd (non spacingSm) per coerenza con la stessa
                            // gap finale usata in items_screen.dart (house detail):
                            // stesso respiro visivo sotto l'ultimo item in entrambe
                            // le schermate che condividono lo stesso pattern.
                            bottom:
                                context.spacingMd + context.ctaReservedHeight,
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return _TripItemCard(
                              item: item,
                              tripId: widget.tripId,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          // Action bar unificata in basso
          bottomContent: UniversalActionBar(
            primaryLabel: hasItems
                ? 'trips.edit_items'.tr()
                : 'trips.add_clothes'.tr(),
            primaryIcon: hasItems ? Icons.checklist : Icons.add_circle_outline,
            onPrimaryPressed: () =>
                context.push('/trips/${widget.tripId}/edit-items'),
            leftAction: CircularActionButton(
              icon: Icons.delete_outline,
              onPressed: () =>
                  _showDeleteDialog(context, trip, displayDestination),
              showBorder: true,
            ),
            rightAction: CircularActionButton(
              icon: Icons.edit_outlined,
              onPressed: () =>
                  context.push('/trips/${widget.tripId}/edit-info'),
              showBorder: true,
            ),
          ),
        );
      },
      loading: () => const SkeletonTripDetailScreen(),
      error: (error, stack) => _buildErrorScreen(context, error),
    );
  }

  Widget _buildNotFoundScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('common.not_found'.tr())),
      body: DsEmptyState(
        icon: Icons.luggage_outlined,
        title: 'common.not_found'.tr(),
        action: ElevatedButton.icon(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
          label: Text('common.back_to_list'.tr()),
        ),
      ),
    );
  }

  Widget _buildEmptyItemsState(BuildContext context, ColorScheme colorScheme) {
    final message = _selectedTab == TripItemFilterTab.all
        ? 'trips.no_items_in_list'.tr()
        : 'trips.no_items_in_category_filter'.tr(args: [_selectedTab.label]);

    return DsEmptyState(icon: Icons.inventory_2_outlined, title: message);
  }

  Widget _buildErrorScreen(BuildContext context, Object error) {
    return Scaffold(
      appBar: AppBar(title: Text('common.error'.tr())),
      body: DsErrorState(
        error: error,
        onRetry: () => ref.read(tripNotifierProvider.notifier).refresh(),
      ),
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    TripModel trip,
    String displayDestination,
  ) async {
    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: 'common.list_type'.tr(),
      itemName: displayDestination,
    );
    if (confirmed == true && context.mounted) {
      final success = await ErrorRetryDialog.executeWithRetry(
        context: context,
        operation: () =>
            ref.read(tripNotifierProvider.notifier).deleteTrip(widget.tripId),
        errorTitle: 'errors.delete_error'.tr(),
        errorMessage: 'errors.delete_trip_failed'.tr(
          args: [displayDestination],
        ),
      );
      if (success && context.mounted) {
        context.pop();
      }
    }
  }
}

class _TripItemCard extends ConsumerWidget {
  final TripItem item;
  final String tripId;

  const _TripItemCard({required this.item, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return UniversalItemTile(
      onTap: () {
        ref
            .read(tripNotifierProvider.notifier)
            .toggleItemCheck(tripId, item.id);
      },
      leading: Checkbox(
        value: item.isChecked,
        onChanged: (_) {
          ref
              .read(tripNotifierProvider.notifier)
              .toggleItemCheck(tripId, item.id);
        },
        // shape non necessario: Material 3 LinearProgressIndicator è già arrotondato di default
      ),
      title: Text(
        item.name,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          decoration: item.isChecked ? TextDecoration.lineThrough : null,
          color: item.isChecked ? context.textTertiary : colorScheme.onSurface,
        ),
      ),
      /* subtitle: Text(
        item.category.name,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ), */
      trailing: DsQuantityBadge(current: item.quantity),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trip_provider.dart';
import '../model/trip_model.dart';
import '../../items/model/item_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/trip_summary_card.dart';
import '../../../shared/widgets/app_pill_tab.dart';
import '../../../shared/widgets/circular_action_button.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../../../shared/helpers/design_system.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return tripsAsync.when(
      data: (trips) {
        final matchingTrips = trips.where((t) => t.id == widget.tripId);
        if (matchingTrips.isEmpty) {
          return _buildNotFoundScreen(context);
        }

        final trip = matchingTrips.first;
        final filteredItems = _filterItems(trip.items);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/trips'),
            ),
            title: Text('common.trip_detail'.tr()),
          ),
          body: Column(
            children: [
              // Card riassuntiva del viaggio
              Padding(
                padding: EdgeInsets.all(context.spacingSm),
                child: TripSummaryCard(trip: trip, isClickable: false),
              ),

              // Pill tabs per filtrare per categoria
              AppPillTab<TripItemFilterTab>(
                items: TripItemFilterTab.values,
                selectedItem: _selectedTab,
                getLabel: (tab) => tab.label,
                onSelected: (tab) => setState(() => _selectedTab = tab),
                height: 40,
                scrollPadding: EdgeInsets.symmetric(horizontal: context.spacingSm),
              ),
              SizedBox(height: context.spacingSm),

              // Lista items
              Expanded(
                child: filteredItems.isEmpty
                    ? _buildEmptyItemsState(context, colorScheme)
                    : ListView.builder(
                        padding: EdgeInsets.all(context.spacingSm),
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
          // Action bar unificata in basso
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: context.spacingMd,
                right: context.spacingMd,
                top: context.spacingMd,
                bottom: context.spacingSm,
              ),
              child: UniversalActionBar(
                horizontalPadding: 0,
                primaryLabel: 'trips.edit_items'.tr(),
                primaryIcon: Icons.checklist,
                onPrimaryPressed: () => context.push('/trips/${widget.tripId}/edit-items'),
                leftAction: CircularActionButton(
                  icon: Icons.delete_outline,
                  onPressed: () => _showDeleteDialog(context, trip),
                  showBorder: true,
                ),
                rightAction: CircularActionButton(
                  icon: Icons.edit_calendar,
                  onPressed: () => context.push('/trips/${widget.tripId}/edit-info'),
                  showBorder: true,
                ),
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _buildErrorScreen(context, error),
    );
  }

  Widget _buildNotFoundScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('common.not_found'.tr())),
      body: EmptyState(
        icon: Icons.luggage_outlined,
        title: 'common.not_found'.tr(),
        action: ElevatedButton.icon(
          onPressed: () => context.go('/trips'),
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

    return EmptyState(
      icon: Icons.inventory_2_outlined,
      title: message,
    );
  }

  Widget _buildErrorScreen(BuildContext context, Object error) {
    return Scaffold(
      appBar: AppBar(title: Text('common.error'.tr())),
      body: ErrorState(
        error: error,
        onRetry: () => ref.read(tripNotifierProvider.notifier).refresh(),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, TripModel trip) async {
    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: 'common.list_type'.tr(),
      itemName: trip.name,
    );
    if (confirmed == true && context.mounted) {
      final success = await ErrorRetryDialog.executeWithRetry(
        context: context,
        operation: () =>
            ref.read(tripNotifierProvider.notifier).deleteTrip(widget.tripId),
        errorTitle: 'errors.delete_error'.tr(),
        errorMessage: 'errors.delete_trip_failed'.tr(args: [trip.name]),
      );
      if (success && context.mounted) {
        context.go('/trips');
      }
    }
  }
}

/// Bottoni di azione in basso
/// Card per un singolo item del viaggio
class _TripItemCard extends ConsumerWidget {
  final TripItem item;
  final String tripId;

  const _TripItemCard({required this.item, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.only(bottom: context.spacingSm),
      shape: RoundedRectangleBorder(
        borderRadius: context.responsiveBorderRadius(
          AppConstants.cardBorderRadius,
        ),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: context.responsiveBorderRadius(
          AppConstants.cardBorderRadius,
        ),
        onTap: () {
          ref
              .read(tripNotifierProvider.notifier)
              .toggleItemCheck(tripId, item.id);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacingSm,
            vertical: context.spacingSm,
          ),
          child: Row(
            children: [
              // Checkbox
              Checkbox(
                value: item.isChecked,
                onChanged: (_) {
                  ref
                      .read(tripNotifierProvider.notifier)
                      .toggleItemCheck(tripId, item.id);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              SizedBox(width: context.spacingXs),

              // Nome e categoria
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: context.fontSizeMd,
                        fontWeight: FontWeight.w500,
                        decoration: item.isChecked
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.isChecked
                            ? colorScheme.onSurface.withValues(alpha: 0.5)
                            : colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      item.category.name,
                      style: TextStyle(
                        fontSize: context.fontSizeXs,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Quantità
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacingSm,
                  vertical: context.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: context.responsiveBorderRadius(8),
                ),
                child: Text(
                  'x${item.quantity}',
                  style: TextStyle(
                    fontSize: context.fontSizeXs,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

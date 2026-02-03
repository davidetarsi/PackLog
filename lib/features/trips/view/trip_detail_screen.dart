import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trip_provider.dart';
import '../model/trip_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/trip_summary_card.dart';

/// Enum per le tab di filtro delle categorie
enum TripItemFilterTab {
  all('Tutto', null),
  vestiti('Vestiti', 'Vestiti'),
  toiletries('Toiletries', 'Toiletries'),
  elettronica('Elettronica', 'Elettronica'),
  varie('Varie', 'Varie');

  final String label;
  final String? categoryFilter;
  const TripItemFilterTab(this.label, this.categoryFilter);
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
              onPressed: () => context.pop(),
            ),
            title: const Text('Dettaglio viaggio'),
          ),
          body: Column(
            children: [
              // Card riassuntiva del viaggio
              Padding(
                padding: EdgeInsets.all(context.spacingSm),
                child: TripSummaryCard(trip: trip, isClickable: false),
              ),

              // Pill tabs per filtrare per categoria
              _CategoryFilterTabs(
                selectedTab: _selectedTab,
                onTabSelected: (tab) => setState(() => _selectedTab = tab),
              ),
              SizedBox(height: context.spacingSm),

              // Lista items
              Expanded(
                child: filteredItems.isEmpty
                    ? _buildEmptyItemsState(context, colorScheme)
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          left: context.spacingSm,
                          right: context.spacingSm,
                          top: context.spacingXs,
                          bottom: context.spacingXl * 4, // Spazio per i bottoni
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
          // Bottoni floating in basso
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _BottomActionButtons(
            onDelete: () => _showDeleteDialog(context, trip),
            onEdit: () => context.push('/trips/${widget.tripId}/edit-info'),
            onEditItems: () =>
                context.push('/trips/${widget.tripId}/edit-items'),
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
      appBar: AppBar(title: const Text('Lista non trovata')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.luggage_outlined,
              size: context.iconSizeHero,
              color: AppColors.disabled,
            ),
            SizedBox(height: context.spacingMd),
            Text(
              'Lista non trovata',
              style: TextStyle(fontSize: context.fontSizeXl),
            ),
            SizedBox(height: context.spacingXl),
            ElevatedButton.icon(
              onPressed: () => context.go('/trips'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Torna alle liste'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyItemsState(BuildContext context, ColorScheme colorScheme) {
    final message = _selectedTab == TripItemFilterTab.all
        ? 'Nessun oggetto nella lista'
        : 'Nessun oggetto in "${_selectedTab.label}"';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: context.iconSizeHero,
            color: AppColors.disabled,
          ),
          SizedBox(height: context.spacingMd),
          Text(
            message,
            style: TextStyle(
              color: AppColors.disabled,
              fontSize: context.fontSizeMd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context, Object error) {
    return Scaffold(
      appBar: AppBar(title: const Text('Errore')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: context.iconSizeHero,
              color: AppColors.destructive,
            ),
            SizedBox(height: context.spacingMd),
            Text('Errore: $error'),
            SizedBox(height: context.spacingMd),
            ElevatedButton(
              onPressed: () {
                ref.read(tripNotifierProvider.notifier).refresh();
              },
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, TripModel trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina lista'),
        content: Text('Sei sicuro di voler eliminare "${trip.name}"?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: const Text(
              'Elimina',
              style: TextStyle(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final success = await ErrorRetryDialog.executeWithRetry(
        context: context,
        operation: () =>
            ref.read(tripNotifierProvider.notifier).deleteTrip(widget.tripId),
        errorTitle: 'Errore di eliminazione',
        errorMessage: 'Impossibile eliminare il viaggio "${trip.name}".',
      );
      if (success && context.mounted) {
        context.go('/trips');
      }
    }
  }
}

/// Pill tabs per filtrare gli items per categoria
class _CategoryFilterTabs extends StatelessWidget {
  final TripItemFilterTab selectedTab;
  final ValueChanged<TripItemFilterTab> onTabSelected;

  const _CategoryFilterTabs({
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: context.spacingSm),
        child: Row(
          children: TripItemFilterTab.values.map((tab) {
            final isSelected = selectedTab == tab;
            return Padding(
              padding: EdgeInsets.only(right: context.spacingSm),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: context.responsiveBorderRadius(20),
                  onTap: () => onTabSelected(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spacingMd,
                      vertical: context.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: context.responsiveBorderRadius(20),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: context.fontSizeMd,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Bottoni di azione in basso
class _BottomActionButtons extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onEditItems;

  const _BottomActionButtons({
    required this.onDelete,
    required this.onEdit,
    required this.onEditItems,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacingSm),
      child: Row(
        children: [
          // Bottone elimina (sinistra, ovale orizzontale)
          Material(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onDelete,
              child: Container(
                width: 56,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: iconColor, width: 2),
                ),
                child: Icon(Icons.delete_outline, color: iconColor, size: 22),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Bottone centrale (modifica oggetti) - pill tab
          Expanded(
            child: Material(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: onEditItems,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: colorScheme.primary, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checklist, color: iconColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Modifica oggetti',
                        style: TextStyle(
                          color: iconColor,
                          fontWeight: FontWeight.w600,
                          fontSize: context.fontSizeMd,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Bottone modifica viaggio (destra, ovale orizzontale)
          Material(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onEdit,
              child: Container(
                width: 56,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: iconColor, width: 2),
                ),
                child: Icon(Icons.edit_calendar, color: iconColor, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
                      item.category,
                      style: TextStyle(
                        fontSize: context.fontSizeSm,
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
                    fontSize: context.fontSizeMd,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trip_provider.dart';
import '../model/trip_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/trip_summary_card.dart';
import '../../../shared/widgets/app_pill_tab.dart';
import '../../../shared/design_system/design_system.dart';

/// Enum per le tab di filtro
enum TripFilterTab {
  upcoming('Prossimi'),
  past('Passati'),
  saved('Salvati'),
  all('Tutti');

  final String label;
  const TripFilterTab(this.label);
}

class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  TripFilterTab _selectedTab = TripFilterTab.upcoming;

  /// Stima l'altezza di una card in base al suo contenuto
  static double _estimateCardHeight(TripModel trip) {
    const maxPreviewItems = 5;
    double height = 60; // Base: titolo + padding

    if (trip.description != null) {
      height += 20; // Descrizione
    }

    if (trip.items.isNotEmpty) {
      height += 40; // Progress bar + counter + spacing
      final itemsToShow = trip.items.length > maxPreviewItems
          ? maxPreviewItems
          : trip.items.length;
      height += itemsToShow * 24; // Ogni item ~24px

      if (trip.items.length > maxPreviewItems) {
        height += 20; // "+N altri"
      }
    }

    return height;
  }

  /// Trova il prossimo viaggio più vicino (in corso o futuro)
  TripModel? _findNextTrip(List<TripModel> trips) {
    // Prima cerca un viaggio attivo (in corso)
    final activeTrips = trips.where((t) => t.isActive).toList();
    if (activeTrips.isNotEmpty) {
      // Prendi quello che finisce prima
      activeTrips.sort((a, b) {
        final aReturn = a.returnDateTime ?? DateTime(2099);
        final bReturn = b.returnDateTime ?? DateTime(2099);
        return aReturn.compareTo(bReturn);
      });
      return activeTrips.first;
    }

    // Altrimenti cerca il prossimo viaggio futuro
    final upcomingTrips = trips.where((t) => t.isUpcoming).toList();
    if (upcomingTrips.isNotEmpty) {
      // Ordina per data di partenza
      upcomingTrips.sort((a, b) {
        final aDeparture = a.departureDateTime ?? DateTime(2099);
        final bDeparture = b.departureDateTime ?? DateTime(2099);
        return aDeparture.compareTo(bDeparture);
      });
      return upcomingTrips.first;
    }

    return null;
  }

  /// Filtra i viaggi in base alla tab selezionata
  List<TripModel> _filterTrips(List<TripModel> trips, TripModel? nextTrip) {
    switch (_selectedTab) {
      case TripFilterTab.upcoming:
        return trips.where((t) => t.isActive || t.isUpcoming).toList();
      case TripFilterTab.past:
        return trips.where((t) => t.isCompleted).toList();
      case TripFilterTab.saved:
        return trips.where((t) => t.isSaved).toList();
      case TripFilterTab.all:
        return trips;
    }
  }

  /// Ordina i viaggi (più recenti prima per passati, più vicini prima per prossimi)
  List<TripModel> _sortTrips(List<TripModel> trips) {
    final sorted = List<TripModel>.from(trips);

    if (_selectedTab == TripFilterTab.past) {
      // Passati: più recenti prima
      sorted.sort((a, b) {
        final aReturn = a.returnDateTime ?? a.departureDateTime ?? a.createdAt;
        final bReturn = b.returnDateTime ?? b.departureDateTime ?? b.createdAt;
        return bReturn.compareTo(aReturn);
      });
    } else {
      // Prossimi/Tutti: più vicini prima
      sorted.sort((a, b) {
        final aDeparture = a.departureDateTime ?? DateTime(2099);
        final bDeparture = b.departureDateTime ?? DateTime(2099);
        return aDeparture.compareTo(bDeparture);
      });
    }

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return tripsAsync.when(
      data: (trips) {
        if (trips.isEmpty) {
          return _buildEmptyState(context);
        }

        final nextTrip = _findNextTrip(trips);
        final filteredTrips = _filterTrips(trips, nextTrip);
        final sortedTrips = _sortTrips(filteredTrips);

        // Rimuovi il prossimo viaggio dalla lista se stiamo mostrando la card grande
        final showNextTripCard =
            nextTrip != null &&
            (_selectedTab == TripFilterTab.upcoming ||
                _selectedTab == TripFilterTab.all);
        final tripsForMasonry = showNextTripCard
            ? sortedTrips.where((t) => t.id != nextTrip.id).toList()
            : sortedTrips;

        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: context.spacingSm,
            right: context.spacingSm,
            top: context.spacingSm,
            bottom: AppConstants.floatingNavBarPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titolo di benvenuto
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacingXs,
                  vertical: context.spacingSm,
                ),
                child: Text(
                  'Pronto per la tua\nprossima avventura?',
                  style: TextStyle(
                    fontSize: context.fontSizeHeading,
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
              SizedBox(height: context.spacingSm),

              // Pill Tabs
              Center(
                child: AppPillTab<TripFilterTab>(
                  items: TripFilterTab.values,
                  selectedItem: _selectedTab,
                  getLabel: (tab) => tab.label,
                  onSelected: (tab) => setState(() => _selectedTab = tab),
                ),
              ),
              SizedBox(height: context.spacingMd),

              // Card grande del prossimo viaggio
              if (showNextTripCard) ...[
                TripSummaryCard(
                  trip: nextTrip,
                  onTap: () => context.push('/trips/${nextTrip.id}'),
                ),
                SizedBox(height: context.spacingSm),
              ],

              // Stato vuoto per il filtro corrente
              if (tripsForMasonry.isEmpty && !showNextTripCard)
                _buildFilterEmptyState(context, colorScheme)
              else if (tripsForMasonry.isNotEmpty)
                // Layout masonry
                _TripsMasonry(trips: tripsForMasonry),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(context, ref, error),
    );
  }


  Widget _buildEmptyState(BuildContext context) {
    return const EmptyState(
      icon: Icons.luggage_outlined,
      title: 'Nessun viaggio',
      subtitle: 'Crea il tuo primo viaggio',
    );
  }

  Widget _buildFilterEmptyState(BuildContext context, ColorScheme colorScheme) {
    String message;
    IconData icon;

    switch (_selectedTab) {
      case TripFilterTab.upcoming:
        message = 'Nessun viaggio in programma';
        icon = Icons.calendar_today_outlined;
        break;
      case TripFilterTab.past:
        message = 'Nessun viaggio passato';
        icon = Icons.history_outlined;
        break;
      case TripFilterTab.saved:
        message = 'Nessun viaggio salvato';
        icon = Icons.bookmark_border_outlined;
        break;
      case TripFilterTab.all:
        message = 'Nessun viaggio';
        icon = Icons.luggage_outlined;
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacingXl * 2),
      child: EmptyState(
        icon: icon,
        title: message,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return ErrorState(
      error: error,
      onRetry: () => ref.read(tripNotifierProvider.notifier).refresh(),
    );
  }
}

/// Card standard per i viaggi (singola colonna nel masonry)
class _TripCard extends StatelessWidget {
  final TripModel trip;

  const _TripCard({required this.trip});

  static const int _maxPreviewItems = 5;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final itemsToShow = trip.items.length > _maxPreviewItems
        ? _maxPreviewItems
        : trip.items.length;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.transparent,
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
          context.push('/trips/${trip.id}');
        },
        child: Padding(
          padding: EdgeInsets.all(context.spacingSm + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header con titolo e icona salvato
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      trip.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: context.fontSizeMd,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trip.isSaved)
                    Padding(
                      padding: EdgeInsets.only(left: context.spacingXs),
                      child: Icon(
                        Icons.bookmark,
                        size: context.iconSizeSm + 2,
                        color: colorScheme.primary,
                      ),
                    ),
                ],
              ),
              if (trip.description != null) ...[
                SizedBox(height: context.spacingXs),
                Text(
                  trip.description!,
                  style: TextStyle(
                    fontSize: context.fontSizeXs,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: context.spacingSm),
              // Progress bar
              if (trip.items.isNotEmpty) ...[
                LinearProgressIndicator(
                  value: trip.completionPercentage,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    trip.completionPercentage == 1.0
                        ? AppColors.success
                        : colorScheme.primary,
                  ),
                ),
                SizedBox(height: context.spacingXs),
                Text(
                  '${trip.completedCount}/${trip.totalCount}',
                  style: TextStyle(
                    fontSize: context.fontSizeXs + 1,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                SizedBox(height: context.spacingSm),
              ],
              // Lista items (preview)
              ...List.generate(itemsToShow, (index) {
                final item = trip.items[index];
                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: context.spacingXs / 2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.isChecked
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: context.iconSizeSm,
                        color: item.isChecked
                            ? AppColors.success
                            : colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      SizedBox(width: context.spacingXs + 2),
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: context.fontSizeXs,
                            decoration: item.isChecked
                                ? TextDecoration.lineThrough
                                : null,
                            color: item.isChecked
                                ? colorScheme.onSurface.withValues(alpha: 0.5)
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'x${item.quantity}',
                        style: TextStyle(
                          fontSize: context.fontSizeXs + 1,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (trip.items.length > _maxPreviewItems)
                Padding(
                  padding: EdgeInsets.only(top: context.spacingXs),
                  child: Text(
                    '+${trip.items.length - _maxPreviewItems} altri',
                    style: TextStyle(
                      fontSize: context.fontSizeXs + 1,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
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

class _TripsMasonry extends StatelessWidget {
  final List<TripModel> trips;

  const _TripsMasonry({required this.trips});

  @override
  Widget build(BuildContext context) {
    final leftColumnTrips = <TripModel>[];
    final rightColumnTrips = <TripModel>[];
    double leftColumnHeight = 0;
    double rightColumnHeight = 0;

    for (final trip in trips) {
      final cardHeight = _TripsScreenState._estimateCardHeight(trip);
      if (leftColumnHeight <= rightColumnHeight) {
        leftColumnTrips.add(trip);
        leftColumnHeight += cardHeight + 8;
      } else {
        rightColumnTrips.add(trip);
        rightColumnHeight += cardHeight + 8;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: leftColumnTrips
                .map(
                  (trip) => Padding(
                    padding: EdgeInsets.only(bottom: context.spacingSm),
                    child: _TripCard(trip: trip),
                  ),
                )
                .toList(),
          ),
        ),
        SizedBox(width: context.spacingSm),
        Expanded(
          child: Column(
            children: rightColumnTrips
                .map(
                  (trip) => Padding(
                    padding: EdgeInsets.only(bottom: context.spacingSm),
                    child: _TripCard(trip: trip),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

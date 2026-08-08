import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trip_provider.dart';
import '../model/trip_model.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/trip_cards.dart';
import '../../../shared/widgets/app_pill_tab.dart';
import '../../../shared/widgets/entity_context_menu.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/entity_action_handler.dart';
import '../../../shared/widgets/skeleton/skeleton.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';

/// Enum per le tab di filtro
enum TripFilterTab {
  upcoming('trips.filter_upcoming'),
  past('trips.filter_past'),
  saved('trips.filter_saved'),
  all('trips.filter_all');

  final String labelKey;
  const TripFilterTab(this.labelKey);

  String get label => labelKey.tr();
}

class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  TripFilterTab _selectedTab = TripFilterTab.upcoming;

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

  Future<void> _handleTripLongPress(TripModel trip) async {
    final action = await showEntityContextMenu(
      context: context,
      entityType: 'common.trip_type'.tr(),
      showSaveAction: true,
      isSaved: trip.isSaved,
    );
    if (action == null || !mounted) return;

    await EntityActionHandler.handleAction(
      context: context,
      action: action,
      entityTypeLabel: 'common.trip_type'.tr(),
      entityName: trip.name,
      onCopy: () async {
        await ref
            .read(tripNotifierProvider.notifier)
            .duplicateTrip(trip.id, nameSuffix: 'trips.duplicate_suffix'.tr());
      },
      copyErrorMessage: 'errors.duplicate_trip_failed'.tr(args: [trip.name]),
      onDelete: () async {
        await ref.read(tripNotifierProvider.notifier).deleteTrip(trip.id);
      },
      deleteErrorMessage: 'errors.delete_trip_failed'.tr(args: [trip.name]),
      onSave: () async {
        await ref.read(tripNotifierProvider.notifier).toggleSaved(trip.id);
      },
      saveErrorMessage: 'errors.save_trip_failed'.tr(args: [trip.name]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ShellTabScaffold(
      body: tripsAsync.when(
        skipLoadingOnReload: true,
        data: (trips) => _buildTripsContent(context, ref, colorScheme, trips),
        loading: () => const SkeletonTripsBody(),
        error: (error, stack) => RefreshIndicator(
          onRefresh: () => ref.refresh(tripNotifierProvider.future),
          color: colorScheme.primary,
          child: LayoutBuilder(
            builder: (_, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight,
                child: _buildErrorState(context, ref, error),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Costruisce il contenuto principale. Titolo e filtri sono SEMPRE visibili,
  /// indipendentemente dal fatto che la lista sia vuota o meno.
  Widget _buildTripsContent(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    List<TripModel> trips,
  ) {
    final nextTrip = _findNextTrip(trips);
    final filteredTrips = _filterTrips(trips, nextTrip);
    final sortedTrips = _sortTrips(filteredTrips);

    final showNextTripCard =
        nextTrip != null &&
        (_selectedTab == TripFilterTab.upcoming ||
            _selectedTab == TripFilterTab.all);
    final tripsForMasonry = showNextTripCard
        ? sortedTrips.where((t) => t.id != nextTrip.id).toList()
        : sortedTrips;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(tripNotifierProvider.future),
      color: colorScheme.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Header sempre visibile: titolo + pill tabs.
          // Estratto come lista per evitare duplicazioni tra i due branch.
          final headerWidgets = <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingXs,
                vertical: context.spacingSm,
              ),
              child: Text(
                'trips.welcome_title'.tr(),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(height: context.spacingMd),
            Center(
              child: AppPillTab<TripFilterTab>(
                items: TripFilterTab.values,
                selectedItem: _selectedTab,
                getLabel: (tab) => tab.label,
                onSelected: (tab) => setState(() => _selectedTab = tab),
              ),
            ),
            SizedBox(height: context.spacingLg),
          ];

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            // `bottom`: vedi [ShellTabScaffold] — il contenuto scorre dietro
            // la nav bar flottante, questo padding tiene l'ultimo viaggio
            // raggiungibile.
            padding: EdgeInsets.only(
              left: context.spacingMd,
              right: context.spacingMd,
              top: context.spacingSm,
              bottom: context.navBarReservedHeight,
            ),
            // Quando la lista è vuota, SizedBox con altezza DELIMITATA permette
            // a Expanded di funzionare per centrare verticalmente l'empty state.
            // Quando ci sono dati, ConstrainedBox con minHeight garantisce che
            // il contenuto riempia lo schermo e sia scrollabile se supera l'altezza.
            child: trips.isEmpty
                ? SizedBox(
                    height: constraints.maxHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...headerWidgets,
                        Expanded(
                          child: Center(child: _buildEmptyState(context)),
                        ),
                      ],
                    ),
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...headerWidgets,
                        if (showNextTripCard) ...[
                          TripCardHero(
                            trip: nextTrip,
                            onTap: () => context.push('/trips/${nextTrip.id}'),
                            onLongPress: () => _handleTripLongPress(nextTrip),
                          ),
                          SizedBox(height: context.spacingSm),
                        ],
                        if (tripsForMasonry.isEmpty && !showNextTripCard)
                          _buildFilterEmptyState(context, colorScheme)
                        else if (tripsForMasonry.isNotEmpty)
                          _TripsMasonry(trips: tripsForMasonry),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DsEmptyState(
      icon: Icons.luggage_outlined,
      iconColor: colorScheme.primary,
      title: 'trips.no_trips_title'.tr(),
      action: FilledButton.icon(
        onPressed: () => context.push('/new-trip'),
        icon: const Icon(Icons.add),
        label: Text('trips.no_trips_subtitle'.tr()),
      ),
    );
  }

  Widget _buildFilterEmptyState(BuildContext context, ColorScheme colorScheme) {
    String message;
    IconData icon;

    switch (_selectedTab) {
      case TripFilterTab.upcoming:
        message = 'trips.no_upcoming'.tr();
        icon = Icons.calendar_today_outlined;
        break;
      case TripFilterTab.past:
        message = 'trips.no_past'.tr();
        icon = Icons.history_outlined;
        break;
      case TripFilterTab.saved:
        message = 'trips.no_saved'.tr();
        icon = Icons.bookmark_border_outlined;
        break;
      case TripFilterTab.all:
        message = 'errors.no_trips'.tr();
        icon = Icons.luggage_outlined;
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacingXl * 2),
      child: DsEmptyState(icon: icon, title: message),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return DsErrorState(
      error: error,
      onRetry: () => ref.read(tripNotifierProvider.notifier).refresh(),
    );
  }
}

/// Masonry a 2 colonne per le trip card compatte.
///
/// Distribuisce le card tra colonne sinistra/destra usando una stima
/// dell'altezza per bilanciare le colonne. Ogni card usa [TripCardCompact]
/// (estratto in shared).
class _TripsMasonry extends StatelessWidget {
  final List<TripModel> trips;

  const _TripsMasonry({required this.trips});

  static double _estimateCardHeight(TripModel trip) {
    const maxPreviewItems = 5;
    double h = 64; // titolo + padding + spacing
    if (trip.description != null) h += 22;
    if (trip.items.isNotEmpty) {
      h += 36; // progress + counter
      final preview = trip.items.length.clamp(0, maxPreviewItems);
      h += preview * 26;
      if (trip.items.length > maxPreviewItems) h += 22;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final left = <TripModel>[];
    final right = <TripModel>[];
    double lh = 0;
    double rh = 0;

    for (final trip in trips) {
      final h = _estimateCardHeight(trip) + AppSpacing.md;
      if (lh <= rh) {
        left.add(trip);
        lh += h;
      } else {
        right.add(trip);
        rh += h;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: left
                .map(
                  (t) => Padding(
                    padding: EdgeInsets.only(bottom: context.spacingMd),
                    child: TripCardCompact(trip: t),
                  ),
                )
                .toList(),
          ),
        ),
        SizedBox(width: context.spacingMd),
        Expanded(
          child: Column(
            children: right
                .map(
                  (t) => Padding(
                    padding: EdgeInsets.only(bottom: context.spacingMd),
                    child: TripCardCompact(trip: t),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

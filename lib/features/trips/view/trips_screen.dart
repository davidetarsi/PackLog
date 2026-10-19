import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../houses/model/house_model.dart';
import '../../houses/providers/house_provider.dart';
import '../model/trip_model.dart';
import '../model/trip_postcard.dart';
import '../providers/trip_provider.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/entity_action_handler.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/app_pill_tab.dart';
import '../../../shared/widgets/entity_context_menu.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';
import '../../../shared/widgets/skeleton/skeleton.dart';
import '../../../shared/widgets/tab_header.dart';
import 'widgets/postcard/postcard_pile.dart';
import 'widgets/postcard/trip_album.dart';
import 'widgets/postcard/trip_postcard.dart';

/// Filtri della tab Viaggi. Neutri: nessun colore d'accento.
enum TripFilterTab {
  upcoming('trips.filter_upcoming'),
  past('trips.filter_past'),
  saved('trips.filter_saved');

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

  /// Riusa il viaggio: copia senza date, poi apre la modifica in modalità
  /// riuso. Se l'utente esce senza salvare, la copia viene eliminata dalla
  /// rotta di modifica.
  Future<void> _handleReuse(TripModel trip) async {
    try {
      final newId = await ref
          .read(tripNotifierProvider.notifier)
          .reuseTrip(trip.id);
      if (!mounted) return;
      context.push('/trips/$newId/edit-info?reuse=1');
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        'errors.duplicate_trip_failed'.tr(args: [trip.name]),
      );
    }
  }

  void _onPileCta(TripModel trip, PostcardCta cta) {
    if (cta == PostcardCta.prepare) {
      context.push('/trips/${trip.id}/edit-items');
    } else {
      context.push('/trips/${trip.id}');
    }
  }

  /// Nome della meta: casa di destinazione se esiste, altrimenti città o
  /// nome del viaggio.
  String _destinationOf(TripModel trip, List<HouseModel> houses) {
    String? houseName;
    for (final house in houses) {
      if (house.id == trip.destinationHouseId) {
        houseName = house.displayName;
        break;
      }
    }
    return tripDestinationName(trip, houseName: houseName);
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripNotifierProvider);
    final houses = ref.watch(houseNotifierProvider).valueOrNull ?? const [];
    final colorScheme = Theme.of(context).colorScheme;

    return ShellTabScaffold(
      body: Column(
        children: [
          TabHeader(title: 'navigation.trips'.tr()),
          Center(
            child: AppPillTab<TripFilterTab>(
              items: TripFilterTab.values,
              selectedItem: _selectedTab,
              getLabel: (tab) => tab.label,
              onSelected: (tab) => setState(() => _selectedTab = tab),
              selectedColor: colorScheme.onSurface,
              selectedTextColor: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: context.spacingMd),
          Expanded(
            child: tripsAsync.when(
              skipLoadingOnReload: true,
              data: (trips) => _buildContent(context, trips, houses),
              loading: () => const SkeletonTripsBody(),
              error: (error, stack) => RefreshIndicator(
                onRefresh: () => ref.refresh(tripNotifierProvider.future),
                color: colorScheme.primary,
                child: LayoutBuilder(
                  builder: (_, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: _buildErrorState(context, error),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<TripModel> trips,
    List<HouseModel> houses,
  ) {
    if (trips.isEmpty) {
      return _buildScrollableEmpty(
        context,
        DsEmptyState(
          icon: Icons.luggage_outlined,
          title: 'trips.no_trips_title'.tr(),
          ctaLabel: 'trips.no_trips_subtitle'.tr(),
          ctaIcon: Icons.add,
          onCta: () => context.push('/new-trip'),
        ),
      );
    }

    switch (_selectedTab) {
      case TripFilterTab.upcoming:
        final upcoming = upcomingTrips(trips);
        if (upcoming.isEmpty) {
          return _buildScrollableEmpty(
            context,
            DsEmptyState(
              icon: Icons.calendar_today_outlined,
              title: 'trips.no_upcoming'.tr(),
              ctaLabel: 'create_sheet.new_trip'.tr(),
              ctaIcon: Icons.add,
              onCta: () => context.push('/new-trip'),
            ),
          );
        }
        return _buildPile(context, upcoming, houses);

      case TripFilterTab.past:
        final past = pastTrips(trips);
        if (past.isEmpty) {
          return _buildScrollableEmpty(
            context,
            DsEmptyState(
              icon: Icons.history_outlined,
              title: 'trips.no_past'.tr(),
            ),
          );
        }
        return _buildAlbum(
          context,
          groups: [
            for (final entry in groupByYear(past))
              TripAlbumGroup('${entry.key}', entry.value),
          ],
          cancelledStamps: true,
          houses: houses,
        );

      case TripFilterTab.saved:
        final saved = savedTrips(trips);
        if (saved.isEmpty) {
          return _buildScrollableEmpty(
            context,
            DsEmptyState(
              icon: Icons.bookmark_border_outlined,
              title: 'trips.no_saved'.tr(),
              subtitle: 'trips.no_saved_hint'.tr(),
            ),
          );
        }
        return _buildAlbum(
          context,
          groups: [TripAlbumGroup('trips.album.saved_group'.tr(), saved)],
          cancelledStamps: false,
          houses: houses,
        );
    }
  }

  Widget _buildPile(
    BuildContext context,
    List<TripModel> upcoming,
    List<HouseModel> houses,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        0,
        context.spacingMd,
        context.navBarReservedHeight + context.spacingLg,
      ),
      child: PostcardPile(
        itemCount: upcoming.length,
        semanticLabel: (index) => 'trips.pile.semantics'.tr(
          args: [
            '${index + 1}',
            '${upcoming.length}',
            _destinationOf(upcoming[index], houses),
          ],
        ),
        itemBuilder: (context, index) {
          final trip = upcoming[index];
          return GestureDetector(
            onTap: () => context.push('/trips/${trip.id}'),
            onLongPress: () => _handleTripLongPress(trip),
            child: TripPostcard(
              trip: trip,
              destination: _destinationOf(trip, houses),
              onCta: (cta) => _onPileCta(trip, cta),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlbum(
    BuildContext context, {
    required List<TripAlbumGroup> groups,
    required bool cancelledStamps,
    required List<HouseModel> houses,
  }) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(tripNotifierProvider.future),
      color: Theme.of(context).colorScheme.primary,
      child: TripAlbum(
        groups: groups,
        cancelledStamps: cancelledStamps,
        destinationOf: (trip) => _destinationOf(trip, houses),
        onTap: (trip) => context.push('/trips/${trip.id}'),
        onLongPress: _handleTripLongPress,
        onReuse: _handleReuse,
        padding: EdgeInsets.only(
          left: context.spacingMd,
          right: context.spacingMd,
          bottom: context.navBarReservedHeight,
        ),
      ),
    );
  }

  /// Stato vuoto trascinabile per il refresh, centrato nello spazio
  /// disponibile sopra la nav bar.
  Widget _buildScrollableEmpty(BuildContext context, Widget empty) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(tripNotifierProvider.future),
      color: Theme.of(context).colorScheme.primary,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            left: context.spacingMd,
            right: context.spacingMd,
            bottom: context.navBarReservedHeight,
          ),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(child: empty),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return DsErrorState(
      error: error,
      onRetry: () => ref.read(tripNotifierProvider.notifier).refresh(),
    );
  }
}

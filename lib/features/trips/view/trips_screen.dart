import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/monitoring/monitoring_service.dart';
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

  /// Viaggio chiesto dalla rotta (`/trips?focus=<id>`), da portare in cima
  /// alla pila appena compare tra i prossimi.
  String? _focusId;

  /// Ultimo focus già portato in cima: un focus uguale non riporta la pila
  /// indietro dopo uno scorrimento.
  String? _focusApplied;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final focus = GoRouterState.of(context).uri.queryParameters['focus'];
    if (focus != null) _focusId = focus;
  }

  /// Indice in [upcoming] del viaggio da portare in cima, se il focus non è
  /// ancora applicato e il viaggio è tra i prossimi. Null altrimenti.
  int? _pendingFocusIndex(List<TripModel> upcoming) {
    final focus = _focusId;
    if (focus == null || focus == _focusApplied) return null;
    final index = upcoming.indexWhere((trip) => trip.id == focus);
    return index < 0 ? null : index;
  }

  /// Dopo il frame in cui la pila si apre sul focus, il focus è applicato: la
  /// tab e lo scorrimento tornano liberi.
  void _applyFocusAfterFrame() {
    final focus = _focusId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || focus == null || focus != _focusId) return;
      if (focus == _focusApplied) return;
      setState(() {
        _focusApplied = focus;
        _selectedTab = TripFilterTab.upcoming;
      });
    });
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

  /// Riusa il viaggio: copia senza date, poi apre la modifica in modalità
  /// riuso. Se l'utente esce senza salvare, la copia viene eliminata dalla
  /// rotta di modifica.
  Future<void> _handleReuse(TripModel trip) async {
    // Letto prima dell'await: il catch può arrivare dopo il dispose.
    final monitoring = ref.read(monitoringServiceProvider);
    try {
      final newId = await ref
          .read(tripNotifierProvider.notifier)
          .reuseTrip(trip.id);
      if (!mounted) return;
      context.push('/trips/$newId/edit-info?reuse=1');
    } catch (error, stack) {
      monitoring.captureException(error, stackTrace: stack);
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
  /// nome del viaggio. [houseNames] è costruita una volta per build.
  String _destinationOf(TripModel trip, Map<String, String> houseNames) {
    return tripDestinationName(
      trip,
      houseName: houseNames[trip.destinationHouseId],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripNotifierProvider);
    final houses = ref.watch(houseNotifierProvider).valueOrNull ?? const [];
    final houseNames = {
      for (final house in houses) house.id: house.displayName,
    };
    final colorScheme = Theme.of(context).colorScheme;

    final loadedTrips = tripsAsync.valueOrNull;
    final focusIndex = loadedTrips == null
        ? null
        : _pendingFocusIndex(upcomingTrips(loadedTrips));
    if (focusIndex != null) _applyFocusAfterFrame();
    final activeTab = focusIndex == null
        ? _selectedTab
        : TripFilterTab.upcoming;

    return ShellTabScaffold(
      body: Column(
        children: [
          TabHeader(title: 'navigation.trips'.tr()),
          // A sinistra, allineati al titolo della tab, come nel mock. Il
          // margine sta dentro lo scorrimento: su schermi stretti le pillole
          // arrivano fino al bordo.
          SizedBox(
            width: double.infinity,
            child: AppPillTab<TripFilterTab>(
              items: TripFilterTab.values,
              selectedItem: activeTab,
              getLabel: (tab) => tab.label,
              onSelected: (tab) => setState(() => _selectedTab = tab),
              selectedColor: colorScheme.onSurface,
              selectedTextColor: colorScheme.onSurface,
              scrollPadding: EdgeInsets.symmetric(
                horizontal: context.spacingMd,
              ),
            ),
          ),
          SizedBox(height: context.spacingMd),
          Expanded(
            child: tripsAsync.when(
              skipLoadingOnReload: true,
              data: (trips) => _buildContent(
                context,
                trips,
                houseNames,
                tab: activeTab,
                focusIndex: focusIndex,
              ),
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
    Map<String, String> houseNames, {
    required TripFilterTab tab,
    required int? focusIndex,
  }) {
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

    switch (tab) {
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
        return _buildPile(
          context,
          upcoming,
          houseNames,
          focusIndex: focusIndex,
        );

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
          houseNames: houseNames,
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
          houseNames: houseNames,
        );
    }
  }

  Widget _buildPile(
    BuildContext context,
    List<TripModel> upcoming,
    Map<String, String> houseNames, {
    required int? focusIndex,
  }) {
    // La chiave cambia solo quando un focus viene applicato, così la pila si
    // ricrea con [initialIndex] e non a ogni rebuild.
    final pileFocus = focusIndex != null ? _focusId : _focusApplied;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        0,
        context.spacingMd,
        context.navBarReservedHeight + context.spacingLg,
      ),
      child: PostcardPile(
        key: ValueKey('postcard_pile_$pileFocus'),
        itemCount: upcoming.length,
        initialIndex: focusIndex ?? 0,
        semanticLabel: (index) => 'trips.pile.semantics'.tr(
          args: [
            '${index + 1}',
            '${upcoming.length}',
            postcardTitle(
              upcoming[index],
              destination: _destinationOf(upcoming[index], houseNames),
            ),
          ],
        ),
        itemBuilder: (context, index) {
          final trip = upcoming[index];
          return GestureDetector(
            onTap: () => context.push('/trips/${trip.id}'),
            onLongPress: () => _handleTripLongPress(trip),
            child: TripPostcard(
              trip: trip,
              destination: _destinationOf(trip, houseNames),
              houseNames: houseNames,
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
    required Map<String, String> houseNames,
  }) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(tripNotifierProvider.future),
      color: Theme.of(context).colorScheme.primary,
      child: TripAlbum(
        groups: groups,
        cancelledStamps: cancelledStamps,
        destinationOf: (trip) => _destinationOf(trip, houseNames),
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

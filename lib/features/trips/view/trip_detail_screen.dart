import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/ds_button.dart';
import '../../../shared/widgets/ds_not_found_state.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/skeleton/skeleton.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../houses/providers/house_provider.dart';
import '../model/suitcase_progress.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import 'widgets/pack/pack_luggages.dart';
import 'widgets/pack/pack_summary_line.dart';
import 'widgets/pack/pack_weather.dart';
import 'widgets/slots/slot_actions.dart';
import 'widgets/slots/slot_flights.dart';
import 'widgets/slots/slot_edits.dart';
import 'widgets/slots/slot_fill_flow.dart';
import 'widgets/slots/slots_section.dart';
import 'widgets/slots/trip_items_card.dart';

enum _TripMenu { edit, duplicate, save, delete }

/// La valigia del viaggio mentre la si fa: cosa c'è da portare e cosa è già
/// dentro. È la pagina valigia (lo step 2 del nuovo viaggio) vista nel momento
/// dopo: stessi pezzi (riepilogo, meteo, bagagli, oggetti per categoria), ma
/// qui si spunta invece di scegliere.
///
/// Un solo bottone, "Modifica valigia", che apre la pagina valigia; modifica
/// del viaggio, copia, salvati ed eliminazione stanno nel menu ⋮, come nel
/// dettaglio casa.
///
/// Con una valigia AI fatta di posti ([AiPackingResult.hasSlots]) "Cosa
/// porti" mostra anche gli importanti, i "da comprare" e i proposti di
/// PackLog; senza posti resta com'era.
class TripDetailScreen extends ConsumerStatefulWidget {
  final String tripId;

  /// Il posto da riempire all'apertura (`/trips/:id?slot=<id>`). Un id
  /// sconosciuto o di un posto già chiuso si ignora in silenzio.
  final String? initialSlotId;

  const TripDetailScreen({super.key, required this.tripId, this.initialSlotId});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen>
    with TripSlotEdits, TripSlotFlights, TripSlotFill {
  /// Il posto chiesto dal percorso, in attesa che viaggio e case siano
  /// caricati per aprire il foglio.
  String? _pendingSlotId;
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _pendingSlotId = widget.initialSlotId;
  }

  @override
  void didUpdateWidget(TripDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final slotId = widget.initialSlotId;
    if (slotId != null && slotId != oldWidget.initialSlotId) {
      _pendingSlotId = slotId;
    }
  }

  /// Se il percorso chiedeva un posto, lo apre appena viaggio e case sono
  /// caricati: una sola volta, dopo il frame.
  void _resolvePendingSlot(TripModel trip) {
    final id = _pendingSlotId;
    if (id == null) return;
    if (!ref.watch(houseNotifierProvider).hasValue) return;
    _pendingSlotId = null;
    final slot = trip.aiResult?.slots
        ?.where((s) => s.id == id && s.isOpen)
        .firstOrNull;
    if (slot == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) openSlot(slot);
    });
  }

  /// Rimozione e Annulla leggono il viaggio dopo il salvataggio precedente.
  @override
  Future<void> runSuitcaseMutation(Future<void> Function() change) {
    return _container
        .read(tripNotifierProvider.notifier)
        .serializeEdit(tripId, change);
  }

  Future<void> _changeTrip(TripModel Function(TripModel) change) {
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = container.read(tripNotifierProvider.notifier);
    final id = tripId;
    return runSuitcaseMutation(() async {
      final latest = container
          .read(tripNotifierProvider)
          .valueOrNull
          ?.where((t) => t.id == id)
          .firstOrNull;
      if (latest != null) await notifier.updateTrip(change(latest));
    });
  }

  void _toggleInventoryItem(TripItem item) {
    final notifier = ref.read(tripNotifierProvider.notifier);
    final id = tripId;
    unawaited(runSuitcaseMutation(() => notifier.toggleItemCheck(id, item.id)));
  }

  /// Agisce sullo snapshot del viaggio; l'oggetto nell'inventario resta intatto.
  Future<void> _removeInventoryItem(TripItem item) {
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = container.read(tripNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final id = tripId;
    TripModel? currentTrip() => container
        .read(tripNotifierProvider)
        .valueOrNull
        ?.where((t) => t.id == id)
        .firstOrNull;
    return runSuitcaseMutation(() async {
      try {
        final trip = currentTrip();
        if (trip == null) return;
        final index = trip.items.indexWhere((i) => i.id == item.id);
        if (index < 0) return;
        final removed = trip.items[index];
        await notifier.updateTrip(
          trip.copyWith(
            items: trip.items.where((i) => i.id != item.id).toList(),
            updatedAt: DateTime.now(),
          ),
        );
        if (!mounted) return;
        Future<void> restore() async {
          try {
            final latest = currentTrip();
            if (latest == null || latest.items.any((i) => i.id == removed.id)) {
              return;
            }
            final items = [...latest.items];
            items.insert(index.clamp(0, items.length).toInt(), removed);
            await notifier.updateTrip(
              latest.copyWith(items: items, updatedAt: DateTime.now()),
            );
          } catch (_) {
            if (messenger.mounted) {
              AppSnackBar.showErrorOn(messenger, 'errors.save_error'.tr());
            }
          }
        }

        AppSnackBar.showUndo(
          context,
          'trips.pack.ai.removed'.tr(args: [removed.name]),
          onUndo: () => unawaited(runSuitcaseMutation(restore)),
        );
      } catch (_) {
        if (mounted) AppSnackBar.showError(context, 'errors.save_error'.tr());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripNotifierProvider);

    return tripsAsync.when(
      data: (trips) {
        final trip = trips.where((t) => t.id == tripId).firstOrNull;
        if (trip == null) return _notFound(context);
        _resolvePendingSlot(trip);
        return _TripDetail(
          trip: trip,
          slotActions: SlotActions(
            open: openSlot,
            markToBuy: (slot) => markSlotToBuy(slot),
            toggle: toggleSlot,
            remove: (slot) => unawaited(removeSlot(slot, confirm: true)),
            dismiss: (slot) => unawaited(removeSlot(slot, confirm: false)),
            removeItem: (item) => unawaited(_removeInventoryItem(item)),
            toggleItem: _toggleInventoryItem,
            changeTrip: _changeTrip,
            runMutation: runSuitcaseMutation,
            rowKey: rowKey,
            flying: flying,
            flyKitItems: flyKitItems,
          ),
        );
      },
      loading: () => const SkeletonTripDetailScreen(),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text('common.error'.tr())),
        body: DsErrorState(
          error: error,
          title: 'errors.load_trips'.tr(),
          onRetry: () => ref.read(tripNotifierProvider.notifier).refresh(),
        ),
      ),
    );
  }

  Widget _notFound(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('trips.not_found'.tr())),
      body: DsNotFoundState(
        icon: Icons.luggage_outlined,
        title: 'trips.not_found'.tr(),
        actionLabel: 'common.back_to_trips'.tr(),
        onAction: () => context.go('/trips'),
      ),
    );
  }
}

class _TripDetail extends ConsumerWidget {
  final TripModel trip;
  final SlotActions slotActions;

  const _TripDetail({required this.trip, required this.slotActions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houses = ref.watch(houseNotifierProvider).valueOrNull ?? const [];
    final destinationHouse = houses
        .where((h) => h.id == trip.destinationHouseId)
        .firstOrNull;
    // Con i posti la valigia c'è anche senza oggetti propri.
    final hasItems = !SuitcaseProgress.of(trip).isEmpty;

    return StickyCtaScaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<_TripMenu>(
            key: const Key('trip_detail_menu'),
            icon: const Icon(Icons.more_vert),
            onSelected: (choice) => _onMenu(context, ref, choice),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _TripMenu.edit,
                child: Text('trips.detail.edit_trip'.tr()),
              ),
              PopupMenuItem(
                value: _TripMenu.duplicate,
                child: Text('trips.detail.duplicate'.tr()),
              ),
              PopupMenuItem(
                value: _TripMenu.save,
                child: Text(
                  trip.isSaved
                      ? 'trips.detail.unsave'.tr()
                      : 'trips.detail.save'.tr(),
                ),
              ),
              PopupMenuItem(
                value: _TripMenu.delete,
                child: Text(
                  'common.delete'.tr(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomContent: DsButton(
        key: const Key('trip_detail_cta'),
        label: hasItems
            ? 'trips.detail.edit_suitcase'.tr()
            : 'trips.pack.title'.tr(),
        icon: hasItems ? Icons.edit_outlined : Icons.luggage_outlined,
        expand: true,
        onPressed: () => context.push('/trips/${trip.id}/edit-items'),
      ),
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            context.spacingMd,
            context.spacingSm,
            context.spacingMd,
            context.spacingLg + context.ctaReservedHeight,
          ),
          children: [
            // Il riepilogo è la cartolina del viaggio: toccarlo apre la modifica
            // di date e tappe.
            InkWell(
              key: const Key('trip_detail_summary'),
              borderRadius: BorderRadius.circular(
                AppConstants.cardBorderRadius,
              ),
              onTap: () => context.push('/trips/${trip.id}/edit-info'),
              child: PackSummaryLine(
                trip: trip,
                destinationHouseName: destinationHouse?.displayName,
                houseNames: {for (final h in houses) h.id: h.displayName},
              ),
            ),
            PackWeatherSection(trip: trip),
            PackLuggages(trip.luggages),
            if (trip.aiResult?.hasSlots ?? false)
              SlotsSection(trip: trip, actions: slotActions)
            else
              PlainItemsSection(trip: trip),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    _TripMenu choice,
  ) async {
    final notifier = ref.read(tripNotifierProvider.notifier);
    switch (choice) {
      case _TripMenu.edit:
        context.push('/trips/${trip.id}/edit-info');
      case _TripMenu.duplicate:
        final ok = await ErrorRetryDialog.executeWithRetry(
          context: context,
          operation: () => slotActions.runMutation(() async {
            await notifier.duplicateTrip(
              trip.id,
              nameSuffix: 'trips.duplicate_suffix'.tr(),
            );
          }),
          errorTitle: 'errors.save_error'.tr(),
          errorMessage: 'errors.duplicate_trip_failed'.tr(args: [trip.name]),
        );
        if (ok && context.mounted) {
          AppSnackBar.showSuccess(context, 'trips.detail.duplicated'.tr());
        }
      case _TripMenu.save:
        await ErrorRetryDialog.executeWithRetry(
          context: context,
          operation: () =>
              slotActions.runMutation(() => notifier.toggleSaved(trip.id)),
          errorTitle: 'errors.save_error'.tr(),
          errorMessage: 'errors.save_trip_failed'.tr(args: [trip.name]),
        );
      case _TripMenu.delete:
        await _delete(context, ref);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: 'common.trip_type'.tr(),
      itemName: trip.name,
    );
    if (confirmed != true || !context.mounted) return;
    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => slotActions.runMutation(
        () => ref.read(tripNotifierProvider.notifier).deleteTrip(trip.id),
      ),
      errorTitle: 'errors.delete_error'.tr(),
      errorMessage: 'errors.delete_trip_failed'.tr(args: [trip.name]),
    );
    if (success && context.mounted) context.pop();
  }
}

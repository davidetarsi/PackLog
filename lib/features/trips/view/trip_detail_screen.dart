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
import '../../../shared/widgets/ds_section_title.dart';
import '../../../shared/widgets/ds_not_found_state.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/skeleton/skeleton.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../houses/providers/house_provider.dart';
import '../../items/model/item_model.dart';
import '../../items/providers/item_provider.dart';
import '../../luggages/model/luggage_model.dart';
import '../../luggages/providers/luggage_provider.dart';
import '../model/suitcase_progress.dart';
import '../model/ai_packing.dart';
import '../model/trip_model.dart';
import '../services/ai_packing_launcher.dart';
import '../services/suitcase_analytics.dart';
import '../services/suitcase_outdated.dart';
import 'widgets/trip_changed_notice.dart';
import '../providers/trip_provider.dart';
import 'widgets/pack/pack_luggage_selector.dart';
import 'widgets/ai/ai_pack_reassurance.dart';
import 'widgets/ai/ai_pack_rows.dart';
import 'widgets/ai/ai_pack_item_sheet.dart';
import 'widgets/pack/pack_summary_line.dart';
import 'widgets/pack/pack_weather.dart';
import 'widgets/slots/slot_actions.dart';
import 'widgets/slots/suitcase_progress_header.dart';
import 'widgets/slots/slot_flights.dart';
import 'widgets/slots/slot_edits.dart';
import 'widgets/slots/slot_fill_flow.dart';
import 'widgets/slots/slots_section.dart';
import 'widgets/slots/trip_items_card.dart';

enum _TripMenu { edit, regenerate, duplicate, save, delete }

/// La valigia del viaggio: riepilogo, meteo, bagagli e oggetti per categoria,
/// per ogni viaggio (a mano o con la proposta AI). Qui si spunta, si tolgono
/// oggetti, si cambiano le copie e si apre la scheda dell'oggetto.
///
/// Un solo bottone, "Aggiungi oggetti", che apre la pagina di aggiunta (dopo
/// la prima revisione AI c'è "Fatto" al suo posto); modifica del viaggio,
/// copia, salvati ed eliminazione stanno nel menu ⋮, come nel dettaglio casa.
///
/// Con una valigia AI fatta di posti ([AiPackingResult.hasSlots]) "Cosa
/// porti" mostra anche gli importanti, i "da comprare" e i proposti di
/// PackLog.
class TripDetailScreen extends ConsumerStatefulWidget {
  final String tripId;
  final bool showNeeds;
  final bool firstReview;

  /// Il posto da riempire all'apertura (`/trips/:id?slot=<id>`). Un id
  /// sconosciuto o di un posto già chiuso si ignora in silenzio.
  final String? initialSlotId;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    this.initialSlotId,
    this.showNeeds = false,
    this.firstReview = false,
  });

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

  Future<void> _addInventoryItem(ItemModel item, int copies) async {
    final notifier = _container.read(tripNotifierProvider.notifier);
    final id = tripId;
    try {
      await runSuitcaseMutation(() async {
        final latest = _container
            .read(tripNotifierProvider)
            .valueOrNull
            ?.where((trip) => trip.id == id)
            .firstOrNull;
        if (latest == null ||
            latest.items.any((entry) => entry.id == item.id)) {
          return;
        }
        await notifier.updateTrip(
          latest.copyWith(
            items: [
              ...latest.items,
              TripItem(
                id: item.id,
                name: item.name,
                category: item.category,
                quantity: copies,
                originHouseId: item.houseId,
              ),
            ],
            updatedAt: DateTime.now(),
          ),
        );
      });
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, 'errors.save_error'.tr());
    }
  }

  void _toggleTripLuggage(LuggageModel luggage) {
    unawaited(() async {
      try {
        await _changeTrip((latest) {
          final selected = latest.luggages.any(
            (entry) => entry.id == luggage.id,
          );
          return latest.copyWith(
            luggages: selected
                ? latest.luggages
                      .where((entry) => entry.id != luggage.id)
                      .toList()
                : [...latest.luggages, luggage],
            updatedAt: DateTime.now(),
          );
        });
      } catch (_) {
        if (mounted) AppSnackBar.showError(context, 'errors.save_error'.tr());
      }
    }());
  }

  void _reconcileTripLuggages(List<LuggageModel> created) {
    unawaited(() async {
      final createdIds = created.map((luggage) => luggage.id).toSet();
      try {
        await _changeTrip((latest) {
          final available = ref.read(luggageNotifierProvider).valueOrNull;
          if (available == null) return latest;
          final selectedIds = latest.luggages
              .map((luggage) => luggage.id)
              .toSet();
          return latest.copyWith(
            luggages: [
              for (final luggage in available)
                if (selectedIds.contains(luggage.id) ||
                    createdIds.contains(luggage.id))
                  luggage,
            ],
            updatedAt: DateTime.now(),
          );
        });
      } catch (_) {
        if (mounted) AppSnackBar.showError(context, 'errors.save_error'.tr());
      }
    }());
  }

  Future<void> _openTripItem(TripItem item) async {
    final trip = _container
        .read(tripNotifierProvider)
        .valueOrNull
        ?.where((entry) => entry.id == tripId)
        .firstOrNull;
    if (trip == null) return;
    // La casa dell'oggetto, non quella della proposta AI: la valigia a mano non
    // ha `aiResult` e gli oggetti possono venire da case diverse.
    final houseId = item.originHouseId.isNotEmpty
        ? item.originHouseId
        : trip.aiResult?.houseId;
    ItemModel? inventoryItem;
    if (houseId != null) {
      try {
        final items = await _container.read(
          itemNotifierProvider(houseId).future,
        );
        inventoryItem = items.where((entry) => entry.id == item.id).firstOrNull;
      } catch (_) {
        inventoryItem = null;
      }
    }
    if (!mounted) return;
    final proposed = trip.aiResult?.proposal
        .where((entry) => entry.itemId == item.id)
        .firstOrNull;
    await showAiPackItemSheet(
      context,
      item: item,
      subCategory: inventoryItem == null
          ? null
          : subCategoryByIdOf([inventoryItem])[inventoryItem.id],
      available: inventoryItem?.quantity ?? 1,
      reason: proposed?.reason,
      inDeparture: proposed?.inDeparture ?? false,
      onQuantity: (quantity) async {
        try {
          await _changeTrip(
            (latest) => latest.copyWith(
              items: [
                for (final entry in latest.items)
                  if (entry.id == item.id)
                    entry.copyWith(
                      quantity: quantity,
                      isChecked: quantity > entry.quantity
                          ? false
                          : entry.isChecked,
                    )
                  else
                    entry,
              ],
              updatedAt: DateTime.now(),
            ),
          );
        } catch (_) {
          if (mounted) AppSnackBar.showError(context, 'errors.save_error'.tr());
          rethrow;
        }
      },
      onRemove: () => unawaited(_removeInventoryItem(item)),
    );
  }

  void _toggleInventoryItem(TripItem item) {
    final notifier = ref.read(tripNotifierProvider.notifier);
    final id = tripId;
    unawaited(() async {
      try {
        await notifier.toggleItemCheck(id, item.id);
      } catch (_) {
        if (mounted) AppSnackBar.showError(context, 'errors.save_error'.tr());
      }
    }());
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
          showNeeds: widget.showNeeds || widget.initialSlotId != null,
          firstReview: widget.firstReview,
          onAddInventory: _addInventoryItem,
          onOpenItem: (item) => unawaited(_openTripItem(item)),
          onToggleLuggage: _toggleTripLuggage,
          onCreatedLuggages: _reconcileTripLuggages,
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
  final bool showNeeds;
  final bool firstReview;
  final Future<void> Function(ItemModel item, int copies) onAddInventory;
  final ValueChanged<TripItem> onOpenItem;
  final ValueChanged<LuggageModel> onToggleLuggage;
  final ValueChanged<List<LuggageModel>> onCreatedLuggages;

  const _TripDetail({
    required this.trip,
    required this.slotActions,
    required this.showNeeds,
    required this.firstReview,
    required this.onAddInventory,
    required this.onOpenItem,
    required this.onToggleLuggage,
    required this.onCreatedLuggages,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houses = ref.watch(houseNotifierProvider).valueOrNull ?? const [];
    final destinationHouse = houses
        .where((h) => h.id == trip.destinationHouseId)
        .firstOrNull;
    final hasSlots = trip.aiResult?.hasSlots ?? false;
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
              if (hasSlots)
                PopupMenuItem(
                  value: _TripMenu.regenerate,
                  child: Text('trips.pack.ai.regenerate'.tr()),
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
      bottomContent: firstReview && !showNeeds
          ? DsButton(
              key: const Key('trip_detail_cta'),
              label: 'trips.pack.done'.tr(),
              icon: Icons.check,
              expand: true,
              onPressed: () async {
                await slotActions.runMutation(() async {});
                if (context.mounted) context.go('/trips');
              },
            )
          : showNeeds && hasSlots
          ? null
          : DsButton(
              key: const Key('trip_detail_cta'),
              label: 'trips.detail.add_items'.tr(),
              icon: Icons.add,
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
            if (!showNeeds && suitcaseOutdated(trip, now: DateTime.now()))
              Padding(
                padding: EdgeInsets.only(bottom: context.spacingMd),
                child: TripChangedNotice(
                  onRedo: () => _regenerate(context, ref),
                  onClose: () => unawaited(
                    slotActions.changeTrip(
                      (latest) => latest.copyWith(
                        aiResult: latest.aiResult?.copyWith(
                          changeNoticeDismissed: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (hasSlots && !showNeeds)
              Padding(
                padding: EdgeInsets.only(
                  top: context.spacingSm,
                  bottom: context.spacingMd,
                ),
                child: AiPackRows(
                  warnings: const [],
                  readIds: const {},
                  reasons: trip.aiResult!.reasons,
                  slots: trip.aiResult!.slots ?? const [],
                  needsCounts: _needsCounts(trip),
                  onNeeds: () => context.push('/trips/${trip.id}/needs'),
                  onSearch: (_) {},
                  onDismiss: (_) {},
                ),
              ),
            if (hasSlots && !showNeeds && trip.notDeparted)
              Padding(
                padding: EdgeInsets.only(bottom: context.spacingMd),
                child: const AiPackReassurance(),
              ),
            if (hasSlots && !showNeeds) ...[
              TripSlotsContext(trip: trip, actions: slotActions),
              SizedBox(height: context.spacingMd),
            ],
            if (showNeeds && hasSlots)
              SlotsSection(trip: trip, actions: slotActions)
            else ...[
              PackWeatherSection(trip: trip),
              DsSectionTitle('trips.pack.luggages'.tr()),
              PackLuggageSelector(
                selectedIds: trip.luggages.map((luggage) => luggage.id).toSet(),
                onToggle: onToggleLuggage,
                onCreated: onCreatedLuggages,
              ),
              DsSectionTitle(
                hasSlots
                    ? 'trips.detail.owned_items_title'.tr()
                    : 'trips.pack.items'.tr(),
              ),
              if (!hasSlots && hasItems)
                SuitcaseProgressHeader(progress: SuitcaseProgress.of(trip)),
              SuitcaseItemsSection(
                trip: trip,
                // Senza posti niente proposta: niente ricerca nella casa.
                houseId: hasSlots ? trip.aiResult?.houseId : null,
                checklistEnabled: !firstReview,
                onAddInventory: onAddInventory,
                onRemoveItem: firstReview ? slotActions.removeItem : null,
                onToggleItem: slotActions.toggleItem,
                onOpenItem: onOpenItem,
                rowKey: slotActions.rowKey,
                flying: slotActions.flying,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "Rigenera" e "Rifalla con AI": il foglio si apre sopra il dettaglio. Se
  /// la valigia ha già oggetti, il lanciatore chiede prima conferma.
  Future<AiPackingSetup?> _regenerate(BuildContext context, WidgetRef ref) =>
      startAiPacking(context, ref, trip: trip, isNew: false);

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    _TripMenu choice,
  ) async {
    final notifier = ref.read(tripNotifierProvider.notifier);
    switch (choice) {
      case _TripMenu.edit:
        context.push('/trips/${trip.id}/edit-info');
      case _TripMenu.regenerate:
        unawaited(_regenerate(context, ref));
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

({int important, int useful, int toBuy}) _needsCounts(TripModel trip) {
  final slots = trip.aiResult?.slots ?? const <AiSlot>[];
  return (
    important: slots
        .where((s) => s.level == AiSlotLevel.important && s.isSuggested)
        .length,
    useful: slots
        .where((s) => s.level == AiSlotLevel.useful && s.isSuggested)
        .length,
    toBuy: slots.where((s) => s.isToBuy).length,
  );
}

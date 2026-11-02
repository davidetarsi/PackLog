import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/ds_button.dart';
import '../../../shared/widgets/ds_not_found_state.dart';
import '../../../shared/widgets/ds_section_title.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/skeleton/skeleton.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../houses/providers/house_provider.dart';
import '../../items/model/item_model.dart';
import '../model/ai_packing.dart';
import '../model/suitcase_progress.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import 'widgets/pack/pack_parts.dart';
import 'widgets/pack/pack_summary_line.dart';
import 'widgets/pack/pack_weather.dart';
import 'widgets/slots/slot_edits.dart';
import 'widgets/slots/slot_focus.dart';
import 'widgets/slots/slot_rapid_fire_bar.dart';
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
    with TripSlotEdits {
  /// Il posto che la barra Rapid Fire sta riempiendo; `null` = barra chiusa.
  /// La barra si vede solo finché il posto è ancora aperto.
  String? _openSlotId;

  /// Gli oggetti scritti in questa apertura: stanno nel riquadro, non fra
  /// quelli dell'utente, finché il posto resta aperto.
  List<TripItem> _written = const [];

  /// La card del gruppo con il posto aperto, da portare in cima.
  final _openCardKey = GlobalKey();

  /// Il posto riaperto con "Presa" da "da comprare": riempirlo vuol dire che
  /// l'hai comprato.
  String? _boughtSlotId;

  /// Il posto chiesto dal percorso, in attesa che viaggio e case siano
  /// caricati per aprire la barra.
  String? _pendingSlotId;

  @override
  void initState() {
    super.initState();
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

  /// Il posto con la barra aperta, se esiste ancora ed è aperto.
  AiSlot? _barSlot(TripModel trip) {
    final id = _openSlotId;
    if (id == null) return null;
    return trip.aiResult?.slots
        ?.where((s) => s.id == id && s.isOpen)
        .firstOrNull;
  }

  /// Apre la barra per riempire [slot] con uno dei propri oggetti: la toccano
  /// la riga di un proposto, l'aggiunta sulla card di un importante e
  /// "Presa" su un "da comprare". Se la casa di partenza non c'è più la barra
  /// non si apre e uno snack lo dice.
  void _openSlot(AiSlot slot) {
    final notifier = ref.read(tripNotifierProvider.notifier);
    final trips = ref.read(tripNotifierProvider).valueOrNull;
    final houseId = trips
        ?.where((t) => t.id == tripId)
        .firstOrNull
        ?.aiResult
        ?.houseId;
    final houses = ref.read(houseNotifierProvider).valueOrNull;
    if (houseId == null ||
        houses == null ||
        !houses.any((h) => h.id == houseId)) {
      AppSnackBar.showInfo(context, 'trips.slots.no_house'.tr());
      return;
    }
    // "Presa" su una proposta da comprare: torna nella valigia, in cima ai
    // proposti.
    if (slot.toBuy && slot.level == AiSlotLevel.useful) {
      unawaited(updateSlot(notifier, slot, (s) => s.copyWith(toBuy: false)));
    }
    setState(() {
      _openSlotId = slot.id;
      _written = const [];
      _boughtSlotId = slot.toBuy ? slot.id : null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _bringOpenCardUp());
  }

  /// Porta in cima alla vista la card con il posto aperto.
  void _bringOpenCardUp() {
    final card = _openCardKey.currentContext;
    if (!mounted || card == null) return;
    Scrollable.ensureVisible(
      card,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotion.slow,
      curve: AppMotion.standard,
    );
  }

  /// Richiude il posto: gli oggetti scritti tornano fra quelli dell'utente.
  void _closeBar() {
    if (_openSlotId == null) return;
    setState(() {
      _openSlotId = null;
      _written = const [];
      _boughtSlotId = null;
    });
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
      if (mounted) _openSlot(slot);
    });
  }

  /// L'oggetto appena creato dalla barra entra in valigia e scala il posto.
  /// Se il salvataggio non va lo dice (l'oggetto resta nella casa).
  Future<void> _fillSlot(AiSlot slot, ItemModel item) async {
    final notifier = ref.read(tripNotifierProvider.notifier);
    final analytics = ref.read(analyticsServiceProvider);
    // Un posto "da comprare" si apre solo con "Presa" (la riga, o `?slot=`
    // dalla vista Da comprare): riempirlo vuol dire che l'hai comprato.
    final bought = slot.toBuy || slot.id == _boughtSlotId;
    final packed = TripItem(
      id: item.id,
      name: item.name,
      category: item.category,
      quantity: item.quantity ?? 1,
      originHouseId: item.houseId,
    );
    if (_openSlotId == slot.id) {
      setState(() => _written = [..._written, packed]);
    }
    try {
      await notifier.fillAiSlot(tripId, slot.id, packed);
      if (bought) {
        unawaited(
          analytics.logEvent(
            'slot_bought',
            properties: {'level': slot.level.name},
          ),
        );
      }
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, 'errors.save_error'.tr());
    }
  }

  /// "Da comprare" sulla barra: segna il posto e chiude la barra.
  void _barToBuy(AiSlot slot) {
    _closeBar();
    unawaited(markSlotToBuy(slot, from: 'bar'));
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripNotifierProvider);

    return tripsAsync.when(
      data: (trips) {
        final trip = trips.where((t) => t.id == tripId).firstOrNull;
        if (trip == null) return _notFound(context);
        _resolvePendingSlot(trip);
        final barSlot = _barSlot(trip);
        return _TripDetail(
          trip: trip,
          barSlot: barSlot,
          openSlot: barSlot == null
              ? null
              : OpenSlotState(
                  slot: barSlot,
                  written: _written,
                  cardKey: _openCardKey,
                ),
          onFillSlot: _fillSlot,
          onCloseBar: _closeBar,
          onBarToBuy: _barToBuy,
          slotActions: SlotActions(
            open: _openSlot,
            close: _closeBar,
            markToBuy: (slot) => markSlotToBuy(slot),
            toggle: toggleSlot,
            toggleItem: (item) => ref
                .read(tripNotifierProvider.notifier)
                .toggleItemCheck(tripId, item.id),
            remove: (slot) => unawaited(removeSlot(slot, confirm: true)),
            dismiss: (slot) => unawaited(removeSlot(slot, confirm: false)),
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

  /// Il posto che la barra Rapid Fire sta riempiendo; `null` = barra chiusa e
  /// al suo posto "Modifica valigia".
  final AiSlot? barSlot;

  /// Il posto aperto nella lista, con gli oggetti scritti; `null` se la
  /// barra è chiusa.
  final OpenSlotState? openSlot;
  final void Function(AiSlot slot, ItemModel item) onFillSlot;
  final VoidCallback onCloseBar;
  final ValueChanged<AiSlot> onBarToBuy;

  const _TripDetail({
    required this.trip,
    required this.slotActions,
    required this.barSlot,
    required this.openSlot,
    required this.onFillSlot,
    required this.onCloseBar,
    required this.onBarToBuy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houses = ref.watch(houseNotifierProvider).valueOrNull ?? const [];
    final destinationHouse = houses
        .where((h) => h.id == trip.destinationHouseId)
        .firstOrNull;
    // Con i posti la valigia c'è anche senza oggetti propri.
    final hasItems = !SuitcaseProgress.of(trip).isEmpty;
    final bar = barSlot;

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
      // Mentre si riempie un posto la barra Rapid Fire prende il posto del
      // bottone.
      bottomContent: bar != null
          ? SlotRapidFireBar(
              slot: bar,
              houseId: trip.aiResult!.houseId,
              onItemCreated: (item) => onFillSlot(bar, item),
              onClose: onCloseBar,
              onToBuy: bar.toBuy ? null : () => onBarToBuy(bar),
            )
          : DsButton(
              key: const Key('trip_detail_cta'),
              label: hasItems
                  ? 'trips.detail.edit_suitcase'.tr()
                  : 'trips.pack.title'.tr(),
              icon: hasItems ? Icons.edit_outlined : Icons.luggage_outlined,
              expand: true,
              onPressed: () => context.push('/trips/${trip.id}/edit-items'),
            ),
      ctaHeightOverride: bar == null
          ? null
          : StickyCtaScaffold.standardHeight(context) +
                kMinInteractiveDimension +
                context.spacingXs,
      // Con un posto aperto il resto si spenge, e in fondo c'è spazio per
      // portare in cima anche l'ultimo gruppo.
      body: LayoutBuilder(
        builder: (context, viewport) {
          final open = openSlot;
          Widget dim(Widget child) => SlotFocus(
            active: open != null,
            onTapOutside: onCloseBar,
            child: child,
          );
          return ListView(
            padding: EdgeInsets.fromLTRB(
              context.spacingMd,
              context.spacingSm,
              context.spacingMd,
              context.spacingLg + context.ctaReservedHeight,
            ),
            children: [
              dim(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Il riepilogo è la cartolina del viaggio: toccarlo apre
                    // la modifica di date e tappe.
                    InkWell(
                      key: const Key('trip_detail_summary'),
                      borderRadius: BorderRadius.circular(
                        AppConstants.cardBorderRadius,
                      ),
                      onTap: () => context.push('/trips/${trip.id}/edit-info'),
                      child: PackSummaryLine(
                        trip: trip,
                        destinationHouseName: destinationHouse?.displayName,
                        houseNames: {
                          for (final h in houses) h.id: h.displayName,
                        },
                      ),
                    ),
                    PackWeatherSection(trip: trip),
                    if (trip.luggages.isNotEmpty) ...[
                      DsSectionTitle('trips.pack.luggages'.tr()),
                      Wrap(
                        spacing: context.spacingSm,
                        runSpacing: context.spacingSm,
                        children: [
                          for (final luggage in trip.luggages)
                            PackPill(
                              label: luggage.name,
                              icon: Icons.luggage_outlined,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (trip.aiResult?.hasSlots ?? false)
                SlotsSection(trip: trip, actions: slotActions, open: open)
              else
                PlainItemsSection(trip: trip),
              if (open != null) dim(SizedBox(height: viewport.maxHeight)),
            ],
          );
        },
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
          operation: () => notifier.duplicateTrip(
            trip.id,
            nameSuffix: 'trips.duplicate_suffix'.tr(),
          ),
          errorTitle: 'errors.save_error'.tr(),
          errorMessage: 'errors.duplicate_trip_failed'.tr(args: [trip.name]),
        );
        if (ok && context.mounted) {
          AppSnackBar.showSuccess(context, 'trips.detail.duplicated'.tr());
        }
      case _TripMenu.save:
        await ErrorRetryDialog.executeWithRetry(
          context: context,
          operation: () => notifier.toggleSaved(trip.id),
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
      operation: () =>
          ref.read(tripNotifierProvider.notifier).deleteTrip(trip.id),
      errorTitle: 'errors.delete_error'.tr(),
      errorMessage: 'errors.delete_trip_failed'.tr(args: [trip.name]),
    );
    if (success && context.mounted) context.pop();
  }
}

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
import '../../../shared/widgets/ds_checkbox.dart';
import '../../../shared/widgets/ds_not_found_state.dart';
import '../../../shared/widgets/ds_group_header.dart';
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
import 'widgets/slots/slot_rapid_fire_bar.dart';
import 'widgets/slots/slot_widgets.dart';

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

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  String get tripId => widget.tripId;

  /// Il posto che la barra Rapid Fire sta riempiendo; `null` = barra chiusa.
  /// La barra si vede solo finché il posto è ancora aperto.
  String? _openSlotId;

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
    setState(() => _openSlotId = slot.id);
  }

  void _closeBar() {
    if (_openSlotId != null) setState(() => _openSlotId = null);
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
    try {
      await notifier.fillAiSlot(
        tripId,
        slot.id,
        TripItem(
          id: item.id,
          name: item.name,
          category: item.category,
          quantity: item.quantity ?? 1,
          originHouseId: item.houseId,
        ),
      );
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, 'errors.save_error'.tr());
    }
  }

  /// "Da comprare" sulla barra: segna il posto e chiude la barra.
  void _barToBuy(AiSlot slot) {
    _closeBar();
    unawaited(_markToBuy(slot));
  }

  /// "Da comprare" sulla card di un importante: la card diventa una riga
  /// "da comprare"; Annulla la riporta.
  Future<void> _markToBuy(AiSlot slot) async {
    // Il notifier si legge ora: Annulla può arrivare quando la pagina non c'è
    // più, e allora `ref` non si può usare.
    final notifier = ref.read(tripNotifierProvider.notifier);
    final saved = await _updateSlot(
      notifier,
      slot,
      (s) => s.copyWith(toBuy: true),
    );
    if (!saved || !mounted) return;
    AppSnackBar.showUndo(
      context,
      'trips.slots.marked_to_buy'.tr(),
      onUndo: () => unawaited(
        _updateSlot(notifier, slot, (s) => s.copyWith(toBuy: false)),
      ),
    );
  }

  /// La casella di un proposto, quando non si sta più sistemando.
  void _toggleSlot(AiSlot slot) {
    unawaited(
      _updateSlot(
        ref.read(tripNotifierProvider.notifier),
        slot,
        (s) => s.copyWith(checked: !s.checked),
      ),
    );
  }

  /// Cambia il posto e salva; se il salvataggio non va lo dice (se la pagina
  /// c'è ancora) e torna `false` (il posto è già tornato com'era).
  Future<bool> _updateSlot(
    TripNotifier notifier,
    AiSlot slot,
    AiSlot Function(AiSlot) change,
  ) async {
    try {
      await notifier.updateAiSlot(tripId, slot.id, change);
      return true;
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, 'errors.save_error'.tr());
      return false;
    }
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
          barSlot: _barSlot(trip),
          onFillSlot: _fillSlot,
          onCloseBar: _closeBar,
          onBarToBuy: _barToBuy,
          slotActions: _SlotActions(
            open: _openSlot,
            markToBuy: _markToBuy,
            toggle: _toggleSlot,
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

/// Cosa si può fare sui posti della valigia; li gestisce lo schermo.
class _SlotActions {
  const _SlotActions({
    required this.open,
    required this.markToBuy,
    required this.toggle,
  });

  final ValueChanged<AiSlot> open;
  final ValueChanged<AiSlot> markToBuy;
  final ValueChanged<AiSlot> toggle;
}

class _TripDetail extends ConsumerWidget {
  final TripModel trip;
  final _SlotActions slotActions;

  /// Il posto che la barra Rapid Fire sta riempiendo; `null` = barra chiusa e
  /// al suo posto "Modifica valigia".
  final AiSlot? barSlot;
  final void Function(AiSlot slot, ItemModel item) onFillSlot;
  final VoidCallback onCloseBar;
  final ValueChanged<AiSlot> onBarToBuy;

  const _TripDetail({
    required this.trip,
    required this.slotActions,
    required this.barSlot,
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
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            context.spacingMd,
            context.spacingSm,
            context.spacingMd,
            context.spacingLg + context.ctaReservedHeight,
          ),
          children: [
            // Il riepilogo è la cartolina del viaggio: toccarlo apre la
            // modifica di date e tappe.
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
            if (trip.luggages.isNotEmpty) ...[
              DsSectionTitle('trips.pack.luggages'.tr()),
              Wrap(
                spacing: context.spacingSm,
                runSpacing: context.spacingSm,
                children: [
                  for (final luggage in trip.luggages)
                    PackPill(label: luggage.name, icon: Icons.luggage_outlined),
                ],
              ),
            ],
            if (trip.aiResult?.hasSlots ?? false)
              _SlotsSection(trip: trip, actions: slotActions)
            else
              _ItemsSection(trip: trip),
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

/// "Cosa porti": quanti sono già in valigia, poi gli oggetti per categoria
/// in ordine canonico, come nella pagina valigia e nella casa.
class _ItemsSection extends ConsumerWidget {
  final TripModel trip;

  const _ItemsSection({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final items = trip.items;

    if (items.isEmpty) return const _EmptySuitcase();

    final packed = trip.completedCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionTitle('trips.pack.items'.tr()),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppConstants.pillBorderRadius,
                ),
                child: LinearProgressIndicator(
                  key: const Key('trip_detail_progress'),
                  value: packed / items.length,
                  minHeight: context.spacingXs,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: cs.onSurface,
                ),
              ),
            ),
            SizedBox(width: context.spacingSm),
            Text(
              'trips.detail.packed_count'.tr(
                args: [packed.toString(), items.length.toString()],
              ),
              style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        for (final category in ItemCategory.values)
          if (items.any((item) => item.category == category)) ...[
            DsGroupHeader(
              label: category.displayName,
              count: items.where((i) => i.category == category).length,
            ),
            _ItemsCard(
              tripId: trip.id,
              items: items.where((i) => i.category == category).toList(),
            ),
          ],
      ],
    );
  }
}

/// Valigia vuota: niente oggetti (e niente posti).
class _EmptySuitcase extends StatelessWidget {
  const _EmptySuitcase();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.spacingLg),
      child: DsEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'trips.no_items_in_list'.tr(),
      ),
    );
  }
}

/// Gli oggetti di un gruppo, uno per riga, da spuntare.
class _ItemsCard extends ConsumerWidget {
  final String tripId;
  final List<TripItem> items;

  const _ItemsCard({required this.tripId, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: context.groupSurface,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final item in items)
            _PackedRow(
              item: item,
              onToggle: () => ref
                  .read(tripNotifierProvider.notifier)
                  .toggleItemCheck(tripId, item.id),
            ),
        ],
      ),
    );
  }
}

/// "Cosa porti" con la valigia fatta di posti: la testata con l'avanzamento,
/// le informazioni sul viaggio, poi per categoria gli importanti aperti, i
/// "da comprare", la card dei proposti e gli oggetti dell'utente.
class _SlotsSection extends StatelessWidget {
  final TripModel trip;
  final _SlotActions actions;

  const _SlotsSection({required this.trip, required this.actions});

  @override
  Widget build(BuildContext context) {
    final progress = SuitcaseProgress.of(trip);
    if (progress.isEmpty) return const _EmptySuitcase();

    final result = trip.aiResult!;
    final open = (result.slots ?? const <AiSlot>[]).where((s) => s.isOpen);
    final gap = SizedBox(height: context.spacingSm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionTitle('trips.pack.items'.tr()),
        SuitcaseProgressHeader(progress: progress),
        for (final note in result.notes) TripNoteRow(note: note),
        for (final category in ItemCategory.values)
          ..._group(
            context,
            category: category,
            slots: open.where((s) => s.category == category).toList(),
            items: trip.items.where((i) => i.category == category).toList(),
            sorting: progress.sorting,
            gap: gap,
          ),
      ],
    );
  }

  List<Widget> _group(
    BuildContext context, {
    required ItemCategory category,
    required List<AiSlot> slots,
    required List<TripItem> items,
    required bool sorting,
    required Widget gap,
  }) {
    if (slots.isEmpty && items.isEmpty) return const [];
    final important = slots.where((s) => s.level == AiSlotLevel.important);
    final toFill = important.where((s) => !s.toBuy);
    final toBuy = important.where((s) => s.toBuy);
    final useful = slots.where((s) => s.level == AiSlotLevel.useful).toList();

    final blocks = <Widget>[
      for (final slot in toFill)
        ImportantSlotCard(
          key: Key('slot_card_${slot.id}'),
          slot: slot,
          onAdd: () => actions.open(slot),
          onToBuy: () => actions.markToBuy(slot),
        ),
      for (final slot in toBuy)
        ToBuySlotRow(
          key: Key('slot_to_buy_row_${slot.id}'),
          slot: slot,
          onGotIt: () => actions.open(slot),
        ),
      if (useful.isNotEmpty)
        ProposedSlotsCard(
          slots: useful,
          sorting: sorting,
          onOpen: actions.open,
          onToggle: actions.toggle,
        ),
      if (items.isNotEmpty) _ItemsCard(tripId: trip.id, items: items),
    ];

    return [
      DsGroupHeader(
        label: category.displayName,
        count: slots.length + items.length,
      ),
      for (var i = 0; i < blocks.length; i++) ...[if (i > 0) gap, blocks[i]],
    ];
  }
}

/// Riga di un oggetto da mettere in valigia: casella, nome e quantità. Una
/// volta dentro il nome si spegne e si barra; tutta la riga spunta.
class _PackedRow extends StatelessWidget {
  final TripItem item;
  final VoidCallback onToggle;

  const _PackedRow({required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final packed = item.isChecked;

    return InkWell(
      key: Key('trip_item_${item.id}'),
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingSm,
          vertical: context.spacingXs,
        ),
        child: Row(
          children: [
            DsCheckbox(value: packed, onChanged: (_) => onToggle()),
            SizedBox(width: context.spacingXs),
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyLarge?.copyWith(
                  color: packed ? context.textTertiary : cs.onSurface,
                  decoration: packed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (item.quantity > 1)
              Padding(
                padding: EdgeInsets.only(right: context.spacingSm),
                child: Text(
                  '×${item.quantity}',
                  style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

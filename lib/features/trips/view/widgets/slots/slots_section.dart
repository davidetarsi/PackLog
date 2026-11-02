import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_group_header.dart';
import '../../../../../shared/widgets/ds_section_title.dart';
import '../../../../items/model/item_model.dart';
import '../../../model/ai_packing.dart';
import '../../../model/suitcase_progress.dart';
import '../../../model/trip_model.dart';
import 'open_slot_body.dart';
import 'slot_actions.dart';
import 'slot_focus.dart';
import 'slot_widgets.dart';
import 'trip_items_card.dart';

/// "Cosa porti" con la valigia fatta di posti: la testata con l'avanzamento,
/// le informazioni sul viaggio, poi per categoria gli importanti aperti, i
/// "da comprare", la card dei proposti e gli oggetti dell'utente.
///
/// Con un posto aperto ([open]) tutto il resto è spento ([SlotFocus]) e gli
/// oggetti scritti stanno nel riquadro, non fra quelli dell'utente.
class SlotsSection extends StatelessWidget {
  final TripModel trip;
  final SlotActions actions;
  final OpenSlotState? open;

  const SlotsSection({
    super.key,
    required this.trip,
    required this.actions,
    this.open,
  });

  @override
  Widget build(BuildContext context) {
    final progress = SuitcaseProgress.of(trip);
    if (progress.isEmpty) return const EmptySuitcase();

    final result = trip.aiResult!;
    // Il posto che sta scoppiando c'è ancora, anche se ormai è finito.
    final slots = (result.slots ?? const <AiSlot>[]).where(
      (s) => s.inSuitcase || s.id == open?.slot.id,
    );
    final writtenIds = {for (final w in open?.written ?? const []) w.id};
    final mine = trip.items.where((i) => !writtenIds.contains(i.id));
    final gap = SizedBox(height: context.spacingSm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dim(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DsSectionTitle('trips.pack.items'.tr()),
              SuitcaseProgressHeader(progress: progress),
              for (final note in result.notes) TripNoteRow(note: note),
            ],
          ),
        ),
        for (final category in ItemCategory.values)
          ..._group(
            context,
            slots: slots.where((s) => s.category == category).toList(),
            items: mine.where((i) => i.category == category).toList(),
            count:
                slots
                    .where((s) => s.category == category && s.inSuitcase)
                    .length +
                trip.items.where((i) => i.category == category).length,
            header: category.displayName,
            sorting: progress.sorting,
            gap: gap,
          ),
      ],
    );
  }

  /// Spento finché c'è un posto aperto e [lit] è falso.
  Widget _dim(Widget child, {bool lit = false}) => SlotFocus(
    active: open != null && !lit,
    onTapOutside: actions.close,
    child: child,
  );

  /// Il contenuto del posto aperto se è [slot], altrimenti `null`.
  Widget? _openBody(AiSlot slot) {
    final state = open;
    if (state == null || state.slot.id != slot.id) return null;
    final ids = {for (final w in state.written) w.id};
    return OpenSlotBody(
      slot: state.slot,
      written: trip.items.where((i) => ids.contains(i.id)).toList(),
      onToggleItem: actions.toggleItem,
      rowKey: actions.rowKey,
    );
  }

  /// La card che contiene il posto aperto prende la sua chiave.
  Widget _block(Widget child, {required bool holdsOpen}) => _dim(
    holdsOpen ? KeyedSubtree(key: open!.cardKey, child: child) : child,
    lit: holdsOpen,
  );

  Widget _important(AiSlot slot) {
    final body = _openBody(slot);
    if (body == null && slot.toBuy) {
      return _block(
        ToBuySlotRow(
          key: Key('slot_to_buy_row_${slot.id}'),
          slot: slot,
          onGotIt: () => actions.open(slot),
          onRemove: () => actions.remove(slot),
        ),
        holdsOpen: false,
      );
    }
    return _block(
      ImportantSlotCard(
        key: Key('slot_card_${slot.id}'),
        slot: slot,
        onAdd: () => actions.open(slot),
        onToBuy: () => actions.markToBuy(slot),
        onRemove: () => actions.remove(slot),
        openBody: body,
        popping: open?.popping ?? false,
        onPopDone: actions.popDone,
      ),
      holdsOpen: body != null,
    );
  }

  List<Widget> _group(
    BuildContext context, {
    required List<AiSlot> slots,
    required List<TripItem> items,
    required int count,
    required String header,
    required bool sorting,
    required Widget gap,
  }) {
    final important = slots.where((s) => s.level == AiSlotLevel.important);
    final useful = slots.where((s) => s.level == AiSlotLevel.useful).toList();
    final openUseful = useful.where((s) => s.id == open?.slot.id).firstOrNull;
    final openBody = openUseful == null ? null : _openBody(openUseful);

    final blocks = <Widget>[
      for (final slot in important.where((s) => !s.toBuy)) _important(slot),
      for (final slot in important.where((s) => s.toBuy)) _important(slot),
      if (useful.isNotEmpty)
        _block(
          ProposedSlotsCard(
            slots: useful,
            sorting: sorting,
            onOpen: actions.open,
            onToggle: actions.toggle,
            onRemove: actions.dismiss,
            openSlotId: openUseful?.id,
            openBody: openBody,
            onTapOutside: actions.close,
            popping: open?.popping ?? false,
            onPopDone: actions.popDone,
          ),
          holdsOpen: openBody != null,
        ),
      if (items.isNotEmpty)
        _dim(
          ItemsCard(
            tripId: trip.id,
            items: items,
            rowKey: actions.rowKey,
            flying: actions.flying,
          ),
        ),
    ];
    if (blocks.isEmpty) return const [];

    return [
      _dim(DsGroupHeader(label: header, count: count)),
      for (var i = 0; i < blocks.length; i++) ...[if (i > 0) gap, blocks[i]],
    ];
  }
}

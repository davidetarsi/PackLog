import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_appear.dart';
import '../../../../../shared/widgets/ds_form_sheet.dart';
import '../../../../../shared/widgets/ds_text_button.dart';
import '../../../../items/model/item_model.dart';
import '../../../../items/widgets/rapid_fire_input.dart';
import '../../../model/ai_packing.dart';
import '../../../model/trip_model.dart';
import 'slot_copies_label.dart';
import 'slot_written_row.dart';

/// Apre il foglio per riempire [slot] con i propri oggetti.
///
/// Ogni oggetto scritto nasce nella casa [houseId] e passa a [onFill], che lo
/// mette in valigia e scala il posto (anche se nel frattempo il foglio è stato
/// chiuso); se fallisce, [onFill] lancia dopo aver avvisato e il foglio non
/// conta l'oggetto. "Da comprare" chiude il foglio e chiama [onToBuy].
Future<void> showSlotFillSheet(
  BuildContext context, {
  required AiSlot slot,
  required String houseId,
  required Future<void> Function(TripItem item) onFill,
  required VoidCallback onToBuy,
}) => showDsSheet<void>(
  context,
  builder: (_) => SlotFillSheet(
    slot: slot,
    houseId: houseId,
    onFill: onFill,
    onToBuy: onToBuy,
  ),
);

/// Il contenuto del foglio: nome e copie che mancano in testata (con "Da
/// comprare" accanto alla X), la frase, gli oggetti scritti in questa
/// apertura e in fondo il Rapid Fire.
///
/// A copie finite il campo si ferma, la riga nuova entra, passa
/// [AppMotion.slotSheetCloseDelay] e il foglio si chiude. Con le animazioni
/// di sistema spente si chiude subito.
class SlotFillSheet extends StatefulWidget {
  const SlotFillSheet({
    super.key,
    required this.slot,
    required this.houseId,
    required this.onFill,
    required this.onToBuy,
  });

  final AiSlot slot;
  final String houseId;
  final Future<void> Function(TripItem item) onFill;
  final VoidCallback onToBuy;

  @override
  State<SlotFillSheet> createState() => _SlotFillSheetState();
}

class _SlotFillSheetState extends State<SlotFillSheet> {
  final _written = <TripItem>[];
  late int _remaining = widget.slot.remaining;
  bool get _done => _remaining == 0;
  Timer? _closeTimer;

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  /// Un oggetto salvato dal Rapid Fire: entra in valigia anche a foglio
  /// chiuso; la riga compare e le copie scendono solo se il salvataggio va.
  Future<void> _onSaved(ItemModel item) async {
    final packed = TripItem(
      id: item.id,
      name: item.name,
      category: item.category,
      quantity: item.quantity ?? 1,
      originHouseId: item.houseId,
    );
    try {
      await widget.onFill(packed);
    } catch (_) {
      // Chi ha chiamato ha già avvisato: la riga non resta e il campo è libero.
      return;
    }
    if (!mounted) return;
    setState(() {
      _written.add(packed);
      _remaining = (_remaining - packed.quantity).clamp(0, _remaining);
    });
    if (_done) _closeSoon();
  }

  /// Aspetta che la riga sia entrata e un attimo ancora, poi chiude. Il timer
  /// si annulla con il foglio, e il pop parte solo se il foglio è ancora la
  /// route in primo piano (chiuso a mano, nessun secondo pop).
  void _closeSoon() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _close();
      return;
    }
    _closeTimer?.cancel();
    _closeTimer = Timer(
      DsAppear.duration + AppMotion.slotSheetCloseDelay,
      _close,
    );
  }

  void _close() {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(context).pop();
  }

  void _toBuy() {
    Navigator.of(context).pop();
    widget.onToBuy();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final copies = slotCopiesLabel(
      slot.copyWith(remaining: _remaining),
      always: true,
    )!;

    return DsFormSheet(
      title: '${slot.name} $copies',
      actions: [
        if (!slot.toBuy)
          DsTextButton(
            key: const Key('slot_sheet_to_buy'),
            label: 'trips.slots.to_buy'.tr(),
            onPressed: _done ? null : _toBuy,
          ),
      ],
      footer: Padding(
        padding: EdgeInsets.fromLTRB(
          context.spacingMd,
          context.spacingXs,
          context.spacingMd,
          context.spacingMd,
        ),
        child: RapidFireInput(
          key: ValueKey('slot_sheet_input_${slot.id}'),
          houseId: widget.houseId,
          autofocus: true,
          hintText: 'trips.slots.rapid_fire_hint'.tr(),
          enabled: !_done,
          onItemSaved: _onSaved,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'trips.slots.open_hint'.tr(args: ['${slot.copies}']),
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          for (final item in _written)
            SlotWrittenRow(key: ValueKey(item.id), item: item),
        ],
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_text_button.dart';
import '../../../model/ai_packing.dart';
import 'slot_card_parts.dart';
import 'slot_copies_label.dart';

// Gli importanti nel dettaglio del viaggio: la card di un importante
// (la riga "da comprare" sta in `to_buy_slot_row.dart`).
//
// Regola dei colori: l'arancione (`primary`) è "da fare", quindi bordo ed
// etichetta degli importanti e l'azione di aggiunta.

/// Il contorno arancione di un importante.
ShapeBorder _importantShape(ColorScheme cs) => RoundedRectangleBorder(
  side: BorderSide(color: cs.primary, width: AppConstants.selectedBorderWidth),
  borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
);

/// Card di un posto importante da riempire: "Importante", nome (×N), motivo in
/// una riga e due azioni testuali, l'aggiunta ([AiSlot.addLabel]) e "Da
/// comprare", più la X per toglierla. Niente bottoni pieni.
class ImportantSlotCard extends StatelessWidget {
  const ImportantSlotCard({
    super.key,
    required this.slot,
    required this.onAdd,
    required this.onToBuy,
    this.onRemove,
  });

  final AiSlot slot;
  final VoidCallback onAdd;
  final VoidCallback onToBuy;

  /// La X in alto a destra; `null` la nasconde.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final copies = slotCopiesLabel(slot);
    final reason = slot.reason;

    return Material(
      color: context.groupSurface,
      shape: _importantShape(cs),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: context.spacingMd,
              bottom: context.spacingXs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  // Con la X il testo lascia il posto al bottone.
                  padding: EdgeInsets.only(
                    left: context.spacingMd,
                    right: onRemove == null
                        ? context.spacingMd
                        : kMinInteractiveDimension,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ImportantLabel(color: cs.primary),
                      SizedBox(height: context.spacingXs),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              slot.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleMedium,
                            ),
                          ),
                          if (copies != null) ...[
                            SizedBox(width: context.spacingXs),
                            Text(
                              copies,
                              style: tt.titleMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (reason != null && reason.isNotEmpty) ...[
                        SizedBox(height: context.spacingXxs),
                        Text(
                          reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Il testo dei bottoni ha già il suo margine: la riga parte poco
                // più a sinistra, così le parole si allineano al nome.
                Padding(
                  padding: EdgeInsets.only(left: context.spacingXs),
                  child: Wrap(
                    children: [
                      DsTextButton(
                        key: Key('slot_add_${slot.id}'),
                        label: slot.addLabel,
                        onPressed: onAdd,
                        accent: true,
                      ),
                      DsTextButton(
                        key: Key('slot_to_buy_${slot.id}'),
                        label: 'trips.slots.to_buy'.tr(),
                        onPressed: onToBuy,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: RemoveSlotButton(slot: slot, onPressed: onRemove!),
            ),
        ],
      ),
    );
  }
}

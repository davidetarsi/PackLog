import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_icon_button.dart';
import '../../../../../shared/widgets/ds_text_button.dart';
import '../../../model/ai_packing.dart';
import 'slot_copies_label.dart';

// Gli importanti nel dettaglio del viaggio: la card di un importante aperto
// e la riga di uno segnato "da comprare".
//
// Colori provvisori: l'accento di "Importante" è `onPrimaryContainer`, lo
// stesso degli avvisi della valigia AI.

/// Etichetta "Importante" con la bandierina, nel colore [color].
class _ImportantLabel extends StatelessWidget {
  const _ImportantLabel({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flag_outlined, size: context.iconSizeXs, color: color),
        SizedBox(width: context.spacingXs),
        Text(
          'trips.slots.important'.tr(),
          style: tt.labelLarge?.strong.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Card di un posto importante aperto: "Importante", nome (×N), motivo in
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
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
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
                      _ImportantLabel(color: cs.onPrimaryContainer),
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
              child: DsIconButton(
                key: Key('slot_remove_${slot.id}'),
                icon: Icons.close,
                tooltip: 'trips.slots.remove_confirm'.tr(),
                onPressed: onRemove,
              ),
            ),
        ],
      ),
    );
  }
}

/// Riga di un importante segnato "da comprare": più spenta della card,
/// "Importante · Da comprare", il nome e "Presa", che apre la barra per
/// riempirlo.
class ToBuySlotRow extends StatelessWidget {
  const ToBuySlotRow({super.key, required this.slot, required this.onGotIt});

  final AiSlot slot;
  final VoidCallback onGotIt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = cs.onSurfaceVariant;
    final copies = slotCopiesLabel(slot);

    return Material(
      color: context.groupSurface,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          left: context.spacingMd,
          right: context.spacingXs,
          top: context.spacingSm,
          bottom: context.spacingSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ImportantLabel(color: muted),
                      Text(' · ', style: tt.labelLarge?.copyWith(color: muted)),
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: context.iconSizeXs,
                        color: muted,
                      ),
                      SizedBox(width: context.spacingXs),
                      Flexible(
                        child: Text(
                          'trips.slots.to_buy'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelLarge?.copyWith(color: muted),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.spacingXxs),
                  Text(
                    copies == null ? slot.name : '${slot.name} $copies',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            DsTextButton(
              key: Key('slot_got_it_${slot.id}'),
              label: 'trips.slots.got_it'.tr(),
              onPressed: onGotIt,
            ),
          ],
        ),
      ),
    );
  }
}

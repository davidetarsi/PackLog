import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_text_button.dart';
import '../../../model/ai_packing.dart';
import 'slot_card_parts.dart';
import 'slot_copies_label.dart';

/// Riga di un importante segnato "da comprare": più spenta della card,
/// "Importante · Da comprare", il nome e "Presa", che apre la barra per
/// riempirlo, più la X per toglierlo.
class ToBuySlotRow extends StatelessWidget {
  const ToBuySlotRow({
    super.key,
    required this.slot,
    required this.onGotIt,
    this.onRemove,
  });

  final AiSlot slot;
  final VoidCallback onGotIt;

  /// La X dopo "Presa"; `null` la nasconde.
  final VoidCallback? onRemove;

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
                  Wrap(
                    spacing: context.spacingXs,
                    runSpacing: context.spacingXs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ImportantLabel(color: muted),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: context.iconSizeXs,
                            color: muted,
                          ),
                          SizedBox(width: context.spacingXs),
                          Flexible(
                            child: Text(
                              'trips.slots.to_buy'.tr(),
                              style: tt.labelLarge?.copyWith(color: muted),
                            ),
                          ),
                        ],
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
            if (onRemove != null)
              RemoveSlotButton(slot: slot, onPressed: onRemove!),
          ],
        ),
      ),
    );
  }
}

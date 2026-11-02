import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_divider.dart';
import '../../../../../shared/widgets/packlog_gradient.dart';
import '../../../model/ai_packing.dart';
import '../../../model/trip_model.dart';
import 'trip_items_card.dart';

/// Il contenuto del posto aperto, lo stesso nella card dei proposti e in
/// quella di un importante: nome e copie che mancano ("Magliette ×3"), la
/// frase con le copie proposte all'inizio e, sotto, gli oggetti scritti in
/// questa apertura ([written]), con la loro casella.
///
/// Lo sfondo e i margini li mette chi lo contiene.
class OpenSlotBody extends StatelessWidget {
  const OpenSlotBody({
    super.key,
    required this.slot,
    required this.written,
    this.onToggleItem,
    this.rowKey,
  });

  final AiSlot slot;
  final List<TripItem> written;

  /// La casella di un oggetto scritto; `null` la lascia ferma.
  final ValueChanged<TripItem>? onToggleItem;

  /// La chiave della riga di un oggetto scritto (per farlo volare via).
  final GlobalKey Function(String itemId)? rowKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final toggle = onToggleItem;

    return Column(
      key: Key('slot_open_${slot.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PackLogSparkle(size: context.iconSizeSm),
            SizedBox(width: context.spacingSm),
            Expanded(
              child: Text(
                slot.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleMedium?.strong,
              ),
            ),
            SizedBox(width: context.spacingSm),
            Text('×${slot.remaining}', style: tt.titleMedium),
          ],
        ),
        SizedBox(height: context.spacingSm),
        Text(
          'trips.slots.open_hint'.tr(args: ['${slot.copies}']),
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (written.isNotEmpty) ...[
          SizedBox(height: context.spacingSm),
          const DsDivider(),
          for (final item in written)
            PackedRow(
              key: rowKey?.call(item.id),
              item: item,
              onToggle: toggle == null ? () {} : () => toggle(item),
            ),
        ],
      ],
    );
  }
}

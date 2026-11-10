import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_appear.dart';
import '../../../model/trip_model.dart';

/// Un oggetto scritto nel foglio del posto: una spunta, il nome e le copie.
/// Compare con l'animazione d'ingresso del design system ([DsAppear]).
class SlotWrittenRow extends StatelessWidget {
  const SlotWrittenRow({super.key, required this.item});

  final TripItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DsAppear(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacingXs),
        child: Row(
          children: [
            Icon(Icons.check, size: context.iconSizeSm, color: cs.primary),
            SizedBox(width: context.spacingSm),
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyLarge,
              ),
            ),
            if (item.quantity > 1)
              Text(
                '×${item.quantity}',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

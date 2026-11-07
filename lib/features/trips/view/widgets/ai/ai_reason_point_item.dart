import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../model/ai_packing.dart';

/// Un punto "dal tuo armadio": titolo, frasi e, in piccolo, i capi collegati.
class AiReasonPointItem extends StatelessWidget {
  const AiReasonPointItem({super.key, required this.point});

  final AiReasonPoint point;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(point.title, style: tt.titleMedium?.title),
          SizedBox(height: context.spacingXs),
          for (final sentence in point.sentences)
            Text(sentence, style: tt.bodyMedium),
          if (point.items.isNotEmpty) ...[
            SizedBox(height: context.spacingXs),
            Text(
              point.items.join(' · '),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

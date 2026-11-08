import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';

/// Riga di un oggetto della casa che si può aggiungere alla valigia: nome,
/// sottotitolo facoltativo e "Aggiungi" a destra. Il tocco su tutta la riga
/// aggiunge.
class AiWardrobeRow extends StatelessWidget {
  final String name;
  final String? subtitle;
  final VoidCallback onAdd;

  const AiWardrobeRow({
    super.key,
    required this.name,
    this.subtitle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onAdd,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingMd,
          vertical: context.spacingSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            SizedBox(width: context.spacingSm),
            Icon(Icons.add, size: context.iconSizeSm, color: cs.onSurface),
            SizedBox(width: context.spacingXs),
            Text(
              'trips.pack.ai.home_add'.tr(),
              style: tt.labelLarge?.copyWith(color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

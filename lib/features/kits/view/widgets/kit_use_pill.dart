import 'package:flutter/material.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_spacing.dart';

/// Pillola neutra con un'attività o un mezzo del kit: solo lettura, bordo
/// sottile e testo secondario. I kit non hanno colore proprio.
class KitUsePill extends StatelessWidget {
  const KitUsePill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacingSm,
        vertical: context.spacingXxs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: AppConstants.hairlineBorderWidth,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

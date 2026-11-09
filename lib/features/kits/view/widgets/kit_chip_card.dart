import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/surface_colors.dart';
import '../../helpers/kit_use_labels.dart';
import '../../model/kit_model.dart';
import 'kit_use_pill.dart';

/// Quante pillole d'uso stanno nella card; le altre diventano "+N".
const int _kVisibleUses = 2;

/// Card di un kit: icona, nome e pillole d'uso.
class KitChipCard extends StatelessWidget {
  const KitChipCard({
    super.key,
    required this.kit,
    required this.onTap,
    required this.moreLabel,
  });

  final KitModel kit;
  final VoidCallback onTap;

  /// Costruisce la pillola "+N" dal numero degli usi non mostrati.
  final String Function(int hidden) moreLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = context.responsiveBorderRadius(
      AppConstants.cardBorderRadius,
    );
    final labels = kitUseLabels(kit);
    final hidden = labels.length - _kVisibleUses;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.sizeOf(context).width *
            AppConstants.kitCardMaxWidthFactor,
      ),
      child: Material(
        color: context.groupSurface,
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: context.cardPaddingDense,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: context.iconSizeLg + context.spacingMd,
                  height: context.iconSizeLg + context.spacingMd,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(
                      AppConstants.badgeBorderRadius,
                    ),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: context.iconSizeLg,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(width: context.spacingSm),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kit.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                      if (labels.isNotEmpty) ...[
                        SizedBox(height: context.spacingXs),
                        Wrap(
                          spacing: context.spacingXs,
                          runSpacing: context.spacingXs,
                          children: [
                            for (final label in labels.take(_kVisibleUses))
                              KitUsePill(label: label),
                            if (hidden > 0)
                              KitUsePill(
                                label: moreLabel(hidden),
                                semanticsLabel: 'kits.more_uses_semantics'.tr(
                                  args: ['$hidden'],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

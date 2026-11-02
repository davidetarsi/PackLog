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

/// Card piccola di un kit nella riga della casa: icona della scatola, nome e
/// numero di oggetti, pillole d'uso. Rettangolare, per non somigliare alle
/// pillole degli spazi.
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
      AppConstants.inputBorderRadius,
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
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: context.cardPaddingDense,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: context.iconSizeSm,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: context.spacingXs),
                    Flexible(
                      child: Text(
                        'kits.name_count'.tr(
                          args: [kit.name, '${kit.items.length}'],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                if (labels.isNotEmpty) ...[
                  SizedBox(height: context.spacingXs),
                  Wrap(
                    spacing: context.spacingXs,
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
        ),
      ),
    );
  }
}

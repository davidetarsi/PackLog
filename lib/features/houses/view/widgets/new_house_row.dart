import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_dashed_box.dart';
import '../../helpers/create_house_flow.dart';

/// Riga tratteggiata "nuova casa".
///
/// In fondo alla lista è un'azione rara, quindi neutra. Nello stato vuoto
/// ([emphasized]) è l'unica azione possibile: bordo e testo arancio, e
/// l'etichetta "Aggiungi la tua prima casa".
class NewHouseRow extends ConsumerWidget {
  final bool emphasized;

  const NewHouseRow({super.key, this.emphasized = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = emphasized
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final label = emphasized
        ? 'houses.no_houses_subtitle'.tr()
        : 'houses.new_house_row'.tr();
    final radius = BorderRadius.circular(AppConstants.cardBorderRadius);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacingMd,
        vertical: context.spacingSm,
      ),
      child: DsDashedBox(
        color: emphasized ? colorScheme.primary : colorScheme.outlineVariant,
        child: InkWell(
          borderRadius: radius,
          onTap: () => createHouseWithTourAdvance(context, ref),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: context.responsive(72)),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: foreground),
                  SizedBox(width: context.spacingSm),
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

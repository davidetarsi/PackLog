import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_dashed_box.dart';
import '../../helpers/create_house_flow.dart';

/// Ultima riga della lista case: azione rara, quindi neutra (niente arancio).
class NewHouseRow extends ConsumerWidget {
  const NewHouseRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppConstants.cardBorderRadius);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacingMd,
        vertical: context.spacingSm,
      ),
      child: DsDashedBox(
        color: colorScheme.outlineVariant,
        child: InkWell(
          borderRadius: radius,
          onTap: () => createHouseWithTourAdvance(context, ref),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: context.responsive(72)),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: colorScheme.onSurfaceVariant),
                  SizedBox(width: context.spacingSm),
                  Text(
                    'houses.new_house_row'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
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

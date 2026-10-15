import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// Superficie tonale condivisa per il contenuto lazy di un gruppo.
class DsGroupSurfaceSliver extends StatelessWidget {
  final Key? surfaceKey;
  final Widget sliver;

  const DsGroupSurfaceSliver({
    super.key,
    this.surfaceKey,
    required this.sliver,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SliverPadding(
      padding: EdgeInsets.only(bottom: context.spacingMd),
      sliver: DecoratedSliver(
        key: surfaceKey,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        ),
        sliver: sliver,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import '../theme/surface_colors.dart';

/// Superficie condivisa per il contenuto lazy di un gruppo: la stessa delle
/// altre card ([SurfaceColors.groupSurface]).
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
    return SliverPadding(
      padding: EdgeInsets.only(bottom: context.spacingMd),
      sliver: DecoratedSliver(
        key: surfaceKey,
        decoration: BoxDecoration(
          color: context.groupSurface,
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        ),
        sliver: sliver,
      ),
    );
  }
}

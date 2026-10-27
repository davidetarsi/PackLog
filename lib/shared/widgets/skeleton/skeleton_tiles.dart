import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../theme/app_spacing.dart';
import 'skeleton_shimmer.dart';

// Misure dei blocchi che imitano le righe di testo: forme, non spaziature.
const double _wideLine = 160;
const double _mediumLine = 140;
const double _shortLine = 100;
const double _tinyLine = 80;
const double _stubLine = 60;
const double _lineHeightSm = 12;
const double _lineHeightMd = 14;
const double _lineHeightLg = 18;
const double _dividerHeight = 1;

/// Placeholder per un item tile (UniversalItemTile, ItemCard, luggage tile, space tile).
/// Layout: [circle] [line1 + line2] [circle]
class SkeletonItemTile extends StatelessWidget {
  const SkeletonItemTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacingMd,
        vertical: context.spacingSm,
      ),
      child: Row(
        children: [
          SkeletonBox(
            width: context.iconSizeMd,
            height: context.iconSizeMd,
            borderRadius: context.iconSizeMd / 2,
          ),
          SizedBox(width: context.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: _wideLine, height: _lineHeightMd),
                SizedBox(height: context.spacingXs),
                SkeletonBox(width: _shortLine, height: _lineHeightSm),
              ],
            ),
          ),
          SizedBox(width: context.spacingMd),
          SkeletonBox(
            width: context.iconSizeMd,
            height: context.iconSizeMd,
            borderRadius: context.iconSizeMd / 2,
          ),
        ],
      ),
    );
  }
}

/// Placeholder per una house card (HouseCard in HousesScreen e HouseSelectionScreen).
/// Layout: card con bordo + [icon box | name + location] + divider + stats row.
class SkeletonHouseCard extends StatelessWidget {
  const SkeletonHouseCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacingMd,
        vertical: context.spacingSm,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: context.responsiveBorderRadius(
            AppConstants.cardBorderRadius + 4,
          ),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        padding: EdgeInsets.all(context.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(
                  width: context.iconSizeMd + context.spacingMd,
                  height: context.iconSizeMd + context.spacingMd,
                  borderRadius: AppConstants.cardBorderRadius,
                ),
                SizedBox(width: context.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: _mediumLine, height: _lineHeightLg),
                      SizedBox(height: context.spacingXs),
                      SkeletonBox(width: _shortLine, height: _lineHeightMd),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacingMd),
            const SkeletonBox(width: double.infinity, height: _dividerHeight),
            SizedBox(height: context.spacingMd),
            Row(
              children: [
                SkeletonBox(width: _tinyLine, height: _lineHeightSm),
                const Spacer(),
                SkeletonBox(width: _stubLine, height: _lineHeightSm),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

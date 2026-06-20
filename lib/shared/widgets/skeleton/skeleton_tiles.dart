import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../theme/app_spacing.dart';
import 'skeleton_shimmer.dart';

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
                SkeletonBox(width: 160, height: 14),
                SizedBox(height: context.spacingXs),
                SkeletonBox(width: 100, height: 12),
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
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius + 4),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        padding: EdgeInsets.all(context.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(
                  width: 40,
                  height: 40,
                  borderRadius: AppConstants.cardBorderRadius,
                ),
                SizedBox(width: context.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 140, height: 16),
                      SizedBox(height: context.spacingXs),
                      SkeletonBox(width: 100, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacingMd),
            const SkeletonBox(width: double.infinity, height: 1),
            SizedBox(height: context.spacingMd),
            Row(
              children: [
                SkeletonBox(width: 80, height: 12),
                const Spacer(),
                SkeletonBox(width: 60, height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder per una trip card.
/// [isHero] = true → card grande stile TripCardHero (prossimo viaggio).
/// [isHero] = false → card compatta stile TripCardCompact (masonry grid).
class SkeletonTripCard extends StatelessWidget {
  final bool isHero;

  const SkeletonTripCard({super.key, this.isHero = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          isHero
              ? AppConstants.cardBorderRadius + 4
              : AppConstants.cardBorderRadius,
        ),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: EdgeInsets.all(context.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titolo viaggio
          SkeletonBox(
            width: isHero ? 200 : 140,
            height: isHero ? 22 : 16,
          ),
          SizedBox(height: context.spacingSm),
          // Badge info (date, destinazione)
          Row(
            children: [
              SkeletonBox(
                width: 80,
                height: 24,
                borderRadius: AppConstants.pillBorderRadius,
              ),
              SizedBox(width: context.spacingSm),
              SkeletonBox(
                width: 100,
                height: 24,
                borderRadius: AppConstants.pillBorderRadius,
              ),
            ],
          ),
          SizedBox(height: context.spacingMd),
          // Progress bar
          SkeletonBox(
            width: double.infinity,
            height: 6,
            borderRadius: AppConstants.pillBorderRadius,
          ),
          if (isHero) ...[
            SizedBox(height: context.spacingSm),
            SkeletonBox(width: 80, height: 12),
          ],
        ],
      ),
    );
  }
}

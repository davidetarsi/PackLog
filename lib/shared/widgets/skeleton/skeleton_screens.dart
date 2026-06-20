import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../theme/app_spacing.dart';
import 'skeleton_shimmer.dart';
import 'skeleton_tiles.dart';

// ── Body-level skeletons (nessun Scaffold — riempiono lo spazio disponibile) ──

/// Skeleton per la lista delle case (HousesScreen e HouseSelectionScreen).
/// Riempie SafeArea o il body disponibile.
class SkeletonHousesBody extends StatelessWidget {
  const SkeletonHousesBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: context.spacingMd),
        itemCount: 3,
        itemBuilder: (_, _) => const SkeletonHouseCard(),
      ),
    );
  }
}

/// Skeleton per la lista degli item (ItemsScreen).
/// Riempie un Expanded — non include Scaffold.
class SkeletonItemsBody extends StatelessWidget {
  const SkeletonItemsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(context.spacingMd),
        itemCount: 8,
        itemBuilder: (_, _) => const SkeletonItemTile(),
      ),
    );
  }
}

/// Skeleton per la lista dei viaggi (TripsScreen).
/// Riempie il tab body, include header e pill tabs placeholder.
class SkeletonTripsBody extends StatelessWidget {
  const SkeletonTripsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingMd,
          vertical: context.spacingSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titolo
            SkeletonBox(width: 180, height: 28),
            SizedBox(height: context.spacingMd),
            // Pill tabs
            Center(
              child: SkeletonBox(
                width: 280,
                height: 36,
                borderRadius: AppConstants.pillBorderRadius,
              ),
            ),
            SizedBox(height: context.spacingLg),
            // Hero card (prossimo viaggio)
            const SkeletonTripCard(isHero: true),
            SizedBox(height: context.spacingSm),
            // Due compact cards
            const SkeletonTripCard(),
            SizedBox(height: context.spacingSm),
            const SkeletonTripCard(),
          ],
        ),
      ),
    );
  }
}

/// Skeleton generico a lista semplice.
/// Usato nei bottom sheet di luggages e spaces (riempie un Expanded).
class SkeletonSimpleList extends StatelessWidget {
  final int itemCount;

  const SkeletonSimpleList({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
        itemCount: itemCount,
        itemBuilder: (_, _) => const SkeletonItemTile(),
      ),
    );
  }
}

// ── Full-Scaffold skeletons (restituiscono un Scaffold completo) ───────────────

/// Skeleton per la schermata di dettaglio casa (HouseDetailScreen).
/// Restituisce un Scaffold completo con AppBar vuota e lista di item placeholder.
class SkeletonHouseDetailScreen extends StatelessWidget {
  const SkeletonHouseDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SkeletonShimmer(
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: context.spacingMd),
          itemCount: 8,
          itemBuilder: (_, _) => const SkeletonItemTile(),
        ),
      ),
    );
  }
}

/// Skeleton per la schermata di dettaglio viaggio (TripDetailScreen).
/// Restituisce un Scaffold completo con AppBar vuota, badge info, pill tabs e lista item.
class SkeletonTripDetailScreen extends StatelessWidget {
  const SkeletonTripDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SkeletonShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge info (date, destinazione, bagagli)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingMd,
                vertical: context.spacingMd,
              ),
              child: Wrap(
                spacing: context.spacingSm,
                runSpacing: context.spacingSm,
                children: const [
                  SkeletonBox(
                    width: 90,
                    height: 28,
                    borderRadius: AppConstants.pillBorderRadius,
                  ),
                  SkeletonBox(
                    width: 110,
                    height: 28,
                    borderRadius: AppConstants.pillBorderRadius,
                  ),
                  SkeletonBox(
                    width: 80,
                    height: 28,
                    borderRadius: AppConstants.pillBorderRadius,
                  ),
                ],
              ),
            ),
            // Pill tabs
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
              child: SkeletonBox(
                width: double.infinity,
                height: 40,
                borderRadius: AppConstants.pillBorderRadius,
              ),
            ),
            SizedBox(height: context.spacingMd),
            // Lista item
            Expanded(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                itemBuilder: (_, _) => const SkeletonItemTile(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

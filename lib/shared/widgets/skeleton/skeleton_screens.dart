import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../theme/app_spacing.dart';
import '../../theme/nav_bar_spacing.dart';
import 'skeleton_shimmer.dart';
import 'skeleton_tiles.dart';

// Quante righe o card finte mostrare, e le misure della sagoma della tab Viaggi.
const int _houseCount = 5;
const int _itemCount = 8;
const int _tripItemCount = 6;
const int _simpleListCount = 5;
const double _badgeWide = 110;
const double _badgeMedium = 90;
const double _badgeNarrow = 80;
const double _pillTabsHeight = 40;

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
        itemCount: _houseCount,
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
        itemCount: _itemCount,
        itemBuilder: (_, _) => const SkeletonItemTile(),
      ),
    );
  }
}

/// Skeleton della tab Viaggi (TripsScreen): solo la sagoma della cartolina in
/// cima, che riempie l'altezza disponibile. I filtri sono reali e sempre
/// visibili sopra, quindi non si ripetono qui.
class SkeletonTripsBody extends StatelessWidget {
  const SkeletonTripsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: EdgeInsets.only(
          left: context.spacingMd,
          right: context.spacingMd,
          bottom: context.navBarReservedHeight + context.spacingLg,
        ),
        child: const SkeletonBox(
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}

/// Skeleton generico a lista semplice.
/// Usato nei bottom sheet di luggages e spaces (riempie un Expanded).
class SkeletonSimpleList extends StatelessWidget {
  final int itemCount;

  const SkeletonSimpleList({super.key, this.itemCount = _simpleListCount});

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
          itemCount: _itemCount,
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
                    width: _badgeMedium,
                    height: AppConstants.pillTabCompact,
                    borderRadius: AppConstants.pillBorderRadius,
                  ),
                  SkeletonBox(
                    width: _badgeWide,
                    height: AppConstants.pillTabCompact,
                    borderRadius: AppConstants.pillBorderRadius,
                  ),
                  SkeletonBox(
                    width: _badgeNarrow,
                    height: AppConstants.pillTabCompact,
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
                height: _pillTabsHeight,
                borderRadius: AppConstants.pillBorderRadius,
              ),
            ),
            SizedBox(height: context.spacingMd),
            // Lista item
            Expanded(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tripItemCount,
                itemBuilder: (_, _) => const SkeletonItemTile(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

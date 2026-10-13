import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/core_analytics_service.dart';
import '../../features/houses/helpers/create_house_flow.dart';
import '../../features/tour/tour_keys.dart';
import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import 'create_sheet.dart';

/// Effetto vetro della barra (sfocatura dello sfondo). Se sul telefono la
/// sfocatura fa scattare lo scorrimento, metti `false`: la barra torna a una
/// superficie tonale piena.
const bool _kGlassNavBar = true;

/// Shell principale: barra flottante Case · Crea · Viaggi.
///
/// "Crea" è sempre lo stesso in ogni tab e apre il foglio Crea, dove la
/// scansione AI è la scelta principale. La tab corrente decide solo l'ordine
/// delle voci sotto (vedi [showCreateSheet]).
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  static const _housesBranch = 0;
  static const _tripsBranch = 1;

  void _goBranch(int index) =>
      navigationShell.goBranch(index, initialLocation: false);

  Future<void> _onCreate(
    BuildContext context,
    WidgetRef ref, {
    required bool fromTrips,
  }) async {
    final analytics = ref.read(coreAnalyticsServiceProvider);
    final tab = fromTrips ? 'trips' : 'houses';
    analytics.trackCreateTapped(tab: tab);

    final choice = await showCreateSheet(context, fromTrips: fromTrips);
    if (choice == null || !context.mounted) return;

    switch (choice.action) {
      case CreateAction.aiScan:
        analytics.trackCreateSheetChoice(choice: 'ai_scan', tab: tab);
        context.push('/houses/${choice.houseId}/ai-import');
      case CreateAction.manualItems:
        analytics.trackCreateSheetChoice(choice: 'manual_items', tab: tab);
        // L'inserimento a mano passa dal rapid fire della casa, già attivo.
        context.push('/houses/${choice.houseId}?add=manual');
      case CreateAction.newHouse:
        analytics.trackCreateSheetChoice(choice: 'new_house', tab: tab);
        await createHouseWithTourAdvance(context, ref);
      case CreateAction.newTrip:
        analytics.trackCreateSheetChoice(choice: 'new_trip', tab: tab);
        context.push('/new-trip');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final onHouses = navigationShell.currentIndex == _housesBranch;

    final barHeight = context.responsive(56.0);
    final radius = context.responsiveBorderRadius(
      AppConstants.pillBorderRadius,
    );

    Widget bar = Container(
      height: barHeight,
      decoration: BoxDecoration(
        color: _kGlassNavBar
            ? colorScheme.surfaceContainer.withValues(alpha: 0.78)
            : colorScheme.surfaceContainer,
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _NavItem(
              key: const Key('nav_houses'),
              anchorKey: tourKeys.housesTab,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'navigation.houses'.tr(),
              isSelected: onHouses,
              onTap: () => _goBranch(_housesBranch),
            ),
          ),
          Expanded(
            child: _NavItem(
              key: const Key('nav_create'),
              anchorKey: tourKeys.primaryAction,
              icon: Icons.add_circle_outline,
              selectedIcon: Icons.add_circle_outline,
              label: 'common.create'.tr(),
              accent: true,
              onTap: () => _onCreate(context, ref, fromTrips: !onHouses),
            ),
          ),
          Expanded(
            child: _NavItem(
              key: const Key('nav_trips'),
              anchorKey: tourKeys.tripsTab,
              icon: Icons.luggage_outlined,
              selectedIcon: Icons.luggage,
              label: 'navigation.trips'.tr(),
              isSelected: !onHouses,
              onTap: () => _goBranch(_tripsBranch),
            ),
          ),
        ],
      ),
    );
    if (_kGlassNavBar) {
      bar = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: bar,
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Anchor invisibile per gli step info-card del tour (nessun spotlight)
          Center(
            child: SizedBox(key: tourKeys.infoCardTarget, width: 1, height: 1),
          ),
          navigationShell,
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.spacingMd,
            0,
            context.spacingMd,
            context.spacingMd,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: bar,
          ),
        ),
      ),
    );
  }
}

/// Voce della barra. La usano i luoghi (Case, Viaggi) e Crea.
///
/// I luoghi sono neutri anche da attivi: la tab corrente si riconosce
/// dall'icona piena e dalla lineetta arancio sul bordo superiore. [accent]
/// colora la voce di arancio: è riservato a Crea, l'unico arancio della
/// barra, che non è un luogo e quindi non è mai "selezionato".
class _NavItem extends StatelessWidget {
  final GlobalKey anchorKey;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final bool accent;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.anchorKey,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = accent ? colorScheme.primary : colorScheme.onSurface;

    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        key: anchorKey,
        onTap: onTap,
        borderRadius: context.responsiveBorderRadius(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: context.responsive(22),
                  color: color,
                ),
                SizedBox(height: context.spacingXs / 4),
                // L'altezza della barra è fissa: con caratteri molto grandi la
                // scritta non deve spingere l'icona fuori.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 0,
                child: Container(
                  key: const Key('nav_indicator'),
                  width: context.spacingLg,
                  height: context.spacingXs,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(context.spacingXs),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

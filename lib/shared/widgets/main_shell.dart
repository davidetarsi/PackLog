import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/core_analytics_service.dart';
import '../../features/houses/providers/house_provider.dart';
import '../../features/items/view/add_edit_item_screen.dart';
import '../../features/items/view/add_items_sheet.dart';
import '../../features/tour/tour_keys.dart';
import '../constants/app_constants.dart';
import '../helpers/snack_bar_helper.dart';
import '../theme/app_spacing.dart';
import 'primary_action_button.dart';

/// Effetto vetro della barra (sfocatura dello sfondo). Se sul telefono la
/// sfocatura fa scattare lo scorrimento, metti `false`: la barra torna a una
/// superficie tonale piena.
const bool _kGlassNavBar = true;

/// Shell principale: barra flottante con due luoghi (Case, Viaggi) e, staccato,
/// il bottone d'azione della tab corrente.
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  static const _housesBranch = 0;
  static const _tripsBranch = 1;

  void _goBranch(int index) =>
      navigationShell.goBranch(index, initialLocation: false);

  Future<void> _onAddItems(
    BuildContext context,
    WidgetRef ref, {
    required bool hasHouses,
  }) async {
    final analytics = ref.read(coreAnalyticsServiceProvider);
    analytics.trackPrimaryActionTapped(
      tab: 'houses',
      action: 'add_items',
      enabled: hasHouses,
    );
    if (!hasHouses) {
      AppSnackBar.showWarning(context, 'navigation.create_house_first'.tr());
      return;
    }
    final choice = await showAddItemsSheet(context);
    if (choice == null || !context.mounted) return;
    switch (choice.method) {
      case AddItemsMethod.aiScan:
        analytics.trackAddItemsSheetChoice(choice: 'ai_scan');
        context.push('/houses/${choice.houseId}/ai-import');
      case AddItemsMethod.manual:
        analytics.trackAddItemsSheetChoice(choice: 'manual');
        await showAddEditItemSheet(context, houseId: choice.houseId);
    }
  }

  void _onNewTrip(BuildContext context, WidgetRef ref) {
    ref
        .read(coreAnalyticsServiceProvider)
        .trackPrimaryActionTapped(
          tab: 'trips',
          action: 'new_trip',
          enabled: true,
        );
    context.push('/new-trip');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentIndex = navigationShell.currentIndex;
    final houses = ref.watch(houseNotifierProvider).valueOrNull;
    // Durante il caricamento il bottone resta acceso: spegnerlo per un frame
    // farebbe lampeggiare il colore a ogni avvio.
    final hasHouses = houses == null || houses.isNotEmpty;
    final onHouses = currentIndex == _housesBranch;

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
          child: Row(
            children: [
              Expanded(
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
              SizedBox(width: context.spacingSm),
              KeyedSubtree(
                key: tourKeys.primaryAction,
                child: PrimaryActionButton(
                  key: const Key('primary_action_button'),
                  icon: onHouses ? Icons.add : Icons.luggage,
                  label: onHouses
                      ? 'navigation.add_items'.tr()
                      : 'navigation.new_trip'.tr(),
                  enabled: !onHouses || hasHouses,
                  onPressed: onHouses
                      ? () => _onAddItems(context, ref, hasHouses: hasHouses)
                      : () => _onNewTrip(context, ref),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final GlobalKey anchorKey;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.anchorKey,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return InkWell(
      key: anchorKey,
      onTap: onTap,
      borderRadius: context.responsiveBorderRadius(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? selectedIcon : icon,
            size: context.responsive(22),
            color: color,
          ),
          SizedBox(height: context.spacingXs / 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

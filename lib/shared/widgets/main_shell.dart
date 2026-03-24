import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../features/houses/view/settings_screen.dart';
import '../../features/houses/view/add_edit_house_screen.dart';
import '../../features/items/view/add_edit_item_screen.dart';
import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// Shell principale dell'app con tab bar persistente
class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  bool _isCreateMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    // Se clicchiamo su altro mentre il menu è aperto, chiudilo
    if (_isCreateMenuOpen && index != 3) {
      _closeCreateMenu();
    }

    switch (index) {
      case 0:
        _showSettings();
        break;
      case 1:
        widget.navigationShell.goBranch(0, initialLocation: false);
        break;
      case 2:
        widget.navigationShell.goBranch(1, initialLocation: false);
        break;
      case 3:
        _toggleCreateMenu();
        break;
    }
  }

  /// Mostra la schermata delle impostazioni come bottom sheet.
  ///
  /// [FractionallySizedBox] con [heightFactor] fisso sostituisce il
  /// precedente [DraggableScrollableSheet]: elimina il wrapper ridondante,
  /// sblocca la gesture nativa di swipe-to-close e riduce l'overhead di
  /// rendering senza perdere funzionalità.
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: const SettingsScreen(),
      ),
    );
  }

  void _toggleCreateMenu() {
    setState(() {
      _isCreateMenuOpen = !_isCreateMenuOpen;
    });
    if (_isCreateMenuOpen) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _closeCreateMenu() {
    if (_isCreateMenuOpen) {
      setState(() {
        _isCreateMenuOpen = false;
      });
      _animationController.reverse();
    }
  }

  void _onCreateTrip() {
    _closeCreateMenu();
    context.push('/new-trip');
  }

  void _onCreateItem() {
    _closeCreateMenu();
    showAddEditItemSheet(context);
  }

  void _onCreateHouse() {
    _closeCreateMenu();
    showAddEditHouseSheet(context);
  }

  void _onCreateBulk() {
    _closeCreateMenu();
    context.push('/bulk-creation/select-house');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentIndex = widget.navigationShell.currentIndex;
    final selectedTabIndex = currentIndex + 1;

    // Altezza tab bar + padding bottom - responsive
    // 1. Recuperiamo lo spazio occupato dall'hardware di sistema (es. gesture bar)
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
    final tabBarHeight = context.responsive(56.0);
    final tabBarBottomPadding = context.spacingMd;
    final tabBarTotalHeight =
        tabBarHeight + bottomSafeArea + tabBarBottomPadding + context.spacingMd;

    return PopScope<Object?>(
      // Il pop di sistema è consentito solo quando il menu è chiuso.
      // Quando il menu è aperto, intercettiamo il tasto "Indietro" per
      // chiudere il menu invece di uscire dalla schermata corrente.
      canPop: !_isCreateMenuOpen,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        // Se didPop è true il framework ha già gestito il pop (canPop era
        // true), non c'è nulla da fare.
        if (didPop) return;

        // canPop era false → il menu era aperto. Lo chiudiamo con la sua
        // animazione di uscita senza toccare la navigazione dello stack.
        _closeCreateMenu();
      },
      child: Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Contenuto principale
          widget.navigationShell,

          // Overlay scuro quando il menu è aperto
          if (_isCreateMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeCreateMenu,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(color: Colors.black.withValues(alpha: 0.5)),
                ),
              ),
            ),

          // Menu pill tabs sopra la tab bar
          if (_isCreateMenuOpen)
            Positioned(
              right: context.spacingMd,
              bottom: tabBarTotalHeight + context.spacingSm,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width / 2,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _CreatePillTab(
                          icon: Icons.luggage,
                          label: 'trips.add'.tr(),
                          colorScheme: colorScheme,
                          onTap: _onCreateTrip,
                        ),
                        SizedBox(height: context.spacingSm),
                        _CreatePillTab(
                          icon: Icons.inventory_2,
                          label: 'items.add'.tr(),
                          colorScheme: colorScheme,
                          onTap: _onCreateItem,
                        ),
                        SizedBox(height: context.spacingSm),
                        _CreatePillTab(
                          icon: Icons.grid_view,
                          label: 'bulk_creation.add_from_template'.tr(),
                          colorScheme: colorScheme,
                          onTap: _onCreateBulk,
                        ),
                        SizedBox(height: context.spacingSm),
                        _CreatePillTab(
                          icon: Icons.home,
                          label: 'houses.add'.tr(),
                          colorScheme: colorScheme,
                          onTap: _onCreateHouse,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        bottom: true, 
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.spacingMd,
            0,
            context.spacingMd,
            tabBarBottomPadding,
          ),
          child: Container(
            height: tabBarHeight,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: context.responsiveBorderRadius(
                AppConstants.pillBorderRadius,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.person_3_outlined,
                    selectedIcon: Icons.person_3,
                    label: 'common.profile'.tr(),
                    isSelected: false,
                    onTap: () => _onTabTapped(0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: 'navigation.houses'.tr(),
                    isSelected: selectedTabIndex == 1,
                    onTap: () => _onTabTapped(1),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.luggage_outlined,
                    selectedIcon: Icons.luggage,
                    label: 'navigation.trips'.tr(),
                    isSelected: selectedTabIndex == 2,
                    onTap: () => _onTabTapped(2),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: _isCreateMenuOpen
                        ? Icons.close
                        : Icons.add_circle_outline,
                    selectedIcon: Icons.add_circle,
                    label: _isCreateMenuOpen
                        ? 'common.close'.tr()
                        : 'common.create'.tr(),
                    isSelected: _isCreateMenuOpen,
                    onTap: () => _onTabTapped(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ), // Scaffold
  ); // PopScope
  } // build
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: context.responsiveBorderRadius(16),
      // Occupa tutta l'altezza disponibile nella Row della tab bar in modo
      // che il Column possa centrarsi verticalmente senza overflow.
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.responsive(10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: context.responsive(22),
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: context.spacingXs / 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  // fontSize leggermente ridotta per garantire che testo +
                  // icona stiano sempre dentro tabBarHeight su ogni densità.
                  fontSize: context.responsive(10),
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatePillTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _CreatePillTab({
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: context.responsiveBorderRadius(
        AppConstants.pillBorderRadius,
      ),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.responsiveBorderRadius(
          AppConstants.pillBorderRadius,
        ),
        child: Padding(
          padding: context.responsiveSymmetricPadding(
            horizontal: 20,
            vertical: 12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: context.responsive(22), color: colorScheme.onPrimaryContainer),
              SizedBox(width: context.spacingSm + 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: context.responsiveFont(15),
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

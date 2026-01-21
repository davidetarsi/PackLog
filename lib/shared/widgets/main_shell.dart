import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/houses/view/settings_screen.dart';
import '../../features/houses/view/add_edit_house_screen.dart';
import '../../features/items/view/add_edit_item_screen.dart';
import '../constants/app_constants.dart';

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

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => const SettingsScreen(),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentIndex = widget.navigationShell.currentIndex;
    final selectedTabIndex = currentIndex + 1;

    // Altezza tab bar + padding bottom
    const tabBarHeight = 56.0;
    const tabBarBottomPadding = 30.0;
    const tabBarTotalHeight = tabBarHeight + tabBarBottomPadding + 16;

    return Scaffold(
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
                  child: Container(color: Colors.black.withOpacity(0.5)),
                ),
              ),
            ),

          // Menu pill tabs sopra la tab bar
          if (_isCreateMenuOpen)
            Positioned(
              right: 16,
              bottom: tabBarTotalHeight + 8,
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
                          label: 'Viaggio',
                          color: colorScheme.primaryContainer,
                          iconColor: colorScheme.onPrimaryContainer,
                          onTap: _onCreateTrip,
                        ),
                        const SizedBox(height: 8),
                        _CreatePillTab(
                          icon: Icons.inventory_2,
                          label: 'Oggetto',
                          color: colorScheme.secondaryContainer,
                          iconColor: colorScheme.onSecondaryContainer,
                          onTap: _onCreateItem,
                        ),
                        const SizedBox(height: 8),
                        _CreatePillTab(
                          icon: Icons.home,
                          label: 'Casa',
                          color: colorScheme.tertiaryContainer,
                          iconColor: colorScheme.onTertiaryContainer,
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
      extendBody: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, tabBarBottomPadding),
        child: Container(
          height: tabBarHeight,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: 'Impostazioni',
                isSelected: false,
                onTap: () => _onTabTapped(0),
              ),
              _NavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Case',
                isSelected: selectedTabIndex == 1,
                onTap: () => _onTabTapped(1),
              ),
              _NavItem(
                icon: Icons.luggage_outlined,
                selectedIcon: Icons.luggage,
                label: 'Viaggi',
                isSelected: selectedTabIndex == 2,
                onTap: () => _onTabTapped(2),
              ),
              _NavItem(
                icon: _isCreateMenuOpen
                    ? Icons.close
                    : Icons.add_circle_outline,
                selectedIcon: Icons.add_circle,
                label: _isCreateMenuOpen ? 'Chiudi' : 'Crea',
                isSelected: _isCreateMenuOpen,
                onTap: () => _onTabTapped(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isSelected
            ? BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: 22,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePillTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _CreatePillTab({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

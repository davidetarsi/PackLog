import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/houses/view/settings_screen.dart';

/// Shell principale dell'app con tab bar persistente
class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  void _onTabTapped(int index) {
    // 4 tab: Impostazioni, Case, Viaggi, Crea
    switch (index) {
      case 0:
        _showSettings();
        break;
      case 1:
        // Tab Case - branch index 0
        widget.navigationShell.goBranch(0, initialLocation: index == widget.navigationShell.currentIndex);
        break;
      case 2:
        // Tab Viaggi - branch index 1
        widget.navigationShell.goBranch(1, initialLocation: index == widget.navigationShell.currentIndex);
        break;
      case 3:
        _showCreate();
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

  void _showCreate() {
    // Determina cosa creare in base alla pagina corrente
    final currentIndex = widget.navigationShell.currentIndex;
    if (currentIndex == 0) {
      // Siamo nella sezione Case
      context.push('/houses/new');
    } else {
      // Siamo nella sezione Viaggi
      context.push('/trips/new');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentIndex = widget.navigationShell.currentIndex;

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex + 1, // +1 perché Impostazioni è index 0
        onDestinationSelected: _onTabTapped,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Impostazioni',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
              color: currentIndex == 0 ? colorScheme.primary : null,
            ),
            selectedIcon: Icon(Icons.home, color: colorScheme.primary),
            label: 'Case',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.luggage_outlined,
              color: currentIndex == 1 ? colorScheme.primary : null,
            ),
            selectedIcon: Icon(Icons.luggage, color: colorScheme.primary),
            label: 'Viaggi',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Crea',
          ),
        ],
      ),
    );
  }
}


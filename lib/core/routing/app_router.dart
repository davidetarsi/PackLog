import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/houses/view/houses_screen.dart';
import '../../features/houses/view/house_detail_screen.dart';
import '../../features/items/view/add_edit_item_screen.dart';
import '../../features/trips/view/trips_page.dart';
import '../../features/trips/view/trip_detail_screen.dart';
import '../../features/trips/view/add_trip_screen.dart';
import '../../features/trips/view/edit_trip_info_screen.dart';
import '../../features/trips/view/edit_trip_items_screen.dart';
import '../../shared/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _housesNavigatorKey = GlobalKey<NavigatorState>();
final _tripsNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Shell con tab bar persistente per Case e Viaggi
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        // Branch 0: Case
        StatefulShellBranch(
          navigatorKey: _housesNavigatorKey,
          routes: [
            GoRoute(
              path: '/',
              name: 'houses',
              builder: (context, state) => const HousesScreen(),
            ),
          ],
        ),
        // Branch 1: Viaggi
        StatefulShellBranch(
          navigatorKey: _tripsNavigatorKey,
          routes: [
            GoRoute(
              path: '/trips',
              name: 'trips',
              builder: (context, state) => const TripsPage(),
            ),
          ],
        ),
      ],
    ),
    // Route fuori dalla shell (senza tab bar)
    GoRoute(
      path: '/houses/:id',
      name: 'house-detail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null || id.isEmpty) {
          return const _ErrorScreen(message: 'ID casa non valido');
        }
        return HouseDetailScreen(houseId: id);
      },
    ),
    GoRoute(
      path: '/trips/:id',
      name: 'trip-detail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null || id.isEmpty) {
          return const _ErrorScreen(message: 'ID viaggio non valido');
        }
        return TripDetailScreen(tripId: id);
      },
    ),
    GoRoute(
      path: '/new-trip',
      name: 'trip-new',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AddTripScreen(),
    ),
    GoRoute(
      path: '/trips/:id/edit',
      name: 'trip-edit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null || id.isEmpty) {
          return const _ErrorScreen(message: 'ID lista non valido');
        }
        return AddTripScreen(tripId: id);
      },
    ),
    GoRoute(
      path: '/trips/:id/edit-info',
      name: 'trip-edit-info',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null || id.isEmpty) {
          return const _ErrorScreen(message: 'ID viaggio non valido');
        }
        return EditTripInfoScreen(tripId: id);
      },
    ),
    GoRoute(
      path: '/trips/:id/edit-items',
      name: 'trip-edit-items',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null || id.isEmpty) {
          return const _ErrorScreen(message: 'ID viaggio non valido');
        }
        return EditTripItemsScreen(tripId: id);
      },
    ),
    // Route per creare item senza casa preselezionata (fuori dalla shell)
    GoRoute(
      path: '/items/new',
      name: 'item-new-global',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AddEditItemScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Errore')),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Errore di navigazione: ${state.error}',
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Torna alla home'),
          ),
        ],
      ),
    ),
  ),
);

class _ErrorScreen extends StatelessWidget {
  final String message;

  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Errore')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Torna alla home'),
            ),
          ],
        ),
      ),
    );
  }
}

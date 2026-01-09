import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/houses/view/houses_screen.dart';
import '../../features/houses/view/house_detail_screen.dart';
import '../../features/houses/view/add_edit_house_screen.dart';
import '../../features/items/view/add_edit_item_screen.dart';
import '../../features/trips/view/trips_page.dart';
import '../../features/trips/view/trip_detail_screen.dart';
import '../../features/trips/view/add_edit_trip_screen.dart';
import '../../shared/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

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
    // Route fuori dalla shell (si aprono sopra)
    GoRoute(
      path: '/trips/new',
      name: 'trip-new',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AddEditTripScreen(),
    ),
    GoRoute(
      path: '/trips/:id',
      name: 'trip-detail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null || id.isEmpty || id == 'new') {
          return const AddEditTripScreen();
        }
        return TripDetailScreen(tripId: id);
      },
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
        return AddEditTripScreen(tripId: id);
      },
    ),
    // IMPORTANTE: Le route specifiche devono venire PRIMA delle route con parametri
    GoRoute(
      path: '/houses/new',
      name: 'house-new',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AddEditHouseScreen(),
    ),
    GoRoute(
      path: '/houses/:id',
      name: 'house-detail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null || id.isEmpty || id == 'new') {
          // Se id è "new", reindirizza alla route corretta
          return const AddEditHouseScreen();
        }
        return HouseDetailScreen(houseId: id);
      },
    ),
    GoRoute(
      path: '/houses/:id/edit',
      name: 'house-edit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null || id.isEmpty) {
          return const _ErrorScreen(message: 'ID casa non valido');
        }
        return AddEditHouseScreen(houseId: id);
      },
    ),
    // Route per creare item senza casa preselezionata
    GoRoute(
      path: '/items/new',
      name: 'item-new-global',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AddEditItemScreen(),
    ),
    GoRoute(
      path: '/houses/:houseId/items/new',
      name: 'item-new',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final houseId = state.pathParameters['houseId'];
        if (houseId == null || houseId.isEmpty) {
          return const _ErrorScreen(message: 'ID casa non valido');
        }
        return AddEditItemScreen(houseId: houseId);
      },
    ),
    GoRoute(
      path: '/houses/:houseId/items/:id/edit',
      name: 'item-edit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final houseId = state.pathParameters['houseId'];
        final itemId = state.pathParameters['id'];
        if (houseId == null || houseId.isEmpty) {
          return const _ErrorScreen(message: 'ID casa non valido');
        }
        if (itemId == null || itemId.isEmpty) {
          return const _ErrorScreen(message: 'ID oggetto non valido');
        }
        return AddEditItemScreen(houseId: houseId, itemId: itemId);
      },
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

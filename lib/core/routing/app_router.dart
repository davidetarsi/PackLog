import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/houses/view/houses_screen.dart';
import '../../features/houses/view/house_detail_screen.dart';
import '../../features/profile/view/profile_screen.dart';
import '../../features/trips/view/trips_page.dart';
import '../../features/trips/view/trip_detail_screen.dart';
import '../../features/trips/view/add_trip_screen.dart';
import '../../features/trips/view/edit_trip_info_screen.dart';
import '../../features/trips/view/edit_trip_items_screen.dart';
import '../../features/trips/model/trip_model.dart';
import '../../features/trips/view/smart_packing_loading_screen.dart';
import '../../features/trips/view/smart_packing_results_screen.dart';
import '../../features/bulk_creation/view/house_selection_screen.dart';
import '../../features/bulk_creation/view/template_selection_screen.dart';
import '../../features/bulk_creation/view/bulk_item_list_screen.dart';
import '../../features/poc_ai/view/ai_clothing_sandbox_screen.dart';
import '../../shared/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _profileNavigatorKey = GlobalKey<NavigatorState>();
final _housesNavigatorKey = GlobalKey<NavigatorState>();
final _tripsNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Shell con tab bar persistente (Profilo / Case / Viaggi)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        // Branch 0: Profilo
        StatefulShellBranch(
          navigatorKey: _profileNavigatorKey,
          routes: [
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
        // Branch 1: Case
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
        // Branch 2: Viaggi
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
          return _ErrorScreen(message: 'errors.invalid_house_id'.tr());
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
          return _ErrorScreen(message: 'errors.invalid_trip_id'.tr());
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
          return _ErrorScreen(message: 'errors.invalid_list_id'.tr());
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
          return _ErrorScreen(message: 'errors.invalid_trip_id'.tr());
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
          return _ErrorScreen(message: 'errors.invalid_trip_id'.tr());
        }
        return EditTripItemsScreen(tripId: id);
      },
    ),
    // Loading screen — new trip (data from form, not yet in DB)
    GoRoute(
      path: '/trips/new/smart-packing',
      name: 'smart-packing-loading-new',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final pendingTrip = state.extra as TripModel?;
        if (pendingTrip == null) {
          return _ErrorScreen(message: 'errors.invalid_trip_id'.tr());
        }
        return SmartPackingLoadingScreen(
          tripId: 'new',
          pendingTrip: pendingTrip,
        );
      },
    ),
    // Results screen — new trip
    GoRoute(
      path: '/trips/new/smart-packing/results',
      name: 'smart-packing-results-new',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final payload = state.extra as SmartPackingResultsPayload?;
        if (payload == null) {
          return _ErrorScreen(message: 'errors.invalid_trip_id'.tr());
        }
        return SmartPackingResultsScreen(
          tripId: 'new',
          recommendations: payload.recommendations,
          pendingTrip: payload.pendingTrip,
        );
      },
    ),
    // Loading screen — existing trip (reads from DB)
    GoRoute(
      path: '/trips/:id/smart-packing',
      name: 'smart-packing-loading',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null || id.isEmpty) {
          return _ErrorScreen(message: 'errors.invalid_trip_id'.tr());
        }
        return SmartPackingLoadingScreen(tripId: id);
      },
    ),
    // Results screen — existing trip
    GoRoute(
      path: '/trips/:id/smart-packing/results',
      name: 'smart-packing-results',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null || id.isEmpty) {
          return _ErrorScreen(message: 'errors.invalid_trip_id'.tr());
        }
        final payload = state.extra as SmartPackingResultsPayload?;
        return SmartPackingResultsScreen(
          tripId: id,
          recommendations: payload?.recommendations ?? [],
          pendingTrip: payload?.pendingTrip,
        );
      },
    ),
    // Route sandbox PoC AI (developer-only, non esposta nella tab bar)
    GoRoute(
      path: '/ai-sandbox',
      name: 'ai-sandbox',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AiClothingSandboxScreen(),
    ),

    // Route per la creazione massiva di item da template
    GoRoute(
      path: '/bulk-creation/select-house',
      name: 'bulk-house-selection',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const HouseSelectionScreen(),
    ),
    GoRoute(
      path: '/bulk-creation/templates/:houseId',
      name: 'bulk-template-selection',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final houseId = state.pathParameters['houseId'];
        if (houseId == null || houseId.isEmpty) {
          return _ErrorScreen(message: 'errors.invalid_house_id'.tr());
        }
        return TemplateSelectionScreen(houseId: houseId);
      },
    ),
    GoRoute(
      path: '/bulk-creation/items/:houseId',
      name: 'bulk-item-list',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final houseId = state.pathParameters['houseId'];
        if (houseId == null || houseId.isEmpty) {
          return _ErrorScreen(message: 'errors.invalid_house_id'.tr());
        }
        return BulkItemListScreen(houseId: houseId);
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: Text('common.error'.tr())),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'common.navigation_error'.tr(args: [state.error.toString()]),
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: Text('common.back_to_home'.tr()),
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
      appBar: AppBar(title: Text('common.error'.tr())),
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
              child: Text('common.back_to_home'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

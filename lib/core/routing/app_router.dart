import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../shared/theme/app_spacing.dart';

import '../../bootstrap.dart';
import '../../features/onboarding/providers/onboarding_status_provider.dart';
import '../../features/onboarding/view/onboarding_screen.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_state.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/houses/view/houses_screen.dart';
import '../../features/houses/view/house_detail_screen.dart';
import '../../features/profile/view/profile_screen.dart';
import '../../features/trips/view/trips_screen.dart';
import '../../features/trips/view/trip_detail_screen.dart';
import '../../features/trips/view/add_trip_screen.dart';
import '../../features/trips/view/edit_trip_info_screen.dart';
import '../../features/trips/view/edit_trip_items_screen.dart';
import '../../features/ai_input/view/ai_clothing_sandbox_screen.dart';
import '../../features/ai_input/view/ai_results_screen.dart';
import '../../features/bulk_creation/view/house_selection_screen.dart';
import '../../features/bulk_creation/view/template_selection_screen.dart';
import '../../features/bulk_creation/view/bulk_item_list_screen.dart';
import '../../features/tour/controllers/tour_orchestrator.dart';
import '../../features/tour/model/onboarding_state.dart';
import '../../features/tour/providers/post_login_onboarding_provider.dart';
import '../../features/tour/view/ai_onboarding_intro_screen.dart';
import '../../features/tour/widgets/tour_trigger_wrapper.dart';
import '../../shared/dev/ds_theme_showcase_screen.dart';
import '../../shared/widgets/main_shell.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _profileNavigatorKey = GlobalKey<NavigatorState>();
final _housesNavigatorKey = GlobalKey<NavigatorState>();
final _tripsNavigatorKey = GlobalKey<NavigatorState>();

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (_, _) {
      notifyListeners();
    });
    ref.listen<AsyncValue<bool>>(onboardingStatusProvider, (_, _) {
      notifyListeners();
    });
    ref.listen<AsyncValue<OnboardingState>>(postLoginOnboardingProvider, (
      _,
      _,
    ) {
      notifyListeners();
    });
  }
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final authChangeNotifier = _AuthChangeNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      // 1. Wait for bootstrap
      final bootstrapState = ref.read(appBootstrapProvider);
      if (bootstrapState is! AsyncData) return null;

      // 2. Onboarding check
      final onboardingState = ref.read(onboardingStatusProvider);
      final bool onboardingCompleted = onboardingState.valueOrNull ?? false;
      final bool isOnOnboarding = state.matchedLocation == '/onboarding';

      if (!onboardingCompleted && !isOnOnboarding) return '/onboarding';
      if (onboardingCompleted && isOnOnboarding) return '/login';
      if (isOnOnboarding) {
        return null; // in-progress onboarding bypasses auth check
      }

      // 3. Auth check (unchanged)
      final authState = ref.read(authNotifierProvider);
      final isAuthenticated = authState is Authenticated;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isAuthenticated && !isOnLogin) {
        debugPrint('[Router] redirect → /login (not authenticated)');
        return '/login';
      }
      if (isAuthenticated && isOnLogin) {
        debugPrint('[Router] redirect → / (authenticated, leaving login)');
        return '/';
      }

      // 4. Post-login onboarding redirect
      if (isAuthenticated) {
        final postLoginAsync = ref.read(postLoginOnboardingProvider);
        final postLoginStep = postLoginAsync.valueOrNull?.step;
        final isOnAiIntro = state.matchedLocation.startsWith(
          '/onboarding-ai-intro',
        );

        if (postLoginStep == OnboardingStep.aiIntro && !isOnAiIntro) {
          return '/onboarding-ai-intro';
        }
        if (postLoginStep != null &&
            postLoginStep != OnboardingStep.aiIntro &&
            isOnAiIntro) {
          return '/';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding-ai-intro',
        name: 'onboarding-ai-intro',
        builder: (context, state) => const AiOnboardingIntroScreen(),
      ),
      GoRoute(
        path: '/onboarding-ai-intro/results',
        name: 'onboarding-ai-intro-results',
        builder: (context, state) =>
            const AiResultsScreen(isFirstTimeOnboarding: true),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            TourListener(child: MainShell(navigationShell: navigationShell)),
        branches: [
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
          StatefulShellBranch(
            navigatorKey: _tripsNavigatorKey,
            routes: [
              GoRoute(
                path: '/trips',
                name: 'trips',
                builder: (context, state) => const TripsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/houses/:id',
        name: 'house-detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return _ErrorScreen(message: 'errors.invalid_house_id'.tr());
          }
          return TourTriggerWrapper(
            triggerStep: OnboardingStep.moveItemsTooltip,
            houseId: id,
            title: 'tour.move_items_tooltip.title'.tr(),
            body: 'tour.move_items_tooltip.body'.tr(),
            child: HouseDetailScreen(houseId: id),
          );
        },
      ),
      GoRoute(
        path: '/houses/:id/ai-import',
        name: 'ai-import',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return _ErrorScreen(message: 'errors.invalid_house_id'.tr());
          }
          return AiClothingSandboxScreen(houseId: id);
        },
      ),
      GoRoute(
        path: '/houses/:id/ai-import/results',
        name: 'ai-import-results',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return _ErrorScreen(message: 'errors.invalid_house_id'.tr());
          }
          return AiResultsScreen(houseId: id, isFirstTimeOnboarding: false);
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
        builder: (context, state) => TourTriggerWrapper(
          triggerStep: OnboardingStep.tripCreationTooltip,
          title: 'tour.trip_creation_tooltip.title'.tr(),
          body: 'tour.trip_creation_tooltip.body'.tr(),
          advancesOnOk: true,
          child: const AddTripScreen(),
        ),
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
      GoRoute(
        path: '/dev/ds-showcase',
        name: 'ds-showcase',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          if (!kDebugMode) {
            return _ErrorScreen(message: 'errors.feature_disabled'.tr());
          }
          return const DsThemeShowcaseScreen();
        },
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(
      message: 'common.navigation_error'.tr(args: [state.error.toString()]),
    ),
  );
}

/// Pagina di errore "full screen" usata dal router quando un path matcha ma
/// i parametri sono invalidi, una feature è disabilitata, o `errorBuilder`
/// finale di GoRouter ha catturato un errore di navigazione. Single source
/// of truth: prima esisteva sia inline in `errorBuilder` sia come classe
/// separata, con lo stesso layout copiato due volte.
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
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            AppSpacing.gapMd,
            Text(
              message,
              style: TextStyle(
                fontSize: context.fontSizeMd,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapMd,
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

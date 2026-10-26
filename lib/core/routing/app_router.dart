import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../bootstrap.dart';
import '../../features/onboarding/providers/onboarding_status_provider.dart';
import '../analytics/core_analytics_service.dart';
import 'analytics_navigator_observer.dart';
import '../../features/onboarding/view/onboarding_screen.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_state.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/houses/view/houses_screen.dart';
import '../../features/houses/view/add_edit_house_screen.dart';
import '../../features/houses/view/house_detail_screen.dart';
import '../../features/profile/view/profile_screen.dart';
import '../../features/trips/view/ai_packing_wait_screen.dart';
import '../../features/trips/view/trips_screen.dart';
import '../../features/trips/view/trip_detail_screen.dart';
import '../../features/trips/view/new_trip_screen.dart';
import '../../features/trips/view/pack_suitcase_screen.dart';
import '../../features/trips/view/trip_weather_screen.dart';
import '../../features/ai_input/view/ai_results_screen.dart';
import '../../features/tour/controllers/tour_orchestrator.dart';
import '../../features/tour/model/onboarding_state.dart';
import '../../features/tour/providers/post_login_onboarding_provider.dart';
import '../../features/tour/tour_keys.dart';
import '../../features/tour/view/ai_onboarding_intro_screen.dart';
import '../../features/tour/widgets/tour_trigger_wrapper.dart';
import '../../shared/dev/ds_theme_showcase_screen.dart';
import '../../shared/widgets/main_shell.dart';
import '../../shared/widgets/ds_not_found_state.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
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

  final analytics = ref.read(coreAnalyticsServiceProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    observers: [AnalyticsNavigatorObserver(analytics)],
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
          // Dopo la prova AI si entra nella casa appena creata, con i capi
          // scansionati e il primo tip del tour.
          final houseId = postLoginAsync.valueOrNull?.defaultHouseId;
          if (postLoginStep == OnboardingStep.houseDetailTooltip &&
              houseId != null) {
            return '/houses/$houseId';
          }
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
        path: '/profile',
        name: 'profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/houses/:id',
        name: 'house-detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return _ErrorScreen(message: 'common.content_unavailable'.tr());
          }
          return TourTriggerWrapper(
            triggerStep: OnboardingStep.houseDetailTooltip,
            houseId: id,
            title: 'tour.house_detail_tooltip.title'.tr(),
            body: 'tour.house_detail_tooltip.body'.tr(),
            keyTarget: tourKeys.houseTitle,
            isSpotlight: true,
            // Target nell'AppBar: la card deve stare sotto, non sopra (il
            // default per gli step spotlight la metterebbe fuori vista).
            align: ContentAlign.bottom,
            advancesOnOk: true,
            // Toccare il nome evidenziato fa quello che il tip suggerisce.
            onTargetTap: () => showAddEditHouseSheet(context, houseId: id),
            child: HouseDetailScreen(
              houseId: id,
              // `?add=manual` arriva da Crea → "scrivili a mano".
              openRapidFire: state.uri.queryParameters['add'] == 'manual',
            ),
          );
        },
      ),
      GoRoute(
        path: '/houses/:id/ai-import/results',
        name: 'ai-import-results',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return _ErrorScreen(message: 'common.content_unavailable'.tr());
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
            return _ErrorScreen(message: 'common.content_unavailable'.tr());
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
          child: NewTripScreen(
            aiIntent: state.uri.queryParameters['ai'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/trips/:id/edit-info',
        name: 'trip-edit-info',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return _ErrorScreen(message: 'common.content_unavailable'.tr());
          }
          // Stessa pagina del nuovo viaggio, in modifica.
          return NewTripScreen(
            tripId: id,
            discardOnExit: state.uri.queryParameters['reuse'] == '1',
          );
        },
      ),
      GoRoute(
        path: '/trips/:id/edit-items',
        name: 'trip-edit-items',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return _ErrorScreen(message: 'common.content_unavailable'.tr());
          }
          return PackSuitcaseScreen(
            tripId: id,
            fromNewTrip: state.uri.queryParameters['from'] == 'new',
            startAi: state.uri.queryParameters['ai'] == '1',
          );
        },
      ),
      GoRoute(
        path: '/trips/:id/weather',
        name: 'trip-weather',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return _ErrorScreen(message: 'common.content_unavailable'.tr());
          }
          return TripWeatherScreen(
            tripId: id,
            stopIndex:
                int.tryParse(state.uri.queryParameters['stop'] ?? '') ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/trips/:id/ai-packing',
        name: 'trip-ai-packing',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          final job = state.extra;
          if (id == null || id.isEmpty || job is! PackTripJob) {
            return _ErrorScreen(message: 'errors.invalid_trip_id'.tr());
          }
          return AiPackingWaitScreen(tripId: id, job: job);
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
      title: 'common.page_not_found'.tr(),
      message: 'common.page_not_found_hint'.tr(),
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
  final String? title;

  const _ErrorScreen({required this.message, this.title});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title ?? 'common.page_unavailable'.tr())),
    body: DsNotFoundState(
      title: title ?? 'common.page_unavailable'.tr(),
      message: message,
      actionLabel: 'houses.back_to_houses'.tr(),
      onAction: () => context.go('/'),
    ),
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/bootstrap.dart' show appBootstrapProvider;
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/auth/auth_provider.dart';
import 'package:pack_log/core/auth/auth_state.dart';
import 'package:pack_log/core/routing/app_router.dart';
import 'package:pack_log/features/onboarding/providers/onboarding_status_provider.dart';
import 'package:pack_log/features/tour/model/onboarding_state.dart';
import 'package:pack_log/features/tour/providers/post_login_onboarding_provider.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/shared/widgets/ds_field.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import '../../helpers/memory_asset_loader.dart';

class _Auth extends AuthNotifier {
  _Auth(this.initial);

  final AuthState initial;

  @override
  AuthState build() => initial;

  void change(AuthState next) => state = next;
}

class _Onboarding extends OnboardingStatus {
  @override
  Future<bool> build() async => true;
}

class _PostLogin extends PostLoginOnboarding {
  @override
  Future<OnboardingState> build() async =>
      const OnboardingState(step: OnboardingStep.done, hasExistingHouses: true);
}

class _Analytics extends Mock implements CoreAnalyticsService {}

class _EmptyItems extends ItemNotifier {
  @override
  Future<List<ItemModel>> build(String houseId) async => const [];
}

void main() {
  test(
    'same UID refresh preserves router; different UID gets fresh navigators',
    () async {
      const userA = AuthState.authenticated(
        userId: 'user-A',
        email: 'a@example.test',
      );
      final auth = _Auth(userA);
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => auth),
          appBootstrapProvider.overrideWith((ref) async {}),
          onboardingStatusProvider.overrideWith(_Onboarding.new),
          postLoginOnboardingProvider.overrideWith(_PostLogin.new),
          coreAnalyticsServiceProvider.overrideWith((ref) => _Analytics()),
        ],
      );
      addTearDown(container.dispose);

      final firstRouter = container.read(appRouterProvider);
      final firstRootKey = firstRouter.routerDelegate.navigatorKey;

      auth.change(
        const AuthState.authenticated(
          userId: 'user-A',
          email: 'a-refreshed@example.test',
        ),
      );
      await container.pump();
      expect(container.read(appRouterProvider), same(firstRouter));

      auth.change(
        const AuthState.authenticated(
          userId: 'user-B',
          email: 'b@example.test',
        ),
      );
      await container.pump();
      final nextRouter = container.read(appRouterProvider);
      expect(nextRouter, isNot(same(firstRouter)));
      expect(nextRouter.routerDelegate.navigatorKey, isNot(same(firstRootKey)));
    },
  );

  testWidgets(
    'same UID keeps a private kit draft; switching UID drops the modal route',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      const userA = AuthState.authenticated(
        userId: 'user-A',
        email: 'a@example.test',
      );
      final auth = _Auth(userA);
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => auth),
          appBootstrapProvider.overrideWith((ref) async {}),
          onboardingStatusProvider.overrideWith(_Onboarding.new),
          postLoginOnboardingProvider.overrideWith(_PostLogin.new),
          coreAnalyticsServiceProvider.overrideWith((ref) => _Analytics()),
          itemNotifierProvider('house-A').overrideWith(_EmptyItems.new),
        ],
      );
      addTearDown(container.dispose);
      var router = container.read(appRouterProvider);
      router.go('/nonexistent-session-test');

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US'), Locale('it', 'IT')],
          path: 'assets/translations',
          assetLoader: MemoryAssetLoader(readAppTranslations()),
          fallbackLocale: const Locale('en', 'US'),
          startLocale: const Locale('it', 'IT'),
          saveLocale: false,
          child: UncontrolledProviderScope(
            container: container,
            child: Consumer(
              builder: (context, ref, _) {
                router = ref.watch(appRouterProvider);
                return MaterialApp.router(
                  key: ObjectKey(router),
                  routerConfig: router,
                  theme: AppTheme.light,
                  builder: (context, child) => Scaffold(body: child),
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      router.go('/houses/house-A/kits/new');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final draftField = find.byKey(const Key('kit_name_field'));
      expect(draftField, findsOneWidget);
      await tester.enterText(draftField, 'Private draft from A');
      await tester.pump();
      ScaffoldMessenger.of(tester.element(draftField)).showSnackBar(
        const SnackBar(
          content: Text('Private notice from A'),
          duration: Duration(days: 1),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      auth.change(
        const AuthState.authenticated(
          userId: 'user-A',
          email: 'a-refreshed@example.test',
        ),
      );
      expect(container.read(appRouterProvider), same(router));
      await tester.pump();
      expect(
        tester.widget<DsTextField>(draftField).controller?.text,
        'Private draft from A',
      );
      expect(find.text('Private notice from A'), findsOneWidget);

      auth.change(
        const AuthState.authenticated(
          userId: 'user-B',
          email: 'b@example.test',
        ),
      );
      final routerForB = container.read(appRouterProvider);
      expect(routerForB, isNot(same(router)));
      routerForB.go('/nonexistent-session-test');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('kit_name_field')), findsNothing);
      expect(find.text('Private draft from A'), findsNothing);
      expect(find.text('Private notice from A'), findsNothing);
    },
  );
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/features/tour/controllers/tour_orchestrator.dart';
import 'package:pack_log/features/tour/model/onboarding_state.dart';
import 'package:pack_log/features/tour/providers/post_login_onboarding_provider.dart';
import 'package:pack_log/features/tour/repositories/i_onboarding_repository.dart';
import 'package:pack_log/features/tour/repositories/shared_prefs_onboarding_repository.dart';
import 'package:pack_log/features/tour/tour_keys.dart';
import 'package:pack_log/features/tour/widgets/tour_step_content.dart';

class MockOnboardingRepository extends Mock implements IOnboardingRepository {}

class MockAnalytics extends Mock implements AppAnalyticsService {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(OnboardingStep.aiIntro);
  });

  /// Repo che parte da [step] e accetta ogni save.
  MockOnboardingRepository repoAt(OnboardingStep step) {
    final repo = MockOnboardingRepository();
    when(() => repo.loadStep()).thenAnswer((_) async => step);
    when(() => repo.loadSkippedAi()).thenAnswer((_) async => false);
    when(() => repo.loadHasExistingHouses()).thenAnswer((_) async => false);
    when(() => repo.loadDefaultHouseId()).thenAnswer((_) async => null);
    when(() => repo.saveStep(any())).thenAnswer((_) async {});
    when(() => repo.saveSkippedAi(any())).thenAnswer((_) async {});
    when(() => repo.saveHasExistingHouses(any())).thenAnswer((_) async {});
    when(() => repo.saveDefaultHouseId(any())).thenAnswer((_) async {});
    return repo;
  }

  Widget wrap(ProviderContainer container, Widget shell) {
    return EasyLocalization(
      // Nei widget test gli asset di traduzione non vengono bundlati, quindi
      // `.tr()` ritorna la chiave grezza e nei log compaiono dei warning
      // "Localization key not found": innocui. Per questo le asserzioni qui
      // sotto guardano i TIPI di widget e non le stringhe.
      supportedLocales: const [Locale('en', 'US'), Locale('it', 'IT')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      saveLocale: false,
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PostLoginOnboardingListener(child: shell)),
      ),
    );
  }

  /// Schermata che espone il target dei tip spotlight della shell.
  Widget shellScreen() => Scaffold(
    body: Center(
      child: SizedBox(key: tourKeys.houseFab, width: 48, height: 48),
    ),
  );

  // Copre il post-frame callback + `_routeTransitionSettleDelay` (350 ms) +
  // l'animazione di entrata della card.
  //
  // Niente `pumpAndSettle`: gli step spotlight usano `pulseEnable: true`, cioè
  // un'animazione che si ripete all'infinito e che manderebbe pumpAndSettle in
  // timeout. Per lo stesso motivo anche le transizioni di route qui sotto sono
  // avanzate con pump espliciti.
  // Misurato: la card compare intorno ai 1400 ms (350 ms di
  // `_routeTransitionSettleDelay` + le animazioni interne di
  // TutorialCoachMark). Pompiamo con margine, altrimenti un `findsNothing`
  // passerebbe solo perché non abbiamo aspettato abbastanza.
  Future<void> settleTooltip(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> settleRoute(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'non mostra il tooltip mentre una route è pushata sopra la shell, '
    'e lo mostra al ritorno',
    (tester) async {
      final analytics = MockAnalytics();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});

      // moveItemsTooltip non è uno step del listener: nulla scatta all'avvio.
      final container = ProviderContainer(
        overrides: [
          onboardingRepositoryProvider.overrideWithValue(
            repoAt(OnboardingStep.moveItemsTooltip),
          ),
          analyticsServiceProvider.overrideWithValue(analytics),
        ],
      );
      addTearDown(container.dispose);
      await container.read(postLoginOnboardingProvider.future);

      await tester.pumpWidget(wrap(container, shellScreen()));
      await settleTooltip(tester);
      expect(find.byType(TourStepContent), findsNothing);

      // L'utente apre il dettaglio casa: nel router quella route usa
      // `parentNavigatorKey: _rootNavigatorKey`, quindi viene pushata SOPRA
      // la shell, che però resta montata sotto.
      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('house detail')),
        ),
      );
      await settleRoute(tester);
      expect(find.text('house detail'), findsOneWidget);

      // Il TourTriggerWrapper della route avanza lo step:
      // moveItemsTooltip -> createTripTooltip, che È uno step del listener.
      await container.read(postLoginOnboardingProvider.notifier).advance();
      await settleTooltip(tester);

      // REGRESSIONE: prima del fix il listener sparava qui il tooltip, sopra
      // il dettaglio casa e puntando a una GlobalKey non visibile.
      expect(
        find.byType(TourStepContent),
        findsNothing,
        reason:
            'il listener non deve mostrare tooltip mentre la shell è coperta',
      );

      // Tornando indietro la shell ridiventa la route corrente: il tip
      // pendente deve partire adesso.
      nav.pop();
      await settleRoute(tester);
      await settleTooltip(tester);

      expect(
        find.byType(TourStepContent),
        findsOneWidget,
        reason: 'il tip pendente deve apparire al ritorno sulla shell',
      );
    },
  );

  testWidgets('mostra il tooltip quando la shell è la route corrente', (
    tester,
  ) async {
    final analytics = MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(
          repoAt(OnboardingStep.houseTooltip),
        ),
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
    );
    addTearDown(container.dispose);
    await container.read(postLoginOnboardingProvider.future);

    await tester.pumpWidget(wrap(container, shellScreen()));
    await settleTooltip(tester);

    expect(find.byType(TourStepContent), findsOneWidget);
  });
}

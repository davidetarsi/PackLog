import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../core/analytics/analytics_service.dart';
import '../model/onboarding_state.dart';
import '../providers/post_login_onboarding_provider.dart';
import '../tour_keys.dart';
import '../widgets/tour_step_content.dart';

/// Wraps [MainShell] and shows overlay tooltips for the three steps
/// whose targets live in the shell: [houseTooltip], [defaultHouseTooltip],
/// and [createTripTooltip]. The remaining steps ([moveItemsTooltip] and
/// [tripCreationTooltip]) are handled by [TourTriggerWrapper] in the router.
class PostLoginOnboardingListener extends ConsumerStatefulWidget {
  final Widget child;
  const PostLoginOnboardingListener({super.key, required this.child});

  @override
  ConsumerState<PostLoginOnboardingListener> createState() =>
      _PostLoginOnboardingListenerState();
}

/// Alias so existing router code that references TourListener still compiles
/// until the router import is updated in Task 12.
typedef TourListener = PostLoginOnboardingListener;

class _PostLoginOnboardingListenerState
    extends ConsumerState<PostLoginOnboardingListener> {
  OnboardingStep? _lastShownStep;

  /// Vedi commento nel `build()`: copre la transizione di route verso
  /// MainShell alla primissima apparizione post-login.
  static const _routeTransitionSettleDelay = Duration(milliseconds: 350);

  @override
  Widget build(BuildContext context) {
    final onboardingAsync = ref.watch(postLoginOnboardingProvider);

    // Le route di dettaglio (`/houses/:id`, `/new-trip`) sono dichiarate con
    // `parentNavigatorKey: _rootNavigatorKey`: vengono spinte SOPRA la shell,
    // che però resta montata sotto (le route non in cima mantengono lo stato)
    // e continua quindi a ricostruirsi. Senza questo gate, un avanzamento di
    // step fatto da un `TourTriggerWrapper` su quelle route farebbe scattare
    // qui il tip successivo sopra la schermata sbagliata, per giunta puntando
    // a una GlobalKey (`tourKeys.houseFab`) in quel momento coperta.
    //
    // `ModalRoute.of` registra una dipendenza da `_ModalScopeStatus`, che
    // notifica i dipendenti quando `isCurrent` cambia: al ritorno sulla shell
    // questo build rigira da solo e il tip rimasto in sospeso parte allora.
    final isShellCurrent = ModalRoute.of(context)?.isCurrent ?? true;

    ref.listen<AsyncValue<OnboardingState>>(postLoginOnboardingProvider, (
      _,
      next,
    ) {
      if (next.valueOrNull?.step == OnboardingStep.aiIntro) {
        setState(() => _lastShownStep = null);
      }
    });

    onboardingAsync.whenData((onboarding) {
      final step = onboarding.step;
      if (isShellCurrent && _isListenerStep(step) && _lastShownStep != step) {
        // Marcato SUBITO, non dentro `_showTooltip`: fra lo scheduling e
        // l'esecuzione differita passano altri build (ora anche a ogni
        // cambio di `isCurrent`), che altrimenti schedulerebbero un secondo
        // tooltip identico sopra il primo.
        _lastShownStep = step;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // `houseTooltip` è il primo step di questo listener a poter
          // scattare sul frame stesso in cui MainShell viene montato per la
          // prima volta in sessione (subito dopo il redirect da
          // /onboarding-ai-intro): la posizione della GlobalKey può essere
          // catturata mentre la transizione di route è ancora in corso,
          // producendo un highlight visivamente spostato. Gli altri step di
          // questo listener arrivano dopo interazione dell'utente, quindi
          // MainShell è già stabile — il ritardo qui è innocuo per loro.
          Future.delayed(_routeTransitionSettleDelay, () {
            // `this.context`, non il parametro di `build`: quest'ultimo
            // resterebbe catturato oltre il gap asincrono del delay.
            if (mounted) _showTooltip(this.context, onboarding);
          });
        });
      }
    });

    return widget.child;
  }

  bool _isListenerStep(OnboardingStep step) {
    return step == OnboardingStep.houseTooltip ||
        step == OnboardingStep.defaultHouseTooltip ||
        step == OnboardingStep.createTripTooltip;
  }

  void _showTooltip(BuildContext context, OnboardingState onboarding) {
    // `_lastShownStep` è già stato marcato nel `build` che ha schedulato
    // questa chiamata — vedi il commento lì.
    final notifier = ref.read(postLoginOnboardingProvider.notifier);
    final analytics = ref.read(analyticsServiceProvider);
    // step_index: numero d'ordine 1-based del tip nel tour (vedi
    // OnboardingStepTourIndex), per costruire il funnel per posizione senza
    // dover riordinare a mano i nomi degli step.
    final stepProps = {
      'step_name': onboarding.step.name,
      'step_index': onboarding.step.tourStepIndex,
    };
    analytics.logEvent('onboarding_step_viewed', properties: stepProps);

    // Collo di bottiglia unico per l'evento di avanzamento: sia il bottone
    // Avanti sia — negli step spotlight — il tap sull'elemento evidenziato
    // portano qui, così il funnel conta un solo evento per avanzamento reale
    // indipendentemente da quale delle due vie l'utente ha usato.
    void advance() {
      analytics.logEvent('onboarding_step_advanced', properties: stepProps);
      notifier.advance();
    }

    final cfg = _stepConfig(onboarding.step);

    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: onboarding.step.name,
          keyTarget: cfg.key,
          shape: cfg.isSpotlight
              ? ShapeLightFocus.RRect
              : ShapeLightFocus.Circle,
          radius: cfg.isSpotlight ? 8.0 : 1.0,
          // Scorciatoia in più per gli step spotlight: toccare l'elemento
          // evidenziato avanza anche senza passare dal bottone Avanti.
          enableTargetTab: cfg.isSpotlight,
          contents: [
            TargetContent(
              align:
                  cfg.align ??
                  (cfg.isSpotlight ? ContentAlign.top : ContentAlign.bottom),
              builder: (ctx, controller) {
                return TourStepContent(
                  title: cfg.title,
                  body: cfg.body,
                  stepIndex: 0,
                  totalSteps: 1,
                  onSkip: () {
                    controller.skip();
                    // Chiude l'intero tour, non solo lo step corrente — vedi
                    // `PostLoginOnboarding.markDone`.
                    analytics.logEvent(
                      'onboarding_closed',
                      properties: stepProps,
                    );
                    notifier.markDone();
                  },
                  onNext: () {
                    controller.next();
                    advance();
                  },
                  isLastStep: true,
                );
              },
            ),
          ],
        ),
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.8,
      hideSkip: true,
      pulseEnable: cfg.isSpotlight,
      // Scorciatoia in più per gli step spotlight: vedi enableTargetTab sopra.
      onClickTarget: cfg.isSpotlight ? (_) => advance() : null,
    ).show(context: context);
  }

  _StepConfig _stepConfig(OnboardingStep step) {
    return switch (step) {
      OnboardingStep.houseTooltip => _StepConfig(
        key: tourKeys.houseFab,
        title: 'tour.house_tooltip.title'.tr(),
        body: 'tour.house_tooltip.body'.tr(),
        isSpotlight: true,
      ),
      OnboardingStep.defaultHouseTooltip => _StepConfig(
        key: tourKeys.infoCardTarget,
        title: 'tour.default_house_tooltip.title'.tr(),
        body: 'tour.default_house_tooltip.body'.tr(),
        isSpotlight: false,
        align: ContentAlign.top,
      ),
      OnboardingStep.createTripTooltip => _StepConfig(
        key: tourKeys.houseFab,
        title: 'tour.create_trip_tooltip.title'.tr(),
        body: 'tour.create_trip_tooltip.body'.tr(),
        isSpotlight: true,
      ),
      _ => throw StateError('_isListenerStep returned true for $step'),
    };
  }
}

class _StepConfig {
  final GlobalKey key;
  final String title;
  final String body;
  final bool isSpotlight;
  final ContentAlign? align;

  const _StepConfig({
    required this.key,
    required this.title,
    required this.body,
    required this.isSpotlight,
    this.align,
  });
}

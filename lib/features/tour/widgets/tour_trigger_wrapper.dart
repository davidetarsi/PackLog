import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../houses/providers/house_provider.dart';
import '../model/onboarding_state.dart';
import '../providers/post_login_onboarding_provider.dart';
import '../tour_keys.dart';
import 'tour_step_content.dart';

/// Wraps a screen and fires a single-target [TutorialCoachMark] card once
/// when [triggerStep] matches the current onboarding step.
///
/// For [OnboardingStep.moveItemsTooltip], pass [houseId] — the tooltip fires
/// only when [houseId] matches [OnboardingState.defaultHouseId].
/// For [OnboardingStep.tripCreationTooltip], set [advancesOnOk] = true so
/// tapping "Ok"/"Next" calls [PostLoginOnboarding.advance].
class TourTriggerWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final OnboardingStep triggerStep;
  final String title;
  final String body;
  final String? houseId;
  final bool advancesOnOk;
  final GlobalKey? keyTarget;
  final bool isSpotlight;

  /// Override esplicito della posizione della card rispetto al target.
  /// Se null, usa il default legato a [isSpotlight] (top per spotlight,
  /// bottom altrimenti) — non adatto quando il target reale sta vicino
  /// alla cima dello schermo, perché "top" spingerebbe la card fuori vista.
  final ContentAlign? align;

  /// Se true, il tip non scatta finché non esistono almeno 2 case.
  ///
  /// Usato da [OnboardingStep.moveItemsTooltip]: insegna a spostare oggetti
  /// verso un'altra casa, ma se esiste solo la casa di prova creata
  /// dall'onboarding AI non c'è ancora una destinazione valida.
  final bool requiresMultipleHouses;

  const TourTriggerWrapper({
    super.key,
    required this.child,
    required this.triggerStep,
    required this.title,
    required this.body,
    this.houseId,
    this.advancesOnOk = false,
    this.keyTarget,
    this.isSpotlight = false,
    this.align,
    this.requiresMultipleHouses = false,
  });

  @override
  ConsumerState<TourTriggerWrapper> createState() => _TourTriggerWrapperState();
}

class _TourTriggerWrapperState extends ConsumerState<TourTriggerWrapper> {
  bool _shown = false;

  /// Vedi il commento gemello in `PostLoginOnboardingListener`: questo
  /// widget scatta anch'esso su una route appena montata (house-detail,
  /// new-trip), quindi è esposto alla stessa finestra di transizione.
  static const _routeTransitionSettleDelay = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeShow();
    });
  }

  void _maybeShow() {
    final onboarding = ref.read(postLoginOnboardingProvider).valueOrNull;
    if (onboarding == null || _shown) return;
    if (onboarding.step != widget.triggerStep) return;
    if (widget.houseId != null && widget.houseId != onboarding.defaultHouseId) {
      return;
    }
    if (widget.requiresMultipleHouses) {
      final houses = ref.read(houseNotifierProvider).valueOrNull;
      if (houses == null || houses.length < 2) return;
    }
    _shown = true;
    Future.delayed(_routeTransitionSettleDelay, () {
      if (mounted) _showCoachMark(onboarding);
    });
  }

  void _showCoachMark(OnboardingState onboarding) {
    final notifier = ref.read(postLoginOnboardingProvider.notifier);
    final analytics = ref.read(analyticsServiceProvider);
    // step_index: vedi il commento gemello in tour_orchestrator.dart.
    final stepProps = {
      'step_name': onboarding.step.name,
      'step_index': onboarding.step.tourStepIndex,
    };
    analytics.logEvent('onboarding_step_viewed', properties: stepProps);

    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: widget.triggerStep.name,
          keyTarget: widget.keyTarget ?? tourKeys.infoCardTarget,
          shape: widget.isSpotlight
              ? ShapeLightFocus.RRect
              : ShapeLightFocus.Circle,
          radius: widget.isSpotlight ? 8.0 : 1.0,
          enableTargetTab: false,
          contents: [
            TargetContent(
              align:
                  widget.align ??
                  (widget.isSpotlight ? ContentAlign.top : ContentAlign.bottom),
              builder: (ctx, controller) {
                return TourStepContent(
                  title: widget.title,
                  body: widget.body,
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
                    if (widget.advancesOnOk) {
                      analytics.logEvent(
                        'onboarding_step_advanced',
                        properties: stepProps,
                      );
                      notifier.advance();
                    }
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
      pulseEnable: widget.isSpotlight,
    ).show(context: context);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<OnboardingState>>(postLoginOnboardingProvider, (
      _,
      next,
    ) {
      if (!_shown) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeShow();
        });
      }
    });
    return widget.child;
  }
}

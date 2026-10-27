import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../model/onboarding_state.dart';
import '../providers/post_login_onboarding_provider.dart';
import '../tour_keys.dart';
import 'tour_step_content.dart';

/// Wraps a screen and fires a single-target [TutorialCoachMark] card once
/// when [triggerStep] matches the current onboarding step.
///
/// For [OnboardingStep.houseDetailTooltip], pass [houseId] — the tooltip
/// fires only when [houseId] matches [OnboardingState.defaultHouseId].
/// Set [advancesOnOk] = true so tapping "Next" calls
/// [PostLoginOnboarding.advance].
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

  /// Se non nullo, toccare l'elemento evidenziato fa avanzare il tour e poi
  /// esegue questa azione (es. apre la modifica della casa).
  final VoidCallback? onTargetTap;

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
    this.onTargetTap,
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

  /// Il bersaglio può non essere ancora montato (es. la casa appena creata
  /// arriva dal provider un attimo dopo): si riprova qualche volta.
  static const _targetRetries = 10;

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
    _shown = true;
    _showWhenTargetReady(onboarding, _targetRetries);
  }

  void _showWhenTargetReady(OnboardingState onboarding, int retriesLeft) {
    Future.delayed(_routeTransitionSettleDelay, () {
      if (!mounted) return;
      final target = widget.keyTarget;
      if (target != null && target.currentContext == null) {
        if (retriesLeft > 0) {
          _showWhenTargetReady(onboarding, retriesLeft - 1);
        } else {
          // Senza bersaglio niente tip: si riproverà alla prossima apertura.
          _shown = false;
        }
        return;
      }
      _showCoachMark(onboarding);
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
          // Senza spotlight il bersaglio è un punto invisibile al centro: niente
          // alone attorno, altrimenti resta un pallino chiaro sulla pagina.
          paddingFocus: widget.isSpotlight ? 10 : 0,
          enableTargetTab: widget.onTargetTap != null,
          contents: [
            TargetContent(
              align:
                  widget.align ??
                  (widget.isSpotlight ? ContentAlign.top : ContentAlign.bottom),
              builder: (ctx, controller) {
                return TourStepContent(
                  title: widget.title,
                  body: widget.body,
                  stepIndex: (onboarding.step.tourStepIndex ?? 1) - 1,
                  totalSteps: kTourLength,
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
                  isLastStep: onboarding.step.tourStepIndex == kTourLength,
                );
              },
            ),
          ],
        ),
      ],
      colorShadow: context.appColors.tourScrim,
      opacityShadow: 0.8,
      hideSkip: true,
      pulseEnable: widget.isSpotlight,
      onClickTarget: widget.onTargetTap == null
          ? null
          : (_) {
              analytics.logEvent(
                'onboarding_step_advanced',
                properties: stepProps,
              );
              notifier.advance();
              widget.onTargetTap!();
            },
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

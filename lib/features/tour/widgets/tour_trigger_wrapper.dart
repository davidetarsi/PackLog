import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../core/analytics/analytics_service.dart';
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
  });

  @override
  ConsumerState<TourTriggerWrapper> createState() => _TourTriggerWrapperState();
}

class _TourTriggerWrapperState extends ConsumerState<TourTriggerWrapper> {
  bool _shown = false;

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
    _showCoachMark(onboarding);
  }

  void _showCoachMark(OnboardingState onboarding) {
    final notifier = ref.read(postLoginOnboardingProvider.notifier);
    final analytics = ref.read(analyticsServiceProvider);
    analytics.logEvent(
      'onboarding_step_viewed',
      properties: {'step_name': onboarding.step.name},
    );

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
              align: widget.isSpotlight
                  ? ContentAlign.top
                  : ContentAlign.bottom,
              builder: (ctx, controller) {
                return TourStepContent(
                  title: widget.title,
                  body: widget.body,
                  stepIndex: 0,
                  totalSteps: 1,
                  onSkip: () {
                    controller.skip();
                    analytics.logEvent(
                      'onboarding_step_skipped',
                      properties: {'step_name': onboarding.step.name},
                    );
                    notifier.markDone();
                  },
                  onNext: () {
                    controller.next();
                    if (widget.advancesOnOk) notifier.advance();
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
    ref.listen<AsyncValue<OnboardingState>>(
      postLoginOnboardingProvider,
      (_, next) {
        if (!_shown) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _maybeShow();
          });
        }
      },
    );
    return widget.child;
  }
}

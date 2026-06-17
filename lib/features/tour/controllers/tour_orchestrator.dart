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

  @override
  Widget build(BuildContext context) {
    final onboardingAsync = ref.watch(postLoginOnboardingProvider);

    ref.listen<AsyncValue<OnboardingState>>(
      postLoginOnboardingProvider,
      (_, next) {
        if (next.valueOrNull?.step == OnboardingStep.aiIntro) {
          setState(() => _lastShownStep = null);
        }
      },
    );

    onboardingAsync.whenData((onboarding) {
      final step = onboarding.step;
      if (_isListenerStep(step) && _lastShownStep != step) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showTooltip(context, onboarding);
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
    setState(() => _lastShownStep = onboarding.step);

    final notifier = ref.read(postLoginOnboardingProvider.notifier);
    final analytics = ref.read(analyticsServiceProvider);
    analytics.logEvent(
      'onboarding_step_viewed',
      properties: {'step_name': onboarding.step.name},
    );

    final cfg = _stepConfig(onboarding.step);

    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: onboarding.step.name,
          keyTarget: cfg.key,
          shape: cfg.isSpotlight ? ShapeLightFocus.RRect : ShapeLightFocus.Circle,
          radius: cfg.isSpotlight ? 8.0 : 1.0,
          // Spotlight steps: tapping the highlighted element advances the tour.
          // Info steps: the tiny dot must not accidentally close the coach mark.
          enableTargetTab: cfg.isSpotlight,
          contents: [
            TargetContent(
              align: cfg.align ?? (cfg.isSpotlight ? ContentAlign.top : ContentAlign.bottom),
              builder: (ctx, controller) {
                return TourStepContent(
                  title: cfg.title,
                  body: cfg.body,
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
                  // Spotlight steps have no Avanti button: the tour advances
                  // by tapping the highlighted element via clickTarget below.
                  onNext: cfg.isSpotlight
                      ? null
                      : () {
                          controller.next();
                          notifier.advance();
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
      // Spotlight steps: advance the tour when the element is tapped.
      onClickTarget: cfg.isSpotlight ? (_) => notifier.advance() : null,
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

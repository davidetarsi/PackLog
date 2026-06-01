import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../core/analytics/analytics_service.dart';
import '../providers/tour_status_provider.dart';
import '../tour_keys.dart';
import '../widgets/tour_step_content.dart';

class TourListener extends ConsumerStatefulWidget {
  final Widget child;
  const TourListener({super.key, required this.child});

  @override
  ConsumerState<TourListener> createState() => _TourListenerState();
}

class _TourListenerState extends ConsumerState<TourListener> {
  bool _tourStarted = false;

  @override
  Widget build(BuildContext context) {
    final tourStatus = ref.watch(tourStatusProvider);

    // Quando il tour viene resettato (true → false), consenti il riavvio.
    ref.listen<AsyncValue<bool>>(tourStatusProvider, (prev, next) {
      if (prev?.valueOrNull == true && next.valueOrNull == false) {
        setState(() => _tourStarted = false);
      }
    });

    // Avvia il tour non appena lo stato risolve a false (prima volta o dopo reset).
    tourStatus.whenData((completed) {
      if (!completed && !_tourStarted) {
        _tourStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startTour(context);
        });
      }
    });

    return widget.child;
  }

  void _startTour(BuildContext context) {
    final analytics = ref.read(analyticsServiceProvider);
    int currentStep = 0;
    analytics.logEvent('tour_started');

    TutorialCoachMark(
      targets: _buildTargets(
        context,
        onStepViewed: (index, name) {
          currentStep = index;
          analytics.logEvent(
            'tour_step_viewed',
            properties: {'step_index': index, 'step_name': name},
          );
        },
      ),
      colorShadow: Colors.black,
      opacityShadow: 0.8,
      onFinish: () {
        analytics.logEvent('tour_completed');
        ref.read(tourStatusProvider.notifier).markCompleted();
      },
      onSkip: () {
        analytics.logEvent(
          'tour_skipped',
          properties: {'step_index': currentStep},
        );
        ref.read(tourStatusProvider.notifier).markCompleted();
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _buildTargets(
    BuildContext context, {
    required void Function(int index, String name) onStepViewed,
  }) {
    TargetFocus makeStep({
      required String identify,
      required GlobalKey keyTarget,
      required int index,
      ShapeLightFocus shape = ShapeLightFocus.RRect,
      double radius = 8,
      ContentAlign contentAlign = ContentAlign.top,
    }) {
      return TargetFocus(
        identify: identify,
        keyTarget: keyTarget,
        shape: shape,
        radius: radius,
        contents: [
          TargetContent(
            align: contentAlign,
            builder: (ctx, controller) {
              onStepViewed(index, identify);
              return TourStepContent(
                title: 'tour.step${index + 1}.title'.tr(),
                body: 'tour.step${index + 1}.body'.tr(),
                stepIndex: index,
                totalSteps: 6,
                onSkip: () => controller.skip(),
                onNext: () => controller.next(),
                isLastStep: index == 5,
              );
            },
          ),
        ],
      );
    }

    return [
      makeStep(
        identify: 'houses_tab',
        keyTarget: tourKeys.housesTab,
        index: 0,
      ),
      makeStep(
        identify: 'create_house',
        keyTarget: tourKeys.infoCardTarget,
        index: 1,
        shape: ShapeLightFocus.Circle,
        radius: 1,
        contentAlign: ContentAlign.bottom,
      ),
      makeStep(
        identify: 'trips_tab',
        keyTarget: tourKeys.tripsTab,
        index: 2,
      ),
      makeStep(
        identify: 'ai_import',
        keyTarget: tourKeys.infoCardTarget,
        index: 3,
        shape: ShapeLightFocus.Circle,
        radius: 1,
        contentAlign: ContentAlign.bottom,
      ),
      makeStep(
        identify: 'move_item',
        keyTarget: tourKeys.infoCardTarget,
        index: 4,
        shape: ShapeLightFocus.Circle,
        radius: 1,
        contentAlign: ContentAlign.bottom,
      ),
      makeStep(
        identify: 'profile_tab',
        keyTarget: tourKeys.profileTab,
        index: 5,
      ),
    ];
  }
}

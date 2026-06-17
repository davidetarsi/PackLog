import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/circular_action_button.dart';
import '../../../shared/widgets/universal_action_bar.dart';

class TourStepContent extends StatelessWidget {
  final String title;
  final String body;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final bool isLastStep;

  const TourStepContent({
    super.key,
    required this.title,
    required this.body,
    required this.stepIndex,
    required this.totalSteps,
    required this.onSkip,
    required this.onNext,
    required this.isLastStep,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.only(
        left: context.spacingMd,
        right: context.spacingMd,
        top: context.spacingMd,
        bottom: context.spacingSm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'tour.step_counter'.tr(namedArgs: {
                'current': '${stepIndex + 1}',
                'total': '$totalSteps',
              }),
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(height: context.spacingXs),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.spacingSm),
          Text(
            body,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.spacingMd),
          UniversalActionBar(
            horizontalPadding: 0,
            primaryLabel:
                isLastStep ? 'tour.finish'.tr() : 'tour.next'.tr(),
            onPrimaryPressed: onNext,
            leftAction: Tooltip(
              message: 'tour.skip'.tr(),
              child: CircularActionButton(
                icon: Icons.close,
                onPressed: onSkip,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

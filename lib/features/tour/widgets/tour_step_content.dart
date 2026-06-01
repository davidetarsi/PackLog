import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_spacing.dart';

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
      padding: EdgeInsets.all(context.spacingMd),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onSkip,
                child: Text('tour.skip'.tr()),
              ),
              FilledButton(
                onPressed: onNext,
                child: Text(
                  isLastStep ? 'tour.finish'.tr() : 'tour.next'.tr(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

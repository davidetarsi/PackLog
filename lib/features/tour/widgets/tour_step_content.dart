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

  /// Null in spotlight steps: the tour advances by tapping the highlighted
  /// element, so no primary "Avanti" button is shown. When non-null, shows
  /// UniversalActionBar with Avanti + circular skip.
  final VoidCallback? onNext;

  final bool isLastStep;

  const TourStepContent({
    super.key,
    required this.title,
    required this.body,
    required this.stepIndex,
    required this.totalSteps,
    required this.onSkip,
    this.onNext,
    this.isLastStep = false,
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
              'tour.step_counter'.tr(
                namedArgs: {
                  'current': '${stepIndex + 1}',
                  'total': '$totalSteps',
                },
              ),
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(height: context.spacingXs),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: context.spacingSm),
          Text(
            body,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.spacingMd),
          if (onNext != null)
            // Normal step: primary Avanti pill + circular skip on the left.
            UniversalActionBar(
              primaryLabel: 'tour.next'.tr(),
              onPrimaryPressed: onNext,
              leftAction: Tooltip(
                message: 'tour.skip'.tr(),
                child: CircularActionButton(
                  icon: Icons.close,
                  onPressed: onSkip,
                ),
              ),
            )
          else
            // Spotlight step: single secondary pill "Salta" — tour advances
            // by tapping the highlighted element, not via a primary button.
            _SecondarySkipPill(label: 'tour.skip'.tr(), onTap: onSkip),
        ],
      ),
    );
  }
}

class _SecondarySkipPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondarySkipPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: double.infinity,
      height: context.responsive(56),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AppConstants.pillBorderRadius,
              ),
              border: Border.all(color: colorScheme.outline, width: 2),
            ),
            child: Center(
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

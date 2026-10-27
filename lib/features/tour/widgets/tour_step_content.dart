import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_button.dart';

class TourStepContent extends StatelessWidget {
  final String title;
  final String body;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onSkip;

  /// Avanza il tour. Ogni tip mostra sempre Avanti, anche negli step
  /// "spotlight" dove toccare l'elemento evidenziato è una scorciatoia
  /// aggiuntiva per lo stesso avanzamento, non un sostituto.
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
    this.isLastStep = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Scheda leggera: contatore piccolo, titolo, testo, poi "Salta il tour"
    // in grigio e un solo bottone pieno.
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        context.spacingMd,
        context.spacingMd,
        context.spacingSm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'tour.step_counter'.tr(
              namedArgs: {
                'current': '${stepIndex + 1}',
                'total': '$totalSteps',
              },
            ),
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.spacingXs),
          Text(title, style: textTheme.titleMedium),
          SizedBox(height: context.spacingXs),
          Text(
            body,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.spacingMd),
          Row(
            children: [
              if (!isLastStep)
                TextButton(
                  key: const Key('tour_skip'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onSkip,
                  child: Text('tour.skip'.tr()),
                ),
              const Spacer(),
              DsButton(
                key: const Key('tour_next'),
                label: isLastStep ? 'tour.finish'.tr() : 'tour.next'.tr(),
                onPressed: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

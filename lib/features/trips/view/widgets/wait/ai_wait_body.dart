import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/packlog_gradient.dart';
import '../../../model/pack_trip_job.dart';
import 'wait_step_row.dart';
import 'wait_step_sequence.dart';
import 'watch_wait_facts.dart';

/// L'attesa mentre `pack-trip` lavora: scintilla, titolo e la card col bordo
/// che gira coi tre passi, ognuno con la sua riga quando si chiude.
class AiWaitBody extends ConsumerWidget {
  const AiWaitBody({
    super.key,
    required this.job,
    required this.tripId,
    required this.steps,
    required this.cardKey,
  });

  final PackTripJob job;
  final String tripId;
  final WaitStepSequence? steps;
  final GlobalKey cardKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = watchWaitFacts(ref, tripId: tripId, job: job);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nights = 'trips.ai.wait.nights'.plural(job.nights);
    final labels = [
      'trips.ai.wait.step_weather'.tr(args: [job.title]),
      'trips.ai.wait.step_wardrobe'.tr(),
      'trips.ai.wait.step_check'.tr(),
    ];

    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PackLogSparkle(size: context.iconSizeXl, breathing: true),
              SizedBox(height: context.spacingLg),
              Text(
                'trips.ai.wait.title'.tr(),
                style: theme.textTheme.headlineMedium?.title,
              ),
              SizedBox(height: context.spacingSm),
              Text(
                'trips.ai.wait.subtitle'.tr(args: [job.title, nights]),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: context.spacingLg),
              SizedBox(
                key: cardKey,
                width: double.infinity,
                child: PackLogGradientBorder(
                  radius: AppConstants.cardBorderRadius,
                  loops: -1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.groupSurface,
                      borderRadius: BorderRadius.circular(
                        AppConstants.cardBorderRadius,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(context.spacingMd),
                      child: Column(
                        children: [
                          for (var i = 0; i < kWaitSteps; i++) ...[
                            if (i > 0) SizedBox(height: context.spacingMd),
                            WaitStepRow(
                              label: labels[i],
                              result: facts.forStep(i),
                              state: i < (steps?.closed ?? 0)
                                  ? WaitStepState.done
                                  : i == (steps?.lit ?? 0)
                                  ? WaitStepState.current
                                  : WaitStepState.pending,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: context.spacingLg),
              Text(
                'trips.ai.wait.hint'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: context.spacingSm),
              Text(
                'trips.ai.wait.stay'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.spacingXl),
      ],
    );
  }
}

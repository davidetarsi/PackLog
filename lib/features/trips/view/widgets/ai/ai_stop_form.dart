import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_checkbox.dart';
import '../../../../../shared/widgets/ds_choice_group.dart';
import '../../../model/ai_packing.dart';

/// Le risposte di una tappa del foglio "Valigia con AI": attività, alloggio e
/// lavatrice. Con [stopName] null è il viaggio con una tappa sola, e i titoli
/// non nominano nessun luogo.
///
/// Niente copia automatica: il bottone "Uguale a …" compare solo se la tappa
/// è ancora intatta ([copyFromName] dice da quale tappa copiare).
class AiStopForm extends StatelessWidget {
  const AiStopForm({
    super.key,
    required this.answers,
    required this.onChanged,
    this.stopName,
    this.copyFromName,
    this.onCopy,
  });

  final AiStopAnswers answers;
  final ValueChanged<AiStopAnswers> onChanged;

  /// Nome della tappa nei titoli; null con una tappa sola.
  final String? stopName;

  /// Tappa da cui copiare, se il bottone "Uguale a" serve.
  final String? copyFromName;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final activitiesTitle = stopName == null
        ? 'trips.ai.activities_title_single'.tr()
        : 'trips.ai.activities_title'.tr(args: [stopName!]);
    final stayTitle = stopName == null
        ? 'trips.ai.stay_title_single'.tr()
        : 'trips.ai.stay_title'.tr(args: [stopName!]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (copyFromName != null && onCopy != null)
          Container(
            padding: EdgeInsets.only(top: context.spacingMd),
            alignment: Alignment.centerLeft,
            child: _DashedCopyButton(
              label: 'trips.ai.copy_from'.tr(args: [copyFromName!]),
              onTap: onCopy!,
            ),
          ),
        DsChoiceGroup<AiActivity>(
          title: activitiesTitle,
          options: AiActivity.values,
          labelOf: (activity) => activity.labelKey.tr(),
          selected: answers.activities.toSet(),
          multiple: true,
          required: false,
          // L'insieme tiene l'ordine dei tocchi, come la lista di prima.
          onChanged: (chosen) =>
              onChanged(answers.copyWith(activities: chosen.toList())),
        ),
        DsChoiceGroup<AiStay>(
          title: stayTitle,
          options: AiStay.values,
          labelOf: (stay) => stay.labelKey.tr(),
          selected: {?answers.stay},
          onChanged: (chosen) =>
              onChanged(answers.copyWith(stay: chosen.first)),
        ),
        SizedBox(height: context.spacingLg),
        _WasherRow(
          value: answers.washer,
          onChanged: (value) => onChanged(answers.copyWith(washer: value)),
          cs: cs,
          tt: tt,
        ),
      ],
    );
  }
}

/// Interruttore della lavatrice: neutro, mai arancio. Acceso = pista e pollice
/// chiari, come nel mockup.
class _WasherRow extends StatelessWidget {
  const _WasherRow({
    required this.value,
    required this.onChanged,
    required this.cs,
    required this.tt,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacingMd,
        vertical: context.spacingSmPlus,
      ),
      decoration: BoxDecoration(
        color: context.groupSurface,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('trips.ai.washer'.tr(), style: tt.bodyLarge),
                Text(
                  value
                      ? 'trips.ai.washer_sub_on'.tr()
                      : 'trips.ai.washer_sub'.tr(),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          DsSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// "Uguale a …": bordo tratteggiato, testo neutro, mai arancio.
class _DashedCopyButton extends StatelessWidget {
  const _DashedCopyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
      child: CustomPaint(
        painter: _DashedBorderPainter(cs.outline),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppConstants.pillTabDefault,
          ),
          padding: EdgeInsets.symmetric(horizontal: context.spacingSmPlus),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.content_copy,
                size: context.iconSizeSm,
                color: cs.onSurface,
              ),
              SizedBox(width: context.spacingSm),
              Text(label, style: tt.labelLarge?.copyWith(color: cs.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.height)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + AppConstants.dashLength),
          paint,
        );
        distance += AppConstants.dashLength + AppConstants.dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

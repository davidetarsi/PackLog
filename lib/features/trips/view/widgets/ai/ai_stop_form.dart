import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../model/ai_packing.dart';
import 'ai_choice_pill.dart';

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
          Align(
            alignment: Alignment.centerLeft,
            child: _DashedCopyButton(
              label: 'trips.ai.copy_from'.tr(args: [copyFromName!]),
              onTap: onCopy!,
            ),
          ),
        _Section(
          title: activitiesTitle,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final activity in AiActivity.values)
                AiChoicePill(
                  label: activity.labelKey.tr(),
                  selected: answers.activities.contains(activity),
                  onTap: () => onChanged(
                    answers.copyWith(
                      activities: answers.activities.contains(activity)
                          ? [
                              for (final a in answers.activities)
                                if (a != activity) a,
                            ]
                          : [...answers.activities, activity],
                    ),
                  ),
                ),
            ],
          ),
        ),
        _Section(
          title: stayTitle,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stay in AiStay.values)
                AiChoicePill(
                  label: stay.labelKey.tr(),
                  selected: answers.stay == stay,
                  onTap: () => onChanged(answers.copyWith(stay: stay)),
                ),
            ],
          ),
        ),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: cs.surface,
            activeTrackColor: cs.onSurface,
            inactiveThumbColor: cs.onSurfaceVariant,
            inactiveTrackColor: Colors.transparent,
            trackOutlineColor: WidgetStatePropertyAll(
              value ? cs.onSurface : cs.outline,
            ),
          ),
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
      borderRadius: BorderRadius.circular(20),
      child: CustomPaint(
        painter: _DashedBorderPainter(cs.outline),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.content_copy, size: 16, color: cs.onSurface),
              const SizedBox(width: 8),
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
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

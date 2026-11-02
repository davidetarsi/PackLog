import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../model/ai_packing.dart';
import '../../../model/suitcase_progress.dart';

// La testata di "Cosa porti" con la valigia fatta di posti e le
// informazioni sul viaggio.
//
// Colori provvisori: i proposti usano `tertiary` (ambra).

/// Testata di "Cosa porti".
///
/// Finché c'è un importante aperto ([SuitcaseProgress.sorting]) mostra
/// "N di M pronti" con la barra divisa (tue, proposte) e la legenda; poi le
/// spunte di sempre, "N di M in valigia". Con [SuitcaseProgress.isEmpty] non
/// va mostrata: il chiamante mette lo stato vuoto.
class SuitcaseProgressHeader extends StatelessWidget {
  const SuitcaseProgressHeader({super.key, required this.progress});

  final SuitcaseProgress progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final countStyle = tt.labelLarge?.copyWith(color: cs.onSurfaceVariant);

    if (!progress.sorting) {
      final total = progress.packTotal;
      return Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                AppConstants.pillBorderRadius,
              ),
              child: LinearProgressIndicator(
                key: const Key('trip_detail_progress'),
                value: total == 0 ? 0 : progress.checked / total,
                minHeight: context.spacingXs,
                backgroundColor: cs.surfaceContainerHighest,
                color: cs.onSurface,
              ),
            ),
          ),
          SizedBox(width: context.spacingSm),
          Text(
            'trips.detail.packed_count'.tr(
              args: ['${progress.checked}', '$total'],
            ),
            style: countStyle,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _ReadyBar(progress: progress)),
            SizedBox(width: context.spacingSm),
            Text(
              'trips.detail.ready_count'.tr(
                args: ['${progress.ready}', '${progress.readyTotal}'],
              ),
              style: countStyle,
            ),
          ],
        ),
        SizedBox(height: context.spacingSm),
        Wrap(
          spacing: context.spacingMd,
          runSpacing: context.spacingXs,
          children: [
            _LegendEntry(
              dot: _LegendDot(color: cs.onSurface),
              label: 'trips.detail.legend_mine'.tr(args: ['${progress.mine}']),
            ),
            _LegendEntry(
              dot: _LegendDot(color: cs.tertiary),
              label: 'trips.detail.legend_proposed'.tr(
                args: ['${progress.proposed}'],
              ),
            ),
            _LegendEntry(
              dot: _LegendDot(outline: cs.onSurfaceVariant),
              label: 'trips.detail.legend_important'.tr(
                args: ['${progress.importantOpen}'],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// La barra di "N di M pronti": prima le tue, poi le proposte, il resto
/// (gli importanti da sistemare) è il fondo vuoto.
class _ReadyBar extends StatelessWidget {
  const _ReadyBar({required this.progress});

  final SuitcaseProgress progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final segments = [
      (progress.mine, cs.onSurface),
      (progress.proposed, cs.tertiary),
      (progress.importantOpen, cs.surfaceContainerHighest),
    ];
    return ClipRRect(
      key: const Key('trip_detail_ready_progress'),
      borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
      child: SizedBox(
        height: context.spacingXs,
        // Senza stretch i segmenti, che non hanno figli, restano alti zero.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (flex, color) in segments)
              if (flex > 0)
                Expanded(
                  flex: flex,
                  child: ColoredBox(color: color),
                ),
          ],
        ),
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.dot, required this.label});

  final Widget dot;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        SizedBox(width: context.spacingXs),
        Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

/// Pallino della legenda: pieno con [color], vuoto con il bordo [outline].
class _LegendDot extends StatelessWidget {
  const _LegendDot({this.color, this.outline});

  final Color? color;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    final border = outline;
    return Container(
      width: context.spacingSm,
      height: context.spacingSm,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: border == null ? null : Border.all(color: border, width: 1.5),
      ),
    );
  }
}

/// Un'informazione sul viaggio ("Prevedi una lavanderia"): icona, titolo e
/// perché, con i testi del server.
class TripNoteRow extends StatelessWidget {
  const TripNoteRow({super.key, required this.note});

  final AiTripNote note;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: context.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: context.iconSizeSm,
            color: cs.onSurfaceVariant,
          ),
          SizedBox(width: context.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.title, style: tt.bodyLarge?.strong),
                SizedBox(height: context.spacingXxs),
                Text(
                  note.why,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

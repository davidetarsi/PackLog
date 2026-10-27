import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Indicatore dei passi di un flusso lineare: "1 Viaggio — 2 Valigia".
///
/// I passi già fatti mostrano una spunta su cerchio pieno, il passo corrente
/// il proprio numero su cerchio pieno con l'etichetta in grassetto, i passi
/// successivi un cerchio a contorno. Tra un passo e l'altro un divisore si
/// allarga per riempire la riga.
///
/// È neutro per colore (solo `onSurface`, `outline`, `onSurfaceVariant`): il
/// campo arancio resta riservato all'azione primaria.
///
/// ```dart
/// DsSteps(labels: ['Viaggio', 'Valigia'], current: 1)
/// ```
class DsSteps extends StatelessWidget {
  /// Etichette dei passi, nell'ordine di visualizzazione.
  final List<String> labels;

  /// Indice (da zero) del passo in corso.
  final int current;

  const DsSteps({super.key, required this.labels, required this.current});

  static const double _borderWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget step(int i) {
      final active = i == current;
      final done = i < current;
      final filled = active || done;
      final label = labels[i];

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: context.responsive(22),
            height: context.responsive(22),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? cs.onSurface : null,
              border: Border.all(
                color: filled ? cs.onSurface : cs.outline,
                width: _borderWidth,
              ),
            ),
            child: done
                ? Icon(Icons.check, size: context.iconSizeSm, color: cs.surface)
                : Text(
                    '${i + 1}',
                    style: tt.labelMedium?.strong.copyWith(
                      color: active ? cs.surface : cs.onSurfaceVariant,
                    ),
                  ),
          ),
          SizedBox(width: context.spacingSm),
          Text(
            label,
            style: (active ? tt.labelLarge?.strong : tt.labelLarge)?.copyWith(
              color: active ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacingSm),
                child: Divider(color: cs.outlineVariant),
              ),
            ),
          step(i),
        ],
      ],
    );
  }
}

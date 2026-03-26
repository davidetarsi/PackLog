import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Widget riutilizzabile per regolare la quantità di un item.
/// 
/// Fornisce pulsanti +/- per incrementare e decrementare un valore intero.
/// Supporta limiti minimi e massimi opzionali.
/// 
/// Esempio:
/// ```dart
/// QuantityStepper(
///   value: 3,
///   onChanged: (newValue) => setState(() => quantity = newValue),
///   minValue: 1,
///   maxValue: 10,
/// )
/// ```
class QuantityStepper extends StatelessWidget {
  /// Valore corrente della quantità
  final int value;

  /// Callback chiamato quando la quantità cambia
  final ValueChanged<int> onChanged;

  /// Valore minimo (default: 1)
  final int minValue;

  /// Valore massimo opzionale (null = nessun limite)
  final int? maxValue;

  /// Dimensione dell'icona (default: 24)
  final double? iconSize;

  /// Stile del testo per il valore
  final TextStyle? valueTextStyle;

  /// Larghezza minima del contenitore del valore (per allineamento)
  final double? minValueWidth;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.minValue = 1,
    this.maxValue,
    this.iconSize,
    this.valueTextStyle,
    this.minValueWidth,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconSize = iconSize ?? context.responsive(24);
    final effectiveMinWidth = minValueWidth ?? context.responsive(32);

    final canDecrement = value > minValue;
    final canIncrement = maxValue == null || value < maxValue!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: canDecrement ? () => onChanged(value - 1) : null,
          iconSize: effectiveIconSize,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        ),
        SizedBox(width: context.spacingXs),
        Container(
          constraints: BoxConstraints(minWidth: effectiveMinWidth),
          alignment: Alignment.center,
          child: Text(
            value.toString(),
            style: valueTextStyle ??
                Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
          ),
        ),
        SizedBox(width: context.spacingXs),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: canIncrement ? () => onChanged(value + 1) : null,
          iconSize: effectiveIconSize,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Badge per mostrare la quantità di un item.
/// Può mostrare:
/// - "xN" per quantità semplice
/// - "xN/M" per quantità parziale (N selezionati su M totali)
class QuantityBadge extends StatelessWidget {
  /// Quantità da mostrare
  final int quantity;

  /// Quantità totale (se diversa da quantity, mostra "xN/M")
  final int? totalQuantity;

  /// Se true, usa lo stile selezionato (colore primario)
  final bool isSelected;

  /// Callback opzionale per il tap
  final VoidCallback? onTap;

  /// Dimensione del font (default: 12)
  final double fontSize;

  const QuantityBadge({
    super.key,
    required this.quantity,
    this.totalQuantity,
    this.isSelected = false,
    this.onTap,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Determina il testo da mostrare
    final showPartial =
        totalQuantity != null && quantity > 0 && quantity < totalQuantity!;
    final text = showPartial ? 'x$quantity/$totalQuantity' : 'x$quantity';

    final widget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: isSelected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: widget,
      );
    }

    return widget;
  }
}

/// Badge quantità per item in viaggio (stile arancione)
class OnTripQuantityBadge extends StatelessWidget {
  final int quantity;
  final int? totalQuantity;

  const OnTripQuantityBadge({
    super.key,
    required this.quantity,
    this.totalQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final showPartial = totalQuantity != null && quantity < totalQuantity!;
    final text = showPartial ? 'x$quantity/$totalQuantity' : 'x$quantity';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.itemOnTripLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        showPartial ? '$text in viaggio' : 'In viaggio',
        style: const TextStyle(
          color: AppColors.itemOnTripDark,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// Badge "In viaggio" pieno
class OnTripBadge extends StatelessWidget {
  const OnTripBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.itemOnTrip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'In viaggio',
        style: TextStyle(color: AppColors.onColored, fontSize: 14),
      ),
    );
  }
}

/// Badge "Temporaneo" per item in arrivo
class TemporaryBadge extends StatelessWidget {
  const TemporaryBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.itemTemporary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Temporaneo',
        style: TextStyle(color: AppColors.onColored, fontSize: 10),
      ),
    );
  }
}


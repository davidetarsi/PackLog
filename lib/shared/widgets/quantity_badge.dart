import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../constants/app_constants.dart';

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

    final showPartial =
        totalQuantity != null && quantity > 0 && quantity < totalQuantity!;
    final text = showPartial ? 'x$quantity/$totalQuantity' : 'x$quantity';

    final widget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppConstants.badgeBorderRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600, // 12px badge → w600
          color: isSelected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: widget);
    }

    return widget;
  }
}

/// Badge quantità per item in viaggio (stile amber — colorScheme.tertiary).
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
    final colorScheme = Theme.of(context).colorScheme;
    final showPartial = totalQuantity != null && quantity < totalQuantity!;
    final text = showPartial ? 'x$quantity/$totalQuantity' : 'x$quantity';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
      ),
      child: Text(
        showPartial
            ? '$text ${'common.in_transit'.tr().toLowerCase()}'
            : 'common.in_transit'.tr(),
        style: TextStyle(
          color: colorScheme.onTertiaryContainer,
          fontSize: context.fontSizeXxs,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Badge "In viaggio" pieno — usa tertiary del ColorScheme.
class OnTripBadge extends StatelessWidget {
  const OnTripBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.tertiary,
        borderRadius: BorderRadius.circular(AppConstants.badgeBorderRadius),
      ),
      child: Text(
        'common.in_transit'.tr(),
        style: TextStyle(
          color: colorScheme.onTertiary,
          fontSize: context.fontSizeXxs,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Badge "Temporaneo" per item in arrivo — usa itemTemporary da AppColorsExtension.
class TemporaryBadge extends StatelessWidget {
  const TemporaryBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: appColors.itemTemporaryBackground,
        borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
      ),
      child: Text(
        'common.temporary'.tr(),
        style: TextStyle(
          color: appColors.itemTemporaryText,
          fontSize: context.fontSizeXxs,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

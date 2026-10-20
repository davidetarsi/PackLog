import 'package:flutter/material.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/surface_colors.dart';

OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
  borderSide: BorderSide(color: color, width: width),
);

/// Decorazione dei campi del viaggio: la meta, la tappa e le date.
///
/// È l'unica fonte dell'altezza dei campi: il campo di ricerca e il riquadro
/// delle date ([TripFieldBox]) la usano entrambi, quindi sono alti uguale.
/// L'altezza viene dal padding verticale `spacingMd` attorno al contenuto.
InputDecoration tripFieldDecoration(
  BuildContext context, {
  bool hasError = false,
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: context.groupSurface,
    contentPadding: EdgeInsets.symmetric(
      horizontal: context.spacingMd,
      vertical: context.spacingMd,
    ),
    border: _border(cs.outlineVariant, 1),
    enabledBorder: _border(
      hasError ? cs.error : cs.outlineVariant,
      hasError ? 1.5 : 1,
    ),
    focusedBorder: _border(hasError ? cs.error : cs.onSurface, 1.5),
  );
}

/// Riquadro di un campo compilato, sulla superficie dei gruppi, alto come il
/// campo di ricerca perché ne condivide la [tripFieldDecoration]. Con
/// [hasError] il bordo è del colore di errore.
class TripFieldBox extends StatelessWidget {
  const TripFieldBox({
    super.key,
    required this.icon,
    required this.child,
    this.suffixIcon,
    this.hasError = false,
    this.onTap,
  });

  /// Icona a sinistra, nella stessa posizione di quella del campo di ricerca.
  final IconData icon;

  /// Il valore mostrato.
  final Widget child;

  /// Azione a destra, come la "x" che toglie la meta.
  final Widget? suffixIcon;

  final bool hasError;

  /// Il tocco sta dentro la superficie, così il ripple si vede sul campo.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final decoration = tripFieldDecoration(
      context,
      prefixIcon: Icon(
        icon,
        size: context.iconSizeMd,
        color: cs.onSurfaceVariant,
      ),
      suffixIcon: suffixIcon,
    );

    return Material(
      color: context.groupSurface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
        side: BorderSide(
          color: hasError ? cs.error : cs.outlineVariant,
          width: hasError ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        // Superficie e bordo li disegna il Material: qui serve solo la
        // geometria del campo, e il ripple deve restare visibile sopra.
        child: InputDecorator(
          decoration: decoration.copyWith(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          child: child,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Un widget di layout primitivo che organizza i figli in tre slot:
/// [left] e [right] hanno larghezza fissa (56px), mentre [center] occupa
/// tutto lo spazio rimanente.
class TriSlotBar extends StatelessWidget {
  final Widget center;
  final Widget? left;
  final Widget? right;
  final double? horizontalPadding;
  final double sideSlotWidth;

  const TriSlotBar({
    super.key,
    required this.center,
    this.left,
    this.right,
    this.horizontalPadding,
    this.sideSlotWidth = 56.0,
  });

  @override
  Widget build(BuildContext context) {
    final hPadding = horizontalPadding ?? context.spacingMd;
     // Larghezza fissa per slot laterali

    // Se non ci sono azioni laterali, restituiamo solo il centro per efficienza
    if (left == null && right == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: hPadding),
        child: center,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Slot Sinistro
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: sideSlotWidth,
            child: left ?? const SizedBox.shrink(),
          ),
          
          SizedBox(width: context.spacingSm),

          // Slot Centrale (Flessibile)
          Expanded(child: center),

          SizedBox(width: context.spacingSm),

          // Slot Destro
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: sideSlotWidth,
            child: right ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
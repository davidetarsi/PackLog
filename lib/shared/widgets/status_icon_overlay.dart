import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../constants/app_constants.dart';

/// Overlay posizionato sopra un'icona per indicare uno stato dell'item.
/// Usato per mostrare l'icona "luggage" (in viaggio) o "flight_land" (in arrivo).
class StatusIconOverlay extends StatelessWidget {
  /// Icona da mostrare nell'overlay
  final IconData icon;

  /// Colore di sfondo
  final Color backgroundColor;

  /// Colore dell'icona (default: bianco)
  final Color iconColor;

  /// Dimensione dell'icona (default: 12)
  final double iconSize;

  const StatusIconOverlay({
    super.key,
    required this.icon,
    required this.backgroundColor,
    this.iconColor = Colors.white,
    this.iconSize = 12,
  });

  /// Overlay per item in viaggio.
  /// Usa colorScheme.tertiary (amber) — tema-aware.
  static StatusIconOverlay onTrip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StatusIconOverlay(
      icon: Icons.luggage,
      backgroundColor: cs.tertiaryContainer,
      iconColor: cs.onTertiaryContainer,
    );
  }

  /// Overlay per item temporaneo (in arrivo).
  /// Usa AppColorsExtension.itemTemporary — tema-aware.
  static StatusIconOverlay temporary(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!;
    return StatusIconOverlay(
      icon: Icons.flight_land,
      backgroundColor: appColors.itemTemporaryBackground,
      iconColor: appColors.itemTemporaryText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -4,
      bottom: -4,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppConstants.badgeBorderRadius),
        ),
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../constants/app_constants.dart';

/// Overlay da posizionare sopra un'icona per indicare uno stato.
/// Usato per mostrare l'icona "luggage" o "flight_land" sulle icone degli item.
class StatusIconOverlay extends StatelessWidget {
  /// Icona da mostrare nell'overlay
  final IconData icon;

  /// Colore di sfondo
  final Color backgroundColor;

  /// Colore dell'icona
  final Color iconColor;

  /// Dimensione dell'icona (default: 12)
  final double iconSize;

  const StatusIconOverlay({
    super.key,
    required this.icon,
    required this.backgroundColor,
    this.iconColor = AppColors.onColored,
    this.iconSize = 12,
  });

  /// Overlay per item in viaggio
  factory StatusIconOverlay.onTrip() {
    return const StatusIconOverlay(
      icon: Icons.luggage,
      backgroundColor: AppColors.itemOnTrip,
    );
  }

  /// Overlay per item temporaneo (in arrivo)
  factory StatusIconOverlay.temporary() {
    return const StatusIconOverlay(
      icon: Icons.flight_land,
      backgroundColor: AppColors.itemTemporary,
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
        child: Icon(
          icon,
          size: iconSize,
          color: iconColor,
        ),
      ),
    );
  }
}


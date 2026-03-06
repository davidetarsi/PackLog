import 'package:flutter/material.dart';

/// Widget standardizzato per l'handle superiore dei bottom sheet.
/// 
/// Mostra una barra orizzontale grigia che indica che il bottom sheet
/// può essere trascinato.
/// 
/// Esempio:
/// ```dart
/// Column(
///   children: [
///     DsBottomSheetHandle(),
///     // ... resto del contenuto
///   ],
/// )
/// ```
class BottomSheetHandle extends StatelessWidget {
  /// Larghezza della barra (default: 40)
  final double width;
  
  /// Altezza della barra (default: 4)
  final double height;
  
  /// Margine superiore (default: 12)
  final double topMargin;
  
  /// Colore personalizzato (se null, usa il colore del theme)
  final Color? color;

  const BottomSheetHandle({
    super.key,
    this.width = 40,
    this.height = 4,
    this.topMargin = 12,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: EdgeInsets.only(top: topMargin),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

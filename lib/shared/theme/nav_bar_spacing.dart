import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'app_spacing.dart';

/// Extension che espone il padding bottom derivato dinamicamente dalla tab bar.
///
/// Sostituisce AppConstants.floatingNavBarPadding (80.0 statico) con un valore
/// calcolato per device: tabBarHeight + safe area + respiro visivo (lg=24).
///
/// Uso:
/// ```dart
/// padding: EdgeInsets.only(bottom: context.navBarReservedHeight),
/// ```
extension NavBarSpacing on BuildContext {
  /// Spazio totale riservato dalla floating navigation bar in fondo allo schermo.
  ///
  /// Composizione:
  /// - AppConstants.tabBarHeight  → altezza visiva della tab bar (56px)
  /// - MediaQuery.paddingOf.bottom → safe area hardware (gesture bar / home indicator)
  /// - AppSpacing.lg (24px)       → respiro visivo tra ultimo elemento e tab bar
  double get navBarReservedHeight =>
      AppConstants.tabBarHeight +
      MediaQuery.paddingOf(this).bottom +
      AppSpacing.lg;
}

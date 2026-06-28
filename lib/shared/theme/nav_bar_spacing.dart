import 'package:flutter/material.dart';
import 'app_spacing.dart';

/// Extension che espone il padding bottom derivato dinamicamente dalla tab bar.
///
/// Uso:
/// ```dart
/// padding: EdgeInsets.only(bottom: context.navBarReservedHeight),
/// ```
extension NavBarSpacing on BuildContext {
  /// Spazio totale riservato dalla floating navigation bar in fondo allo schermo.
  ///
  /// Composizione (specchia la geometria di [MainShell.bottomNavigationBar]):
  /// - MediaQuery.paddingOf.bottom → safe area hardware (gesture bar / home indicator)
  /// - spacingMd (16px responsive)  → padding sotto la pill, tra gesture bar e pill bottom
  /// - responsive(56.0)             → altezza visiva della pill (identica a MainShell)
  /// - spacingLg (24px responsive)  → respiro visivo tra ultimo elemento e pill top
  ///                                   (~20px su schermi piccoli, ~24px su schermo base)
  double get navBarReservedHeight => MediaQuery.paddingOf(this).bottom;
  //+ spacingSm;
  //+ responsive(56.0)
  //+ spacingLg;
}

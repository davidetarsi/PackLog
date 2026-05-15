import 'package:flutter/material.dart';

/// AppBar animata che transita tra una modalità **normale** e una
/// **contestuale** (es. selezione multipla item).
///
/// Estratta da [HouseDetailScreen] per essere riusabile in qualsiasi
/// schermata con selezione multipla (es. futura `TripDetailScreen`).
///
/// ```dart
/// DsContextualAppBar(
///   normalAppBar: AppBar(title: Text('Casa')),
///   selectionAppBar: AppBar(title: Text('3 selezionati')),
///   isInSelectionMode: _isSelecting,
/// )
/// ```
///
/// Deve essere usato nel parametro `appBar` di [Scaffold].
/// Wrappato automaticamente in [PreferredSize] per soddisfare l'interfaccia
/// [PreferredSizeWidget] richiesta da [Scaffold.appBar].
class DsContextualAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// AppBar mostrata in modalità normale.
  final PreferredSizeWidget normalAppBar;

  /// AppBar mostrata in modalità selezione.
  final PreferredSizeWidget selectionAppBar;

  /// Quando `true`, mostra [selectionAppBar]; altrimenti [normalAppBar].
  final bool isInSelectionMode;

  /// Durata della transizione di dissolvenza (default: 220ms).
  final Duration switchDuration;

  const DsContextualAppBar({
    super.key,
    required this.normalAppBar,
    required this.selectionAppBar,
    required this.isInSelectionMode,
    this.switchDuration = const Duration(milliseconds: 220),
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: AnimatedSwitcher(
        duration: switchDuration,
        // Dissolvenza semplice: evita jank da slide sulle AppBar.
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: isInSelectionMode ? selectionAppBar : normalAppBar,
      ),
    );
  }
}

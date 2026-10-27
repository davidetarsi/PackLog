import 'package:flutter/material.dart';

/// Colori di superficie che non stanno in [ColorScheme] così come sono.
extension SurfaceColors on BuildContext {
  /// Sfondo dei gruppi, delle carte e della barra di navigazione. In chiaro
  /// bianco sulla pagina grigia; in
  /// scuro un grigio più chiaro della pagina, come i gruppi di Revolut.
  Color get groupSurface {
    final theme = Theme.of(this);
    return theme.brightness == Brightness.light
        ? theme.colorScheme.surfaceContainerLowest
        : theme.colorScheme.surfaceContainer;
  }
}

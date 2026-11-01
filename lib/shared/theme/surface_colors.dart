import 'package:flutter/material.dart';

/// I livelli di superficie dell'app, dal più basso al più alto.
///
/// | livello            | cosa è                              | chiaro               | scuro                    |
/// |--------------------|-------------------------------------|----------------------|--------------------------|
/// | [pageSurface]      | fondo della pagina                  | grigio chiaro        | grigio scuro             |
/// | [raisedSurface]    | superficie 1: card, gruppi, fogli   | bianco               | un po' più chiaro        |
/// | [nestedSurface]    | superficie 2: card e campi in un foglio | grigio appena più scuro del foglio | ancora più chiaro |
///
/// In scuro ogni livello è più chiaro del precedente; in chiaro i fogli sono
/// bianchi sul fondo grigio e ciò che sta dentro un foglio è un grigio appena
/// più scuro, perché il bianco non si può alzare oltre.
///
/// I componenti condivisi non scelgono il livello: usano [groupSurface], che
/// per ogni componente è "un gradino sopra ciò che ha dietro", e
/// [groundSurface], ciò che c'è dietro. Dentro un foglio ([SheetSurfaceScope],
/// messo da `DsFormSheet`) il fondo è la superficie 1 e i gruppi sono la 2.
extension SurfaceColors on BuildContext {
  /// Livello 0: il fondo della pagina.
  Color get pageSurface => Theme.of(this).colorScheme.surface;

  /// Livello 1: card, gruppi, barre e fogli.
  Color get raisedSurface {
    final theme = Theme.of(this);
    return theme.brightness == Brightness.light
        ? theme.colorScheme.surfaceContainerLowest
        : theme.colorScheme.surfaceContainer;
  }

  /// Livello 2: card e campi dentro un foglio.
  Color get nestedSurface {
    final theme = Theme.of(this);
    return theme.brightness == Brightness.light
        ? theme.colorScheme.surfaceContainer
        : theme.colorScheme.surfaceContainerHigh;
  }

  /// `true` dentro un foglio (`DsFormSheet`).
  bool get isInSheet => SheetSurfaceScope.of(this);

  /// Ciò che sta dietro ai contenuti: la pagina, o il foglio.
  Color get groundSurface => isInSheet ? raisedSurface : pageSurface;

  /// Sfondo di gruppi, card, campi e barre: un gradino sopra
  /// [groundSurface]. Sulla pagina è la superficie 1, in un foglio la 2.
  Color get groupSurface => isInSheet ? nestedSurface : raisedSurface;
}

/// Dice ai discendenti che stanno dentro un foglio: card e campi prendono la
/// superficie 2 invece della 1, così si staccano dal foglio.
class SheetSurfaceScope extends InheritedWidget {
  const SheetSurfaceScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SheetSurfaceScope>() != null;

  @override
  bool updateShouldNotify(SheetSurfaceScope oldWidget) => false;
}

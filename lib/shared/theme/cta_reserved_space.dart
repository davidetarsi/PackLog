import 'package:flutter/widgets.dart';

/// Espone ai discendenti di `body` in [StickyCtaScaffold] lo spazio da
/// riservare in fondo alle proprie scrollable, così l'ultimo elemento di una
/// lista può essere scrollato sopra la CTA flottante invece di restare
/// perennemente coperto (e quindi non cliccabile) sotto di essa.
///
/// Uso:
/// ```dart
/// padding: EdgeInsets.all(context.spacingMd).copyWith(
///   bottom: context.spacingMd + context.ctaReservedHeight,
/// ),
/// ```
///
/// Se non esiste una [StickyCtaScaffold] antenata (o non ha `bottomContent`),
/// il valore di default è `0` — nessun comportamento da gestire esplicitamente.
class CtaReservedSpaceScope extends InheritedWidget {
  final double height;

  const CtaReservedSpaceScope({
    super.key,
    required this.height,
    required super.child,
  });

  static double of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<CtaReservedSpaceScope>();
    return scope?.height ?? 0;
  }

  @override
  bool updateShouldNotify(CtaReservedSpaceScope oldWidget) =>
      height != oldWidget.height;
}

extension CtaReservedSpaceX on BuildContext {
  double get ctaReservedHeight => CtaReservedSpaceScope.of(this);
}

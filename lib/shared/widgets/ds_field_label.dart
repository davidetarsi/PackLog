import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Etichetta di un campo in un foglio ("Nome", "Categoria", "Dettagli"):
/// piccola e secondaria, così il titolo del foglio resta l'unico in grande.
/// Per le domande che occupano una pagina ("Dove vai?") c'è DsSectionTitle.
///
/// La variante [DsFieldLabel.prominent] è un titolo di sezione dentro il foglio
/// (es. "Dettagli"), più evidente e con più spazio sopra.
class DsFieldLabel extends StatelessWidget {
  const DsFieldLabel(this.text, {super.key}) : _prominent = false;

  const DsFieldLabel.prominent(this.text, {super.key}) : _prominent = true;

  final String text;
  final bool _prominent;

  /// Lo stile dell'etichetta, per chi la mette sulla stessa riga del suo
  /// controllo.
  static TextStyle? textStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .labelLarge
      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

  /// Lo stile della variante evidente.
  static TextStyle? prominentStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .titleMedium
      ?.copyWith(color: Theme.of(context).colorScheme.onSurface);

  @override
  Widget build(BuildContext context) {
    if (_prominent) {
      return Padding(
        padding: EdgeInsets.only(
          top: context.spacingLg,
          bottom: context.spacingXs,
        ),
        child: Text(text, style: prominentStyle(context)),
      );
    }
    return Padding(
      padding: EdgeInsets.only(
        top: context.spacingMd,
        bottom: context.spacingXs,
      ),
      child: Text(text, style: textStyle(context)),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Etichetta di un campo in un foglio ("Nome", "Categoria", "Dettagli"):
/// piccola e secondaria, così il titolo del foglio resta l'unico in grande.
/// Per le domande che occupano una pagina ("Dove vai?") c'è DsSectionTitle.
class DsFieldLabel extends StatelessWidget {
  const DsFieldLabel(this.text, {super.key});

  final String text;

  /// Lo stile dell'etichetta, per chi la mette sulla stessa riga del suo
  /// controllo.
  static TextStyle? textStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .labelLarge
      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: context.spacingMd,
        bottom: context.spacingXs,
      ),
      child: Text(text, style: textStyle(context)),
    );
  }
}

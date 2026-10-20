import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Titolo di sezione di pagine e fogli con dei campi, in grande e grassetto
/// ("Dove vai?", "Cosa porti", "Categoria"). Lo usano il nuovo viaggio, il
/// foglio della tappa, la pagina valigia e la scheda oggetto, così i titoli
/// hanno sempre lo stesso aspetto.
class DsSectionTitle extends StatelessWidget {
  const DsSectionTitle(this.text, {super.key});

  final String text;

  /// Lo stile del titolo, per chi mette l'etichetta sulla stessa riga del suo
  /// controllo.
  static TextStyle? textStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: context.spacingLg,
        bottom: context.spacingSm,
      ),
      child: Text(text, style: textStyle(context)),
    );
  }
}

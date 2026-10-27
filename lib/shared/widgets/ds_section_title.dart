import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Titolo di sezione di pagine e fogli con dei campi, in grande e grassetto
/// ("Dove vai?", "Cosa porti"). Lo usano il nuovo viaggio e la pagina valigia,
/// così i titoli hanno sempre lo stesso aspetto.
/// Per le sezioni dentro un foglio c'è DsFieldLabel.prominent.
class DsSectionTitle extends StatelessWidget {
  const DsSectionTitle(this.text, {super.key});

  final String text;

  /// Lo stile del titolo, per chi mette l'etichetta sulla stessa riga del suo
  /// controllo.
  static TextStyle? textStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge?.title;

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

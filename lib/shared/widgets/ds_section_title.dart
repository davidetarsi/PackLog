import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Titolo di sezione di pagine e fogli con dei campi, in grande e grassetto
/// ("Dove vai?", "Cosa porti"). Lo usano il nuovo viaggio e la pagina valigia,
/// così i titoli hanno sempre lo stesso aspetto.
/// Per le sezioni dentro un foglio c'è DsFieldLabel.prominent.
class DsSectionTitle extends StatelessWidget {
  const DsSectionTitle(this.text, {super.key, this.isRequired = false});

  final String text;

  /// Campo obbligatorio: un asterisco dopo il titolo, e "obbligatorio" per
  /// chi usa un lettore di schermo.
  final bool isRequired;

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
      child: isRequired
          ? Semantics(
              label: '$text, ${'common.required'.tr()}',
              excludeSemantics: true,
              child: Text('$text *', style: textStyle(context)),
            )
          : Text(text, style: textStyle(context)),
    );
  }
}

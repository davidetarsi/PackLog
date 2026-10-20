import 'package:flutter/material.dart';

import '../../../../shared/theme/app_spacing.dart';

/// Titolo di sezione dei flussi del viaggio: una domanda in grande e grassetto
/// ("Dove vai?", "Quando?", "Cosa porti"). Lo usano il passo 1, il foglio della
/// tappa e la pagina valigia, così le domande hanno sempre lo stesso aspetto.
class TripSectionTitle extends StatelessWidget {
  const TripSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: context.spacingLg,
        bottom: context.spacingSm,
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

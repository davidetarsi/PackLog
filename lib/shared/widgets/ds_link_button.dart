import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Link testuale con la freccia a destra: la strada secondaria accanto a
/// una CTA (es. "Non sono vestiti? Scrivili a mano →" sotto "Scansiona con
/// AI"). Lo usano il foglio Crea e il template dello stato vuoto.
///
/// Colore del testo, non arancione: accanto c'è sempre la CTA, che resta
/// l'unica cosa colorata; la freccia basta a dire che si tocca.
class DsLinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const DsLinkButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      onPressed: onPressed,
      icon: Icon(Icons.arrow_forward, size: context.iconSizeSm),
      iconAlignment: IconAlignment.end,
      label: Text(label),
    );
  }
}

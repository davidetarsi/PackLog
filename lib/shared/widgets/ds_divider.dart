import 'package:flutter/material.dart';

/// Linea di separazione del design system: l'unico modo di scrivere `Divider`
/// nell'app. Altezza 1, spessore 1 e colore `outlineVariant`, come il tema.
///
/// [indent] e [endIndent] rientrano la linea dai due lati, per le righe di un
/// gruppo che non arrivano al bordo.
class DsDivider extends StatelessWidget {
  final double indent;
  final double endIndent;

  const DsDivider({super.key, this.indent = 0, this.endIndent = 0});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
      indent: indent,
      endIndent: endIndent,
    );
  }
}

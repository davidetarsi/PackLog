import 'package:flutter/material.dart';

/// Casella e interruttore del design system. Sono gli unici modi di scrivere
/// `Checkbox` e `Switch` nell'app.
///
/// Il colore viene dal `checkboxTheme` e dallo `switchTheme` del tema: qui si
/// fissano solo il tocco minimo di 48 e la semantica.
class DsCheckbox extends StatelessWidget {
  final bool value;

  /// `null` spegne la casella.
  final ValueChanged<bool>? onChanged;

  /// Nome letto dagli screen reader.
  final String? semanticLabel;

  const DsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    // `Checkbox` passa un `bool?` che qui non può essere null: il valore è
    // sempre `true` o `false`.
    final callback = onChanged;
    return Checkbox(
      value: value,
      onChanged: callback == null ? null : (v) => callback(v ?? false),
      semanticLabel: semanticLabel,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

/// Interruttore del design system, con il tocco minimo di 48 e i colori del
/// `switchTheme`. `null` in [onChanged] lo spegne.
class DsSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const DsSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

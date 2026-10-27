import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import '../theme/surface_colors.dart';

OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
  borderSide: BorderSide(color: color, width: width),
);

/// Decorazione dei campi di testo dei fogli e delle pagine con un modulo: la
/// meta, la tappa, le date, il nome e la nota di un oggetto.
///
/// È l'unica fonte dell'altezza dei campi: il campo di ricerca e il riquadro
/// delle date ([DsFieldBox]) la usano entrambi, quindi sono alti uguale.
/// L'altezza viene dal padding verticale `spacingMd` attorno al contenuto.
///
/// Utenti: [DsTextField], DsSearchField, [DsFieldBox].
InputDecoration dsFieldDecoration(
  BuildContext context, {
  bool hasError = false,
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: context.groupSurface,
    contentPadding: EdgeInsets.symmetric(
      horizontal: context.spacingMd,
      vertical: context.spacingMd,
    ),
    border: _border(cs.outlineVariant, 1),
    enabledBorder: _border(
      hasError ? cs.error : cs.outlineVariant,
      hasError ? 1.5 : 1,
    ),
    focusedBorder: _border(hasError ? cs.error : cs.onSurface, 1.5),
    errorBorder: _border(cs.error, 1.5),
    focusedErrorBorder: _border(cs.error, 1.5),
    helperMaxLines: 3,
    errorMaxLines: 3,
  );
}

/// Il campo di testo dei moduli: un [TextFormField] con l'aspetto di
/// [dsFieldDecoration], l'aiuto e l'errore sotto il campo.
///
/// [maxLength] ferma la scrittura al limite e non mostra il contatore.
class DsTextField extends StatelessWidget {
  const DsTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.prefixIcon,
    this.suffixText,
    this.helperText,
    this.errorText,
    this.validator,
    this.autovalidateMode,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.autocorrect = true,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;

  /// Icona a sinistra, nella stessa posizione di quella del campo di ricerca.
  final IconData? prefixIcon;

  /// Testo a destra del campo, per esempio la "L" dei litri.
  final String? suffixText;

  /// Aiuto sotto il campo.
  final String? helperText;

  /// Errore sotto il campo, con il bordo del colore di errore.
  final String? errorText;

  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool autocorrect;
  final int? minLines;
  final int? maxLines;

  /// Limite di caratteri: la scrittura si ferma lì, senza contatore.
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = prefixIcon;
    final decoration =
        dsFieldDecoration(
          context,
          hasError: errorText != null,
          hintText: hintText,
          prefixIcon: icon == null
              ? null
              : Icon(
                  icon,
                  size: context.iconSizeMd,
                  color: cs.onSurfaceVariant,
                ),
        ).copyWith(
          suffixText: suffixText,
          helperText: helperText,
          errorText: errorText,
        );

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: decoration,
      validator: validator,
      autovalidateMode: autovalidateMode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofocus: autofocus,
      autocorrect: autocorrect,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      buildCounter: _noCounter,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      enabled: enabled,
    );
  }
}

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;

/// Riquadro di un campo compilato, sulla superficie dei gruppi, alto come il
/// campo di ricerca perché ne condivide la [dsFieldDecoration]. Con
/// [hasError] il bordo è del colore di errore.
class DsFieldBox extends StatelessWidget {
  const DsFieldBox({
    super.key,
    required this.icon,
    required this.child,
    this.suffixIcon,
    this.hasError = false,
    this.onTap,
  });

  /// Icona a sinistra, nella stessa posizione di quella del campo di ricerca.
  final IconData icon;

  /// Il valore mostrato.
  final Widget child;

  /// Azione a destra, come la "x" che toglie la meta.
  final Widget? suffixIcon;

  final bool hasError;

  /// Il tocco sta dentro la superficie, così il ripple si vede sul campo.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final decoration = dsFieldDecoration(
      context,
      prefixIcon: Icon(
        icon,
        size: context.iconSizeMd,
        color: cs.onSurfaceVariant,
      ),
      suffixIcon: suffixIcon,
    );

    return Material(
      color: context.groupSurface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
        side: BorderSide(
          color: hasError ? cs.error : cs.outlineVariant,
          width: hasError ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        // Superficie e bordo li disegna il Material: qui serve solo la
        // geometria del campo, e il ripple deve restare visibile sopra.
        child: InputDecorator(
          decoration: decoration.copyWith(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          child: child,
        ),
      ),
    );
  }
}

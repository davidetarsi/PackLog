import 'package:flutter/services.dart';

/// Rende maiuscola la prima lettera di ciò che si scrive ("aux bt" diventa
/// "Aux bt"), il resto resta com'è.
///
/// `TextCapitalization.sentences` chiede la maiuscola alla tastiera, ma è
/// solo una richiesta: nei campi che restano a fuoco dopo l'invio (il rapid
/// fire della casa), con il testo incollato o con tastiere che la ignorano,
/// il nome restava minuscolo. Questo formatter la garantisce a prescindere
/// dalla tastiera.
class FirstLetterFormatter extends TextInputFormatter {
  const FirstLetterFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final index = text.indexOf(RegExp(r'\S'));
    if (index < 0) return newValue;
    final first = text.substring(index, index + 1);
    final upper = first.toUpperCase();
    // Se la maiuscola cambia la lunghezza (come "ß") il cursore si
    // sposterebbe: si lascia la lettera com'è.
    if (upper == first || upper.length != first.length) return newValue;
    return newValue.copyWith(text: text.replaceRange(index, index + 1, upper));
  }
}

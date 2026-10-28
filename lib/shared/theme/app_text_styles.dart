import 'package:flutter/material.dart';

import 'app_spacing.dart';

/// I tre pesi del testo dell'app. Fuori da questa cartella non si scrive
/// `FontWeight.` né `TextStyle(`: si parte dallo slot del tema e si chiama
/// uno di questi nomi.
extension DsWeight on TextStyle {
  /// w600: righe, etichette, bottoni.
  TextStyle get strong => copyWith(fontWeight: FontWeight.w600);

  /// w700: titoli di pagina, foglio e sezione.
  TextStyle get title => copyWith(fontWeight: FontWeight.w700);

  /// w800: solo cartoline.
  TextStyle get postcard => copyWith(fontWeight: FontWeight.w800);
}

extension DsTextRoles on TextTheme {
  /// Nome della card della casa: titleMedium a 18, w600.
  TextStyle? get cardTitle =>
      titleMedium?.copyWith(fontSize: AppSpacing.fontMd).strong;
}

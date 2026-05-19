import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'language_locale.g.dart';

@Riverpod(keepAlive: true)
class LanguageLocale extends _$LanguageLocale {
  @override
  String build() {
    // Ritorna la lingua di default iniziale. Verrà sovrascritta quasi subito dalla UI.
    return 'it';
  }

  void updateLocale(String languageCode) {
    if (state != languageCode) {
      state = languageCode;
    }
  }
}

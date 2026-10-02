import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'language_locale.g.dart';

/// Maps any language code to a supported [Locale].
/// Only Italian maps to Italian; everything else falls back to English.
Locale resolveLocale(String langCode) =>
    langCode == 'it' ? const Locale('it', 'IT') : const Locale('en', 'US');

/// Returns the device's primary language code ('it', 'en', etc.).
/// Separate provider to enable test overrides without touching WidgetsBinding.
@Riverpod(keepAlive: true)
String deviceLocale(Ref ref) {
  return WidgetsBinding.instance.platformDispatcher.locale.languageCode;
}

@Riverpod(keepAlive: true)
class LanguageLocale extends _$LanguageLocale {
  @override
  String build() {
    final langCode = ref.watch(deviceLocaleProvider);
    return resolveLocale(langCode).languageCode;
  }

  void updateLocale(String languageCode) {
    if (state != languageCode) {
      state = languageCode;
    }
  }
}

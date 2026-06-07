import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'language_locale.g.dart';

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
    return langCode == 'it' ? 'it' : 'en';
  }

  void updateLocale(String languageCode) {
    if (state != languageCode) {
      state = languageCode;
    }
  }
}

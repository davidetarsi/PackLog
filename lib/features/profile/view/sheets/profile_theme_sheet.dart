import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/ds_picker_sheet.dart';

/// Foglio dal basso per scegliere il tema (chiaro, scuro, di sistema).
///
/// Chiudere con la x o toccando fuori non cambia nulla: [onSetThemeMode] viene
/// chiamato solo per una scelta diversa da quella attuale.
Future<void> showProfileThemeSheet(
  BuildContext context, {
  required ThemeMode currentThemeMode,
  required void Function(ThemeMode) onSetThemeMode,
}) async {
  final picked = await DsPickerSheet.show<ThemeMode>(
    context: context,
    title: 'settings.theme'.tr(),
    items: const [ThemeMode.light, ThemeMode.dark, ThemeMode.system],
    getLabel: (mode) => switch (mode) {
      ThemeMode.light => 'settings.theme_light'.tr(),
      ThemeMode.dark => 'settings.theme_dark'.tr(),
      ThemeMode.system => 'settings.theme_system'.tr(),
    },
    getIcon: (mode) => switch (mode) {
      ThemeMode.light => Icons.light_mode,
      ThemeMode.dark => Icons.dark_mode,
      ThemeMode.system => Icons.brightness_auto,
    },
    selected: currentThemeMode,
  );

  if (picked == null || picked == currentThemeMode) return;
  onSetThemeMode(picked);
}

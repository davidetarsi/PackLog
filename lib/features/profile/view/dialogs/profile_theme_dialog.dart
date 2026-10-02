import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/app_spacing.dart';
import '../../widgets/theme_tile.dart';

Future<void> showProfileThemeDialog(
  BuildContext context, {
  required ThemeMode currentThemeMode,
  required void Function(ThemeMode) onSetThemeMode,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('settings.theme'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ThemeTile(
            mode: ThemeMode.light,
            title: 'settings.theme_light'.tr(),
            icon: Icons.light_mode,
            isSelected: currentThemeMode == ThemeMode.light,
            onTap: () {
              onSetThemeMode(ThemeMode.light);
              Navigator.of(dialogContext).pop();
            },
          ),
          AppSpacing.gapSm,
          ThemeTile(
            mode: ThemeMode.dark,
            title: 'settings.theme_dark'.tr(),
            icon: Icons.dark_mode,
            isSelected: currentThemeMode == ThemeMode.dark,
            onTap: () {
              onSetThemeMode(ThemeMode.dark);
              Navigator.of(dialogContext).pop();
            },
          ),
          AppSpacing.gapSm,
          ThemeTile(
            mode: ThemeMode.system,
            title: 'settings.theme_system'.tr(),
            icon: Icons.brightness_auto,
            isSelected: currentThemeMode == ThemeMode.system,
            onTap: () {
              onSetThemeMode(ThemeMode.system);
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      ),
    ),
  );
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/app_spacing.dart';
import '../../widgets/language_tile.dart';

Future<void> showProfileLanguageDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('settings.language'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LanguageTile(
            locale: const Locale('it', 'IT'),
            title: 'Italiano',
            flag: '🇮🇹',
            isSelected: context.locale == const Locale('it', 'IT'),
            onTap: () async {
              await context.setLocale(const Locale('it', 'IT'));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
          ),
          AppSpacing.gapSm,
          LanguageTile(
            locale: const Locale('en', 'US'),
            title: 'English',
            flag: '🇺🇸',
            isSelected: context.locale == const Locale('en', 'US'),
            onTap: () async {
              await context.setLocale(const Locale('en', 'US'));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
          ),
        ],
      ),
    ),
  );
}

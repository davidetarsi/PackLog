import 'package:flutter/material.dart';
import '../../../../features/profile/widgets/language_tile.dart';
import '../../../../shared/theme/app_spacing.dart';

class LanguageSlide extends StatelessWidget {
  final Locale? selectedLocale;
  final void Function(Locale) onLocaleTapped;

  const LanguageSlide({
    super.key,
    required this.selectedLocale,
    required this.onLocaleTapped,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.language, size: 80, color: colorScheme.primary),
          SizedBox(height: context.spacingLg),
          Text(
            'Scegli la tua lingua\nChoose your language',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.fontSizeLg,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.spacingLg),
          LanguageTile(
            locale: const Locale('it', 'IT'),
            title: 'Italiano',
            flag: '🇮🇹',
            isSelected: selectedLocale?.languageCode == 'it',
            onTap: () => onLocaleTapped(const Locale('it', 'IT')),
          ),
          SizedBox(height: context.spacingSm),
          LanguageTile(
            locale: const Locale('en', 'US'),
            title: 'English',
            flag: '🇬🇧',
            isSelected: selectedLocale?.languageCode == 'en',
            onTap: () => onLocaleTapped(const Locale('en', 'US')),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings.language'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageTile(
              locale: const Locale('it', 'IT'),
              title: 'Italiano',
              flag: '🇮🇹',
              isSelected: context.locale == const Locale('it', 'IT'),
              onTap: () async {
                await context.setLocale(const Locale('it', 'IT'));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
            const SizedBox(height: 8),
            _LanguageTile(
              locale: const Locale('en', 'US'),
              title: 'English',
              flag: '🇺🇸',
              isSelected: context.locale == const Locale('en', 'US'),
              onTap: () async {
                await context.setLocale(const Locale('en', 'US'));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;
    final languageName = currentLocale.languageCode == 'it' ? 'Italiano' : 'English';
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'settings.title'.tr(),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        
        // Selezione lingua
        ListTile(
          leading: const Icon(Icons.language),
          title: Text('settings.language'.tr()),
          subtitle: Text(languageName),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageDialog(context),
        ),
        const Divider(),
        
        // Informazioni
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text('settings.about'.tr()),
          subtitle: const Text('Versione 1.0.0'),
        ),
        const Divider(),
        
        // Archiviazione
        const ListTile(
          leading: Icon(Icons.storage),
          title: Text('Archiviazione'),
          subtitle: Text('Dati salvati localmente'),
        ),
      ],
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final Locale locale;
  final String title;
  final String flag;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.locale,
    required this.title,
    required this.flag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
        ),
        child: Row(
          children: [
            Text(
              flag,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? colorScheme.primary : null,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

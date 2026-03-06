import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/providers/last_export_path_provider.dart';
import '../../../core/database/controllers/backup_controller.dart';
import '../../../shared/helpers/design_system.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _showThemeDialog(BuildContext context) {
    final currentThemeMode = ref.read(themeModeNotifierProvider).valueOrNull ?? ThemeMode.dark;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings.theme'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeTile(
              mode: ThemeMode.light,
              title: 'settings.theme_light'.tr(),
              icon: Icons.light_mode,
              isSelected: currentThemeMode == ThemeMode.light,
              onTap: () {
                ref.read(themeModeNotifierProvider.notifier).setThemeMode(ThemeMode.light);
                Navigator.of(dialogContext).pop();
              },
            ),
            const SizedBox(height: 8),
            _ThemeTile(
              mode: ThemeMode.dark,
              title: 'settings.theme_dark'.tr(),
              icon: Icons.dark_mode,
              isSelected: currentThemeMode == ThemeMode.dark,
              onTap: () {
                ref.read(themeModeNotifierProvider.notifier).setThemeMode(ThemeMode.dark);
                Navigator.of(dialogContext).pop();
              },
            ),
            const SizedBox(height: 8),
            _ThemeTile(
              mode: ThemeMode.system,
              title: 'settings.theme_system'.tr(),
              icon: Icons.brightness_auto,
              isSelected: currentThemeMode == ThemeMode.system,
              onTap: () {
                ref.read(themeModeNotifierProvider.notifier).setThemeMode(ThemeMode.system);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Esporta il database e condivide il file
  Future<void> _handleExportDatabase(BuildContext context) async {
    ExportResult? exportResult;
    
    try {
      debugPrint('[SettingsScreen] 📤 Utente ha richiesto export database');
      
      // Mostra loading
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('backup.export_database'.tr()),
            ],
          ),
        ),
      );

      // Export database
      final controller = ref.read(backupControllerProvider.notifier);
      exportResult = await controller.exportToTemporaryFile();

      debugPrint('[SettingsScreen] ✅ Export database completato con successo!');
      debugPrint('[SettingsScreen] 📂 File: ${exportResult.path}');
      debugPrint('[SettingsScreen] 📊 Dimensione: ${_formatFileSize(exportResult.sizeBytes)}');

      // Salva il path dell'export per mostrarlo nell'UI
      await ref.read(lastExportPathProvider.notifier).updateLastExportPath(exportResult.path);
      debugPrint('[SettingsScreen] 💾 Path aggiornato nel provider: ${exportResult.path}');

      // Chiudi loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Tenta di condividere il file
      debugPrint('[SettingsScreen] 📤 Tentativo condivisione file...');
      
      try {
        final xFile = XFile(exportResult.path);
        await Share.shareXFiles(
          [xFile],
          subject: 'backup.export_database'.tr(),
          text: 'backup.file_size'.tr(args: [_formatFileSize(exportResult.sizeBytes)]),
        );

        debugPrint('[SettingsScreen] ✅ File condiviso con successo tramite share sheet');

        // Mostra messaggio di successo
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('backup.export_success'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (shareError) {
        // Fallback: Share non disponibile (simulatore o plugin non configurato)
        // MA l'export è RIUSCITO, quindi mostriamo successo + path
        debugPrint('[SettingsScreen] ⚠️ Share non disponibile: $shareError');
        debugPrint('[SettingsScreen] ℹ️ NOTA: Export riuscito, solo la condivisione non disponibile');
        debugPrint('[SettingsScreen] 💡 Mostro dialog con path del file');
        
        // A questo punto exportResult è garantito non-null (export è riuscito)
        final result = exportResult;
        
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text('backup.export_success'.tr())),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('backup.file_size'.tr(args: [_formatFileSize(result.sizeBytes)])),
                  const SizedBox(height: 16),
                  Text(
                    'backup.file_saved_in'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      result.path,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '💡 ${'backup.share_unavailable_note'.tr()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('common.close'.tr()),
                ),
              ],
            ),
          );
        }
        
        // NON mostriamo errore perché l'export è RIUSCITO
        return;
      }
    } catch (e, stack) {
      // Questo catch gestisce SOLO fallimenti dell'export stesso
      debugPrint('[SettingsScreen] ❌ Export del database fallito: $e');
      debugPrint('[SettingsScreen] Stack trace: $stack');
      
      // Chiudi loading dialog se aperto
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Dialog già chiuso
        }
      }

      // Mostra errore SOLO se l'export è fallito (non se ha fallito solo la share)
      if (exportResult == null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('backup.export_failed'.tr()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Importa il database da un file selezionato dall'utente
  Future<void> _handleImportDatabase(BuildContext context) async {
    try {
      debugPrint('[SettingsScreen] 📥 Utente ha richiesto import database');

      // Step 1: Mostra warning dialog
      final confirmed = await DialogHelpers.showConfirmation(
        context: context,
        title: 'backup.import_warning_title'.tr(),
        message: 'backup.import_warning_message'.tr(),
        isDestructive: true,
      );

      if (confirmed != true) {
        debugPrint('[SettingsScreen] ❌ Import annullato dall\'utente');
        return;
      }

      // Step 2: Seleziona file
      debugPrint('[SettingsScreen] 📂 Apertura file picker...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('[SettingsScreen] ❌ Nessun file selezionato');
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        debugPrint('[SettingsScreen] ❌ Path file non disponibile');
        return;
      }

      debugPrint('[SettingsScreen] 📂 File selezionato: $filePath');

      // Step 3: Valida nome file
      final controller = ref.read(backupControllerProvider.notifier);
      if (!controller.validateImportFileName(filePath)) {
        debugPrint('[SettingsScreen] ❌ Nome file non valido');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('backup.import_validation_failed'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Step 4: Mostra loading
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('backup.importing_data'.tr()),
            ],
          ),
        ),
      );

      // Step 5: Import database (con disaster recovery)
      debugPrint('[SettingsScreen] 🚀 Avvio import con disaster recovery...');
      final importResult = await controller.importDatabase(filePath);

      // Chiudi loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Step 6: Mostra risultato
      if (context.mounted) {
        if (importResult.success) {
          debugPrint('[SettingsScreen] ✅ Import completato con successo');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('backup.import_success'.tr())),
          );
        } else {
          debugPrint('[SettingsScreen] ❌ Import fallito: ${importResult.errorMessage}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult.errorMessage ?? 'backup.import_failed'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[SettingsScreen] ❌ Errore critico durante import: $e');
      
      // Chiudi loading dialog se aperto
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('backup.critical_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Formatta la dimensione del file in modo leggibile
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

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
              title: 'Italiano', // Language names should not be translated
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
              title: 'English', // Language names should not be translated
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
    
    final themeModeAsync = ref.watch(themeModeNotifierProvider);
    final themeModeName = themeModeAsync.when(
      data: (mode) {
        switch (mode) {
          case ThemeMode.light:
            return 'settings.theme_light'.tr();
          case ThemeMode.dark:
            return 'settings.theme_dark'.tr();
          case ThemeMode.system:
            return 'settings.theme_system'.tr();
        }
      },
      loading: () => 'common.loading'.tr(),
      error: (error, stack) => 'settings.theme_dark'.tr(),
    );
    
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
        
        // Selezione tema
        ListTile(
          leading: Icon(
            themeModeAsync.valueOrNull == ThemeMode.light 
                ? Icons.light_mode 
                : themeModeAsync.valueOrNull == ThemeMode.dark
                    ? Icons.dark_mode
                    : Icons.brightness_auto,
          ),
          title: Text('settings.theme'.tr()),
          subtitle: Text(themeModeName),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showThemeDialog(context),
        ),
        const Divider(),
        
        // Sezione Backup & Restore
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'backup.title'.tr(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        
        // Export Database
        Consumer(
          builder: (context, ref, _) {
            final exportPathAsync = ref.watch(lastExportPathProvider);
            final displayPath = exportPathAsync.valueOrNull ?? '...';
            
            return ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text('backup.export_database'.tr()),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('backup.export_subtitle'.tr()),
                  const SizedBox(height: 8),
                  Text(
                    'backup.path_label'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    displayPath,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _handleExportDatabase(context),
            );
          },
        ),
        
        // Import Database
        ListTile(
          leading: const Icon(Icons.download),
          title: Text('backup.import_database'.tr()),
          subtitle: Text('backup.import_subtitle'.tr()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _handleImportDatabase(context),
        ),
        
        const Divider(),
        
        // Informazioni
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text('settings.about'.tr()),
          subtitle: Text('${'common.version'.tr()} 1.0.0'),
        ),
        const Divider(),
        
        // Archiviazione
        ListTile(
          leading: const Icon(Icons.storage),
          title: Text('common.storage'.tr()),
          subtitle: Text('common.data_saved_locally'.tr()),
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

class _ThemeTile extends StatelessWidget {
  final ThemeMode mode;
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.mode,
    required this.title,
    required this.icon,
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
            Icon(
              icon,
              size: 32,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6),
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

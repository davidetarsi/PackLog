import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/providers/last_export_path_provider.dart';
import '../../../core/database/controllers/backup_controller.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/constants/app_constants.dart';

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

  /// Esporta il database e salva il file nella cartella Download del dispositivo.
  ///
  /// Il file viene scritto direttamente su disco (nessun dialog di share).
  /// Al termine mostra una [AppSnackBar] con il nome del file salvato e
  /// aggiorna il path visibile nella UI tramite [lastExportPathProvider].
  Future<void> _handleExportDatabase(BuildContext context) async {
    ExportResult? exportResult;

    try {
      debugPrint('[SettingsScreen] 📤 Utente ha richiesto export database');

      if (!context.mounted) return;

      // Mostra loading dialog durante l'operazione di I/O
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

      // Salva il database nella cartella Download (pubblica o privata in base
      // alla versione Android; vedi BackupController._resolveDownloadsDirectory)
      final controller = ref.read(backupControllerProvider.notifier);
      exportResult = await controller.exportToTemporaryFile();

      debugPrint('[SettingsScreen] ✅ Export completato: ${exportResult.path}');
      debugPrint('[SettingsScreen] 📊 Dimensione: ${_formatFileSize(exportResult.sizeBytes)}');

      // Aggiorna il path visibile nella sezione Backup sotto il pulsante
      await ref
          .read(lastExportPathProvider.notifier)
          .updateLastExportPath(exportResult.path);

      if (!context.mounted) return;

      // Chiudi loading dialog
      Navigator.of(context).pop();

      // Snackbar con il nome del file salvato per comunicare all'utente
      // dove trovare il backup (il path completo è visibile nell'UI)
      AppSnackBar.showSuccess(
        context,
        'backup.export_saved_to'.tr(args: [p.basename(exportResult.path)]),
      );
    } catch (e, stack) {
      debugPrint('[SettingsScreen] ❌ Export fallito: $e\n$stack');

      // Chiudi loading dialog se ancora aperto
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }

      if (exportResult == null && context.mounted) {
        AppSnackBar.showError(context, 'backup.export_failed'.tr());
      }
    }
  }

  /// Importa il database da un file selezionato dall'utente
  Future<void> _handleImportDatabase(BuildContext context) async {
    try {
      debugPrint('[SettingsScreen] 📥 Utente ha richiesto import database');

      // Step 1: Recupera il path della cartella Download (stessa usata per export)
      final backupDirPath = await ref
          .read(backupControllerProvider.notifier)
          .getBackupDirectoryPath();

      if (!context.mounted) return;

      // Step 1b: Mostra warning dialog con path del backup di sicurezza
      final confirmed = await _showImportWarningDialog(
        context,
        backupDirPath: backupDirPath,
      );

      if (confirmed != true) {
        debugPrint('[SettingsScreen] ❌ Import annullato dall\'utente');
        return;
      }

      // Step 2: Crea il safety backup IMMEDIATAMENTE dopo la conferma dell'utente,
      // PRIMA di aprire il file picker. In questo modo il backup è garantito
      // anche se l'utente annulla il picker o se l'import fallisce in seguito.
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (ctx) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('backup.creating_safety_backup'.tr()),
                ],
              ),
            ),
      );

      final controller = ref.read(backupControllerProvider.notifier);
      String? preCreatedBackupPath;
      try {
        preCreatedBackupPath = await controller.createSafetyBackup();
        debugPrint(
          '[SettingsScreen] ✅ Safety backup creato preventivamente: $preCreatedBackupPath',
        );
      } catch (e) {
        debugPrint('[SettingsScreen] ❌ Safety backup fallito: $e');
        if (context.mounted) {
          Navigator.of(context).pop();
          AppSnackBar.showError(context, 'backup.safety_backup_failed'.tr());
        }
        return;
      }
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Chiudi loading del safety backup

      // Step 3: Seleziona file
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

      // Step 4: Valida nome file
      if (!controller.validateImportFileName(filePath)) {
        debugPrint('[SettingsScreen] ❌ Nome file non valido');
        if (context.mounted) {
          AppSnackBar.showError(
            context,
            'backup.import_validation_failed'.tr(),
          );
        }
        return;
      }

      // Step 5: Mostra loading
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

      // Step 6: Import database (passa il backup già creato per non ricrearlo)
      debugPrint('[SettingsScreen] 🚀 Avvio import con disaster recovery...');
      final importResult = await controller.importDatabase(
        filePath,
        preCreatedBackupPath: preCreatedBackupPath,
      );

      // Chiudi loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Step 6: Mostra risultato
      if (context.mounted) {
        if (importResult.success) {
          debugPrint('[SettingsScreen] ✅ Import completato con successo');
          AppSnackBar.showSuccess(context, 'backup.import_success'.tr());
        } else {
          debugPrint('[SettingsScreen] ❌ Import fallito: ${importResult.errorMessage}');
          AppSnackBar.showError(
            context,
            importResult.errorMessage ?? 'backup.import_failed'.tr(),
          );
        }
      }
    } catch (e) {
      debugPrint('[SettingsScreen] ❌ Errore critico durante import: $e');
      
      // Chiudi loading dialog se aperto
      if (context.mounted) {
        Navigator.of(context).pop();
        AppSnackBar.showError(context, 'backup.critical_error'.tr());
      }
    }
  }

  /// Dialog di conferma import con path della cartella di backup di sicurezza.
  ///
  /// Mostra all'utente dove verrà salvata la copia automatica prima
  /// di procedere con la sostituzione del database.
  Future<bool> _showImportWarningDialog(
    BuildContext context, {
    required String backupDirPath,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('backup.import_warning_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('backup.import_warning_message'.tr()),
            const SizedBox(height: 16),
            Text(
              'backup.safety_backup_path_label'.tr(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius:
                    BorderRadius.circular(AppConstants.inputBorderRadius),
              ),
              child: SelectableText(
                backupDirPath,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: colorScheme.primary.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'common.confirm'.tr(),
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );

    return confirmed ?? false;
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
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
      borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
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
      borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
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

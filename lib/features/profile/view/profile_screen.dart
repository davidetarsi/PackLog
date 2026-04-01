import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/controllers/backup_controller.dart';
import '../../../shared/config/app_config.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/providers/theme_provider.dart';
import '../providers/last_export_path_provider.dart';
import '../services/feedback_url_service.dart';
import '../widgets/language_tile.dart';
import '../widgets/theme_tile.dart';

/// Schermata di profilo: unico punto di accesso a preferenze,
/// backup/ripristino dati e informazioni sull'app.
///
/// È una schermata autonoma con proprio [Scaffold] e [AppBar], esposta
/// come branch nella [StatefulShellRoute] del router (tab "Profilo").
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // -------------------------------------------------------------------------
  // Dialogs — Tema e Lingua
  // -------------------------------------------------------------------------

  void _showThemeDialog(BuildContext context) {
    final currentThemeMode =
        ref.read(themeModeNotifierProvider).valueOrNull ?? ThemeMode.dark;

    showDialog<void>(
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
                ref
                    .read(themeModeNotifierProvider.notifier)
                    .setThemeMode(ThemeMode.light);
                Navigator.of(dialogContext).pop();
              },
            ),
            const SizedBox(height: 8),
            ThemeTile(
              mode: ThemeMode.dark,
              title: 'settings.theme_dark'.tr(),
              icon: Icons.dark_mode,
              isSelected: currentThemeMode == ThemeMode.dark,
              onTap: () {
                ref
                    .read(themeModeNotifierProvider.notifier)
                    .setThemeMode(ThemeMode.dark);
                Navigator.of(dialogContext).pop();
              },
            ),
            const SizedBox(height: 8),
            ThemeTile(
              mode: ThemeMode.system,
              title: 'settings.theme_system'.tr(),
              icon: Icons.brightness_auto,
              isSelected: currentThemeMode == ThemeMode.system,
              onTap: () {
                ref
                    .read(themeModeNotifierProvider.notifier)
                    .setThemeMode(ThemeMode.system);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog<void>(
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
            const SizedBox(height: 8),
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

  // -------------------------------------------------------------------------
  // Backup — Export
  // -------------------------------------------------------------------------

  Future<void> _handleExportDatabase(BuildContext context) async {
    ExportResult? exportResult;

    try {
      debugPrint('[ProfileScreen] 📤 Utente ha richiesto export database');
      if (!context.mounted) return;

      showDialog<void>(
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

      final controller = ref.read(backupControllerProvider.notifier);
      exportResult = await controller.exportToTemporaryFile();

      debugPrint('[ProfileScreen] ✅ Export: ${exportResult.path}');

      await ref
          .read(lastExportPathProvider.notifier)
          .updateLastExportPath(exportResult.path);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      AppSnackBar.showSuccess(
        context,
        'backup.export_saved_to'.tr(args: [p.basename(exportResult.path)]),
      );
    } catch (e, stack) {
      debugPrint('[ProfileScreen] ❌ Export fallito: $e\n$stack');
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

  // -------------------------------------------------------------------------
  // Backup — Import
  // -------------------------------------------------------------------------

  Future<void> _handleImportDatabase(BuildContext context) async {
    try {
      debugPrint('[ProfileScreen] 📥 Utente ha richiesto import database');

      final backupDirPath = await ref
          .read(backupControllerProvider.notifier)
          .getBackupDirectoryPath();

      if (!context.mounted) return;

      final confirmed = await _showImportWarningDialog(
        context,
        backupDirPath: backupDirPath,
      );
      if (confirmed != true) return;

      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
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
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          AppSnackBar.showError(context, 'backup.safety_backup_failed'.tr());
        }
        return;
      }
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.single.path;
      if (filePath == null) return;

      if (!controller.validateImportFileName(filePath)) {
        if (context.mounted) {
          AppSnackBar.showError(
            context,
            'backup.import_validation_failed'.tr(),
          );
        }
        return;
      }

      if (!context.mounted) return;
      showDialog<void>(
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

      final importResult = await controller.importDatabase(
        filePath,
        preCreatedBackupPath: preCreatedBackupPath,
      );

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      if (context.mounted) {
        if (importResult.success) {
          AppSnackBar.showSuccess(context, 'backup.import_success'.tr());
        } else {
          AppSnackBar.showError(
            context,
            importResult.errorMessage ?? 'backup.import_failed'.tr(),
          );
        }
      }
    } catch (e) {
      debugPrint('[ProfileScreen] ❌ Errore critico durante import: $e');
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        AppSnackBar.showError(context, 'backup.critical_error'.tr());
      }
    }
  }

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

  // -------------------------------------------------------------------------
  // URL helpers
  // -------------------------------------------------------------------------

  /// Apre [url] nel browser/app di sistema.
  ///
  /// [mode] è opzionale: di default usa [LaunchMode.externalApplication].
  /// Gestisce sia ritorni `false` sia [PlatformException] in un unico
  /// try-catch per un error handling consistente.
  Future<void> _launchUrl(
    BuildContext context,
    String url, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: mode);
      if (!launched && context.mounted) {
        AppSnackBar.showError(context, 'settings.open_link_error'.tr());
      }
    } catch (e) {
      debugPrint('[ProfileScreen] ⚠️ Errore apertura URL ($url): $e');
      if (context.mounted) {
        AppSnackBar.showError(context, 'settings.open_link_error'.tr());
      }
    }
  }

  /// Costruisce l'URL del form di feedback (Context Injection: OS + versione app)
  /// e lo apre con Chrome Custom Tabs / Safari View Controller.
  Future<void> _openFeedbackForm(BuildContext context) async {
    try {
      final result = await FeedbackUrlService().build();
      if (!context.mounted) return;
      await _launchUrl(
        context,
        result.uri.toString(),
        mode: LaunchMode.inAppBrowserView,
      );
    } catch (e) {
      debugPrint('[ProfileScreen] ⚠️ Errore apertura form feedback: $e');
      if (context.mounted) {
        AppSnackBar.showError(context, 'settings.open_link_error'.tr());
      }
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;
    final languageName =
        currentLocale.languageCode == 'it' ? 'Italiano' : 'English';

    final themeModeAsync = ref.watch(themeModeNotifierProvider);
    final themeModeName = themeModeAsync.when(
      data: (mode) => switch (mode) {
        ThemeMode.light => 'settings.theme_light'.tr(),
        ThemeMode.dark => 'settings.theme_dark'.tr(),
        ThemeMode.system => 'settings.theme_system'.tr(),
      },
      loading: () => 'common.loading'.tr(),
      error: (_, _) => 'settings.theme_dark'.tr(),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('settings.title'.tr()),
        centerTitle: true,
        // Nessun leading: questa è una schermata radice del tab bar,
        // non si può fare pop verso un livello superiore.
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          // ── Preferenze ──────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.language),
            title: Text('settings.language'.tr()),
            subtitle: Text(languageName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context),
          ),
          const Divider(),

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

          // ── Backup & Ripristino ──────────────────────────────────────────
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      displayPath,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.7),
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

          ListTile(
            leading: const Icon(Icons.download),
            title: Text('backup.import_database'.tr()),
            subtitle: Text('backup.import_subtitle'.tr()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _handleImportDatabase(context),
          ),
          const Divider(),

          // ── About ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'settings.about_section_title'.tr(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: Text('settings.feedback'.tr()),
            subtitle: Text('settings.feedback_subtitle'.tr()),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openFeedbackForm(context),
          ),

          ListTile(
            leading: const Icon(Icons.code),
            title: Text('settings.view_project'.tr()),
            subtitle: Text('settings.view_project_subtitle'.tr()),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launchUrl(context, AppConfig.githubUrl),
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('settings.about'.tr()),
            subtitle: Text('${'common.version'.tr()} 1.0.0'),
          ),

          ListTile(
            leading: const Icon(Icons.storage),
            title: Text('common.storage'.tr()),
            subtitle: Text('common.data_saved_locally'.tr()),
          ),

          const Divider(),
        ],
      ),
    );
  }
}

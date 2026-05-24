import 'package:easy_localization/easy_localization.dart';
// import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_exceptions.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/auth_state.dart';
import '../providers/gpt_usage_provider.dart';
// import '../../../core/database/controllers/backup_controller.dart';
// import 'package:sentry_flutter/sentry_flutter.dart';

// import '../../../core/database/exceptions/backup_exceptions.dart';
// import '../../../core/monitoring/monitoring_service.dart';
import '../../../shared/config/app_config.dart';
// import '../../../shared/constants/app_constants.dart'; // used by backup dialog
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/providers/package_info_provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/ds_section_header.dart';
// import '../providers/last_export_path_provider.dart';
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
  // Backup — Export [COMMENTATO: non usato con Supabase cloud]
  // -------------------------------------------------------------------------

  // Future<void> _handleExportDatabase(BuildContext context) async {
  //   ExportResult? exportResult;
  //   try {
  //     debugPrint('[ProfileScreen] 📤 Utente ha richiesto export database');
  //     if (!context.mounted) return;
  //     showDialog<void>(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (ctx) => AlertDialog(
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             const CircularProgressIndicator(),
  //             const SizedBox(height: 16),
  //             Text('backup.export_database'.tr()),
  //           ],
  //         ),
  //       ),
  //     );
  //     final controller = ref.read(backupControllerProvider.notifier);
  //     exportResult = await controller.exportToTemporaryFile();
  //     debugPrint('[ProfileScreen] ✅ Export: ${exportResult.path}');
  //     await ref.read(lastExportPathProvider.notifier).updateLastExportPath(exportResult.path);
  //     if (!context.mounted) return;
  //     Navigator.of(context, rootNavigator: true).pop();
  //     AppSnackBar.showSuccess(context, 'backup.export_saved_to'.tr(args: [p.basename(exportResult.path)]));
  //   } catch (e, stack) {
  //     debugPrint('[ProfileScreen] ❌ Export fallito: $e\n$stack');
  //     if (context.mounted) { try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {} }
  //     if (exportResult == null && context.mounted) { AppSnackBar.showError(context, 'backup.export_failed'.tr()); }
  //   }
  // }

  // -------------------------------------------------------------------------
  // Backup — Import [COMMENTATO: non usato con Supabase cloud]
  // -------------------------------------------------------------------------

  // Future<void> _handleImportDatabase(BuildContext context) async { ... }
  // Future<void> _showRollbackErrorDialog(BuildContext context) async { ... }
  // Future<bool> _showImportWarningDialog(BuildContext context, {required String backupDirPath}) async { ... }

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
  // Auth — Sign Out
  // -------------------------------------------------------------------------

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on SignOutFailedException catch (e) {
      debugPrint('[ProfileScreen] Sign-out failed: $e');
      if (context.mounted) {
        AppSnackBar.showError(context, 'login.sign_out_failed'.tr());
      }
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;
    final languageName = currentLocale.languageCode == 'it'
        ? 'Italiano'
        : 'English';

    final authState = ref.watch(authNotifierProvider);
    final displayName = switch (authState) {
      Authenticated(:final displayName) => displayName,
      Unauthenticated() => null,
    };
    final userEmail = switch (authState) {
      Authenticated(:final email) => email,
      Unauthenticated() => '',
    };
    final gptUsageAsync = ref.watch(gptUsageProvider);

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
        // Nessun leading: questa è una schermata radice del tab bar,
        // non si può fare pop verso un livello superiore.
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          // ── Account identity ────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(
              (displayName != null && displayName.isNotEmpty)
                  ? displayName
                  : userEmail,
            ),
            subtitle: userEmail.isNotEmpty ? Text(userEmail) : null,
          ),
          const Divider(),

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

          // ── AI usage ────────────────────────────────────────────────────
          gptUsageAsync.when(
            data: (usage) => ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text('profile.ai_usage_title'.tr()),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: context.spacingXs),
                  LinearProgressIndicator(
                    value: usage.progress,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  SizedBox(height: context.spacingXs),
                  Text(
                    'profile.ai_usage_subtitle'.tr(
                      args: [
                        usage.monthlyCount.toString(),
                        usage.monthlyCap.toString(),
                      ],
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            loading: () => ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text('profile.ai_usage_title'.tr()),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: context.spacingXs),
                  const LinearProgressIndicator(),
                ],
              ),
            ),
            error: (error, _) => ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text('profile.ai_usage_title'.tr()),
              subtitle: Text(
                'errors.load_failed'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
          const Divider(),

          // ── Backup & Ripristino [COMMENTATO: non usato con Supabase cloud] ──
          // DsSectionHeader(label: 'backup.title'.tr(), ...),
          // Consumer(builder: (context, ref, _) { ... }),  // export tile
          // ListTile(...),  // import tile
          // const Divider(),

          // ── About ────────────────────────────────────────────────────────
          DsSectionHeader(
            label: 'settings.about_section_title'.tr(),
            padding: EdgeInsets.fromLTRB(
              context.spacingMd,
              context.spacingLg,
              context.spacingMd,
              context.spacingSm,
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
            subtitle: ref
                .watch(packageInfoProvider)
                .when(
                  data: (info) =>
                      Text('${'common.version'.tr()} ${info.version}'),
                  loading: () => Text('${'common.version'.tr()} …'),
                  error: (_, _) => Text('${'common.version'.tr()} —'),
                ),
          ),

          /* ListTile(
            leading: const Icon(Icons.storage),
            title: Text('common.storage'.tr()),
            subtitle: Text('common.data_saved_locally'.tr()),
          ), */
          const Divider(),

          // ── Account ─────────────────────────────────────────────────
          const SizedBox(height: 8),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
            child: FilledButton.tonalIcon(
              onPressed: () => _handleSignOut(context),
              icon: const Icon(Icons.logout),
              label: Text('login.sign_out'.tr()),
              style: FilledButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

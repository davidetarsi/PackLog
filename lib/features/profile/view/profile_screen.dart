import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/auth/auth_exceptions.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../features/houses/providers/house_provider.dart';
import '../../../features/tour/providers/post_login_onboarding_provider.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../providers/gpt_usage_provider.dart';
import '../../../shared/config/app_config.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/providers/package_info_provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/ds_section_header.dart';
import '../services/feedback_url_service.dart';
import '../widgets/sync_status_tile.dart';
import 'dialogs/profile_delete_account_dialog.dart';
import 'dialogs/profile_language_dialog.dart';
import 'dialogs/profile_logout_dialog.dart';
import 'dialogs/profile_theme_dialog.dart';

/// Schermata di profilo: unico punto di accesso a preferenze,
/// sync e informazioni sull'app.
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
    // Legge il conteggio pending fresco prima di aprire il dialog: il dialog
    // deve sempre mostrare dati attuali, non il valore cacheato della tile.
    final pending = await ref.read(syncServiceProvider).countPendingChanges();
    if (!context.mounted) return;

    final choice = await showProfileLogoutDialog(context, pending);
    if (choice == null || choice == ProfileLogoutChoice.cancel) return;

    if (choice == ProfileLogoutChoice.syncFirst) {
      // Best-effort flush con timeout, poi logout in ogni caso.
      try {
        await ref
            .read(syncServiceProvider)
            .processQueue()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[ProfileScreen] Pre-logout sync failed: $e');
      }
    }

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
  // Auth — Delete Account (GDPR Art. 17 — Right to Erasure)
  // -------------------------------------------------------------------------

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final authState = ref.read(authNotifierProvider);
    if (authState is! Authenticated) return;
    final email = authState.email;

    final confirmed = await showProfileDeleteAccountDialog(context, email);
    if (confirmed != true || !context.mounted) return;

    // Cattura riferimenti stabili PRIMA degli await: appena `signOut()`
    // (interno a deleteAccount) fa scattare l'auth gate del router,
    // ProfileScreen viene disposta e `context.mounted` diventa false →
    // il pop del loader non scatterebbe più. `rootNavigator` invece punta
    // al Navigator dentro MaterialApp, che sopravvive alle navigazioni.
    final rootNav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    // Loading dialog: l'operazione tocca rete + più DELETE Postgres → può
    // impiegare qualche secondo. `useRootNavigator: true` mette il dialog
    // sul root navigator, così la sua chiusura è indipendente dal branch
    // shell route della tab Profilo.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      // Wipe del DB locale: senza questo, il prossimo login (anche con
      // altro utente) vedrebbe transitoriamente i dati di chi è stato
      // appena cancellato finché il fullPull non sostituisce tutto.
      await ref.read(syncServiceProvider).wipeAllUserData();

      // Niente check `context.mounted` qui: è già false (l'auth gate ha
      // rediretto a /login). Il rootNav è ancora valido.
      if (rootNav.canPop()) rootNav.pop();
      // Niente snackbar di successo: l'utente sta venendo rediretto a
      // /login, lo stato "operazione completata" è implicito nel redirect.
      // Una snackbar mostrata su /login sarebbe out-of-context.
    } on DeleteAccountFailedException catch (e) {
      debugPrint('[ProfileScreen] Delete account failed: $e');
      // Sul path di errore l'utente è ANCORA loggato (deleteAccount
      // throws prima di signOut) → ProfileScreen ancora mounted →
      // messenger riferimento valido.
      if (rootNav.canPop()) rootNav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('profile.delete_account_failed'.tr()),
          backgroundColor: errorColor,
        ),
      );
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

    final authState = ref.watch(authNotifierProvider);
    final displayName = switch (authState) {
      Authenticated(:final displayName) => displayName,
      Unauthenticated() => null,
    };
    final userEmail = switch (authState) {
      Authenticated(:final email) => email,
      Unauthenticated() => '',
    };

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

    return ShellTabScaffold(
      appBar: AppBar(
        title: Text('settings.title'.tr()),
        // Nessun leading: schermata radice del tab bar, nessun pop a livello superiore.
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(gptUsageProvider),
        child: ListView(
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
              onTap: () => showProfileLanguageDialog(context),
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
              onTap: () => showProfileThemeDialog(
                context,
                currentThemeMode:
                    ref.read(themeModeNotifierProvider).valueOrNull ??
                    ThemeMode.dark,
                onSetThemeMode: (mode) =>
                    ref.read(themeModeNotifierProvider.notifier).setThemeMode(mode),
              ),
            ),
            const Divider(),

            // ── AI usage ────────────────────────────────────────────────────
            const _GptUsageTile(),
            const Divider(),

            // ── Sync status ───────────────────────────────────────────────────
            const SyncStatusTile(),
            const Divider(),

            // ── Tour ──────────────────────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.tour_outlined),
              title: Text('tour.relaunch_title'.tr()),
              subtitle: Text('tour.relaunch_subtitle'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                ref.read(analyticsServiceProvider).logEvent('tour_relaunched');
                final houses =
                    ref.read(houseNotifierProvider).valueOrNull ?? [];
                await ref
                    .read(postLoginOnboardingProvider.notifier)
                    .reset(hasExistingHouses: houses.isNotEmpty);
                if (context.mounted) context.go('/');
              },
            ),
            const Divider(),

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
            AppSpacing.gapSm,

            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
              child: UniversalActionBar(
                primaryLabel: 'login.sign_out'.tr(),
                primaryIcon: Icons.logout,
                onPrimaryPressed: () => _handleSignOut(context),
                isSecondary: true,
              ),
            ),

            AppSpacing.gapSm,

            // Hard-delete account (GDPR Art. 17). Distruttivo e irreversibile,
            // protetto da dialog con conferma email.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
              child: UniversalActionBar(
                primaryLabel: 'profile.delete_account_cta'.tr(),
                primaryIcon: Icons.delete_forever,
                onPrimaryPressed: () => _handleDeleteAccount(context),
                isDestructive: true,
              ),
            ),

            AppSpacing.gapMd,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widget components
// ─────────────────────────────────────────────────────────────────────────────

class _GptUsageTile extends ConsumerWidget {
  const _GptUsageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gptUsageAsync = ref.watch(gptUsageProvider);

    return gptUsageAsync.when(
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
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            SizedBox(height: context.spacingXs),
            Text(
              'profile.ai_usage_subtitle'.tr(
                args: [
                  usage.usageCount.toString(),
                  usage.usageCap.toString(),
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
      error: (_, _) => ListTile(
        leading: const Icon(Icons.auto_awesome_outlined),
        title: Text('profile.ai_usage_title'.tr()),
        subtitle: Text(
          'errors.load_failed'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/consent/consent_provider.dart';
import '../../../core/auth/auth_exceptions.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../features/houses/providers/house_provider.dart';
import '../../../features/tour/providers/post_login_onboarding_provider.dart';
import '../providers/gpt_usage_provider.dart';
import '../../promo/view/promo_code_sheet.dart';
import '../../../shared/config/app_config.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/nav_bar_spacing.dart';
import '../../../shared/providers/package_info_provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/widgets/ds_group_header.dart';
import '../../../shared/widgets/ds_settings.dart';
import '../../../shared/widgets/ds_inline_error.dart';
import '../../../shared/widgets/tab_header.dart' show profileInitials;
import '../services/feedback_url_service.dart';
import '../widgets/sync_status_tile.dart';
import 'dialogs/profile_delete_account_dialog.dart';
import 'dialogs/profile_language_dialog.dart';
import 'dialogs/profile_logout_dialog.dart';
import 'dialogs/profile_theme_dialog.dart';

/// Schermata di profilo: unico punto di accesso a preferenze,
/// sync e informazioni sull'app.
///
/// È una schermata autonoma con proprio [Scaffold] e [AppBar], aperta come
/// route radice (`/profile`) dall'avatar nell'intestazione delle tab: non fa
/// parte della shell, quindi ha la freccia indietro.
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

    final version = ref
        .watch(packageInfoProvider)
        .when(
          data: (info) => info.version,
          loading: () => '…',
          error: (_, _) => '—',
        );
    final externalIcon = Icon(
      Icons.open_in_new,
      size: context.iconSizeSm,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(gptUsageProvider),
          child: ListView(
            // Padding esplicito: senza, ListView (padding null) auto-inietta
            // MediaQuery.padding.top come proprio sliver padding. Scaffold NON
            // azzera quel padding per il body quando extendBodyBehindAppBar è
            // false (default) — l'AppBar occupa già visivamente quello spazio,
            // ma il valore di MediaQuery resta quello dell'intero schermo.
            // `bottom`: fuori dalla shell non c'è più la nav bar flottante, resta
            // solo la gesture bar di sistema: è lo spazio che `navBarReservedHeight`
            // riserva, così l'ultimo elemento resta raggiungibile.
            padding: EdgeInsets.fromLTRB(
              context.spacingMd,
              context.spacingSm,
              context.spacingMd,
              context.navBarReservedHeight,
            ),
            children: [
              _AccountHeader(displayName: displayName, email: userEmail),

              // ── Preferenze ──────────────────────────────────────────────────
              DsGroupHeader(label: 'profile.section_preferences'.tr()),
              DsSettingsGroup(
                children: [
                  DsSettingsRow(
                    label: 'settings.language'.tr(),
                    value: languageName,
                    onTap: () => showProfileLanguageDialog(context),
                  ),
                  DsSettingsRow(
                    label: 'settings.theme'.tr(),
                    value: themeModeName,
                    onTap: () => showProfileThemeDialog(
                      context,
                      currentThemeMode:
                          ref.read(themeModeNotifierProvider).valueOrNull ??
                          ThemeMode.dark,
                      onSetThemeMode: (mode) => ref
                          .read(themeModeNotifierProvider.notifier)
                          .setThemeMode(mode),
                    ),
                  ),
                ],
              ),

              // ── AI usage ────────────────────────────────────────────────────
              DsGroupHeader(label: 'profile.ai_usage_title'.tr()),
              const _GptUsageGroup(),

              // ── Account ─────────────────────────────────────────────────────
              DsGroupHeader(label: 'profile.section_account'.tr()),
              DsSettingsGroup(
                children: [
                  const SyncStatusTile(),
                  DsSettingsRow(
                    key: const Key('profile_sign_out'),
                    label: 'login.sign_out'.tr(),
                    onTap: () => _handleSignOut(context),
                  ),
                ],
              ),

              // ── Aiuto e info ────────────────────────────────────────────────
              DsGroupHeader(label: 'settings.about_section_title'.tr()),
              DsSettingsGroup(
                children: [
                  DsSettingsRow(
                    label: 'tour.relaunch_title'.tr(),
                    trailing: Icon(
                      Icons.chevron_right,
                      size: context.iconSizeSm,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onTap: () async {
                      ref
                          .read(analyticsServiceProvider)
                          .logEvent('tour_relaunched');
                      final houses =
                          ref.read(houseNotifierProvider).valueOrNull ?? [];
                      await ref
                          .read(postLoginOnboardingProvider.notifier)
                          .reset(hasExistingHouses: houses.isNotEmpty);
                      if (context.mounted) context.go('/');
                    },
                  ),
                  DsSettingsRow(
                    label: 'settings.feedback'.tr(),
                    trailing: externalIcon,
                    onTap: () => _openFeedbackForm(context),
                  ),
                  DsSettingsRow(
                    label: 'settings.view_project'.tr(),
                    trailing: externalIcon,
                    onTap: () => _launchUrl(context, AppConfig.githubUrl),
                  ),
                  // In fondo, non in Preferenze: va lasciato a disposizione
                  // (GDPR art. 7 e 21, "raccolta facoltativa" nel Data safety
                  // di Play) ma non serve in vista. Attivo di default.
                  const _AnalyticsToggleTile(),
                  DsSettingsRow(label: 'common.version'.tr(), value: version),
                ],
              ),

              AppSpacing.gapXl,

              // Hard-delete account (GDPR Art. 17). Distruttivo e irreversibile:
              // si trova, ma è solo testo rosso in fondo alla pagina, staccato
              // da "Esci", così non è l'elemento più evidente. Protetto da
              // dialog con conferma email.
              Center(
                child: TextButton(
                  key: const Key('profile_delete_account'),
                  onPressed: () => _handleDeleteAccount(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: Text('profile.delete_account_cta'.tr()),
                ),
              ),

              AppSpacing.gapSm,
            ],
          ),
        ),
      ),
    );
  }
}

/// Chi è collegato: iniziali (come l'avatar nelle tab), nome ed email. Non è
/// toccabile: nome ed email arrivano dal login.
class _AccountHeader extends StatelessWidget {
  final String? displayName;
  final String email;

  const _AccountHeader({required this.displayName, required this.email});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = displayName;
    final hasName = name != null && name.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacingSm),
      child: Row(
        children: [
          CircleAvatar(
            radius: context.responsive(28),
            backgroundColor: cs.primaryContainer,
            child: Text(
              profileInitials(displayName, email),
              style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer),
            ),
          ),
          SizedBox(width: context.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasName ? name : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (hasName && email.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widget components
// ─────────────────────────────────────────────────────────────────────────────

/// Interruttore delle statistiche d'uso.
///
/// Le statistiche non sono un trattamento strettamente necessario: devono
/// poter essere disattivate **mantenendo l'account**. È anche ciò che rende
/// veritiera la dichiarazione "raccolta opzionale" nel Data safety di Play.
///
/// Non tocca il consenso a privacy policy e termini, che è un registro legale
/// separato e resta condizione per usare l'app.
class _AnalyticsToggleTile extends ConsumerStatefulWidget {
  const _AnalyticsToggleTile();

  @override
  ConsumerState<_AnalyticsToggleTile> createState() =>
      _AnalyticsToggleTileState();
}

class _AnalyticsToggleTileState extends ConsumerState<_AnalyticsToggleTile> {
  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(consentServiceProvider);

    return DsSettingsRow(
      label: 'settings.analytics_title'.tr(),
      subtitle: 'settings.analytics_subtitle'.tr(),
      trailing: Switch(value: consent.analyticsEnabled, onChanged: _toggle),
      onTap: () => _toggle(!consent.analyticsEnabled),
    );
  }

  Future<void> _toggle(bool value) async {
    final consent = ref.read(consentServiceProvider);
    final analytics = ref.read(analyticsServiceProvider);

    // Disattivando: prima si emette l'evento che documenta la scelta,
    // poi si chiude il gate. Nell'ordine inverso l'evento verrebbe
    // scartato dal gate stesso, e non resterebbe traccia dell'opt-out.
    if (!value) {
      analytics.logEvent('analytics_opt_out', properties: {'enabled': false});
    }

    await consent.setAnalyticsEnabled(value);

    if (value) {
      // Riattivando, l'evento va emesso DOPO: prima il gate era chiuso.
      analytics.logEvent('analytics_opt_in', properties: {'enabled': true});
    } else {
      // Dissocia l'identità già inviata ai backend. `clearUser` è
      // deliberatamente fuori dal gate proprio per questo caso: riduce i
      // dati, non li trasmette.
      analytics.clearUser();
    }

    if (mounted) setState(() {});
  }
}

/// Gli usi AI del mese: quanti ne restano, quando si rinnovano, i bonus, e
/// il codice promo se si può ancora usare.
///
/// La barra è neutra: è un contatore, non un'azione, e l'arancio in questa
/// pagina resta ai controlli.
class _GptUsageGroup extends ConsumerWidget {
  const _GptUsageGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final smallText = tt.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final dateFormat = DateFormat.MMMd(context.locale.toString());
    final usage = ref.watch(gptUsageProvider);

    Widget bar(double? value) => ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
      child: LinearProgressIndicator(
        value: value,
        minHeight: context.spacingXs,
        backgroundColor: cs.surfaceContainerHighest,
        color: cs.onSurface,
      ),
    );

    final summary = usage.when(
      data: (usage) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'profile.ai_usage_subtitle'.tr(
              args: [usage.usageCount.toString(), usage.usageCap.toString()],
            ),
            style: tt.bodyLarge,
          ),
          SizedBox(height: context.spacingSm),
          bar(usage.progress),
          if (usage.resetsAt != null) ...[
            SizedBox(height: context.spacingSm),
            Text(
              'profile.ai_usage_resets'.tr(
                args: [dateFormat.format(usage.resetsAt!)],
              ),
              style: smallText,
            ),
          ],
          if (usage.bonusAvailable > 0 && usage.bonusExpiresAt != null)
            Text(
              'profile.ai_usage_bonus'.tr(
                args: [
                  usage.bonusAvailable.toString(),
                  dateFormat.format(usage.bonusExpiresAt!),
                ],
              ),
              key: const Key('profile_ai_bonus'),
              style: smallText,
            ),
        ],
      ),
      loading: () => bar(null),
      error: (_, _) => DsInlineError(
        message: 'profile.ai_usage_load_failed'.tr(),
        onRetry: () => ref.invalidate(gptUsageProvider),
      ),
    );

    return DsSettingsGroup(
      children: [
        Padding(padding: EdgeInsets.all(context.spacingMd), child: summary),
        if (usage.valueOrNull?.canRedeemPromo ?? false)
          DsSettingsRow(
            key: const Key('profile_promo_code'),
            label: 'promo.link'.tr(),
            trailing: Icon(
              Icons.chevron_right,
              size: context.iconSizeSm,
              color: cs.onSurfaceVariant,
            ),
            onTap: () => showPromoCodeSheet(context, redeemNow: true),
          ),
      ],
    );
  }
}

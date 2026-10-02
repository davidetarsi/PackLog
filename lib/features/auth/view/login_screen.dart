import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../bootstrap.dart' show initConsentedAnalytics;
import '../../../core/analytics/analytics_service.dart';
import '../../../core/auth/auth_exceptions.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/consent/consent_provider.dart';
import '../../../shared/config/app_config.dart';
import '../../../shared/helpers/exception_message.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  bool _consentGiven = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(analyticsServiceProvider).logEvent('login_screen_viewed');
      }
    });
  }

  /// Registra o revoca il consenso al variare della casella.
  ///
  /// È il primo trattamento lecito del ciclo di vita dell'app: tutto ciò che
  /// precede (le tre schermate di onboarding, la vista della schermata di
  /// login) viene scartato dal gate in `AppAnalyticsService`.
  Future<void> _onConsentChanged(bool? value) async {
    final given = value ?? false;
    setState(() => _consentGiven = given);

    final consent = ref.read(consentServiceProvider);

    if (!given) {
      // Despuntare ritira il consenso. Non emettiamo nessun evento per
      // segnalarlo: registrare la revoca richiederebbe a sua volta un
      // consenso che l'utente ha appena tolto.
      await consent.revokeLocal();
      return;
    }

    // Registrare PRIMA di emettere: il gate legge `hasConsent` in modo
    // sincrono, quindi deve già trovarlo attivo o scarterebbe proprio
    // l'evento che documenta il consenso.
    await consent.record(policyVersion: AppConfig.policyVersion);

    // Solo ORA gli SDK di analytics possono partire. Al bootstrap non erano
    // stati inizializzati perché il consenso non c'era ancora: senza questa
    // chiamata resterebbero spenti fino al riavvio successivo dell'app.
    // Idempotente, quindi ri-spuntare la casella non li reinizializza.
    await initConsentedAnalytics();

    if (!mounted) return;
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          'consent_given',
          properties: {'policy_version': AppConfig.policyVersion},
        );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    ref
        .read(analyticsServiceProvider)
        .logEvent('login_attempted', properties: {'method': 'google'});

    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      ref
          .read(analyticsServiceProvider)
          .logEvent('login_completed', properties: {'method': 'google'});
    } on SignInFailedException catch (e) {
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            'login_failed',
            properties: {
              'method': 'google',
              'reason': e.reason.name,
              // Niente `e.toString()`: il messaggio Supabase può contenere
              // l'email (es. "Invalid login credentials for <email>") che
              // finirebbe in Amplitude. `runtimeType` ci dà la classe
              // dell'eccezione senza serializzare PII.
              'error_type': e.runtimeType.toString(),
            },
          );
      // Mostra il messaggio specifico al reason solo se non è stato
      // l'utente a cancellare (in quel caso nessuna snackbar — pseudo-noop UX).
      if (mounted && e.reason != AuthFailureReason.cancelled) {
        AppSnackBar.showError(context, exceptionMessage(e));
        debugPrint('[LoginScreen] Sign-in failed: $e');
      }
    } catch (e) {
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            'login_failed',
            properties: {
              'method': 'google',
              // Vedi sopra: solo il tipo, mai il messaggio dell'eccezione.
              'error_type': e.runtimeType.toString(),
            },
          );
      if (mounted) {
        AppSnackBar.showError(context, exceptionMessage(e));
        debugPrint('[LoginScreen] Unexpected error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openLegalDoc(String url) async {
    try {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.inAppBrowserView,
      );
      if (!launched && mounted) {
        AppSnackBar.showError(context, 'settings.open_link_error'.tr());
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'settings.open_link_error'.tr());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacingXl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/icon/app_icon_foreground_clean.png',
                    width: 120,
                    height: 120,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.app_shortcut, size: 80),
                  ),
                ),
                AppSpacing.gapLg,

                Text(
                  'Pack Log',
                  style: textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                AppSpacing.gapSm,

                Text(
                  'login.subtitle'.tr(),
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 3),

                DsButton(
                  label: 'login.sign_in_google'.tr(),
                  icon: Icons.g_mobiledata,
                  expand: true,
                  isLoading: _isLoading,
                  // Senza consenso il bottone è spento: la scala dell'app dice
                  // che non è pronto. Ma il tocco non cade nel vuoto — la
                  // casella qui sotto è piccola e passa inosservata, quindi
                  // l'errore nomina ciò che manca.
                  onPressed: _consentGiven ? _signInWithGoogle : null,
                  onDisabledTap: () => AppSnackBar.showError(
                    context,
                    'login.consent_required'.tr(),
                  ),
                ),

                AppSpacing.gapMd,
                _ConsentRow(
                  value: _consentGiven,
                  onChanged: _onConsentChanged,
                  onPrivacyTap: () => _openLegalDoc(AppConfig.privacyPolicyUrl),
                  onTermsTap: () => _openLegalDoc(AppConfig.termsOfServiceUrl),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Checkbox di consenso con testo che contiene due link tappabili
/// (Privacy Policy e Termini di Servizio). Gating obbligatorio del login.
class _ConsentRow extends StatefulWidget {
  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.onPrivacyTap,
    required this.onTermsTap,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onPrivacyTap;
  final VoidCallback onTermsTap;

  @override
  State<_ConsentRow> createState() => _ConsentRowState();
}

class _ConsentRowState extends State<_ConsentRow> {
  late final TapGestureRecognizer _privacyRecognizer;
  late final TapGestureRecognizer _termsRecognizer;

  @override
  void initState() {
    super.initState();
    _privacyRecognizer = TapGestureRecognizer();
    _termsRecognizer = TapGestureRecognizer();
  }

  @override
  void dispose() {
    _privacyRecognizer.dispose();
    _termsRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final linkStyle = TextStyle(
      color: cs.primary,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );
    final baseStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);

    _privacyRecognizer.onTap = widget.onPrivacyTap;
    _termsRecognizer.onTap = widget.onTermsTap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(value: widget.value, onChanged: widget.onChanged),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: baseStyle,
                  children: [
                    TextSpan(text: 'login.consent_prefix'.tr()),
                    TextSpan(
                      text: 'login.consent_privacy'.tr(),
                      style: linkStyle,
                      recognizer: _privacyRecognizer,
                    ),
                    TextSpan(text: 'login.consent_separator'.tr()),
                    TextSpan(
                      text: 'login.consent_terms'.tr(),
                      style: linkStyle,
                      recognizer: _termsRecognizer,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

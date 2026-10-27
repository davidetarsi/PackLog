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
import '../../../shared/constants/app_constants.dart';
import '../../../shared/helpers/exception_message.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_button.dart';
import '../../../shared/widgets/ds_link_button.dart';
import '../../promo/view/promo_code_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(analyticsServiceProvider).logEvent('login_screen_viewed');
      }
    });
  }

  /// Registra il consenso: toccare "Accedi con Google" vale come accettazione
  /// dei Termini, come dice il testo sotto il bottone.
  ///
  /// È il primo trattamento lecito del ciclo di vita dell'app: tutto ciò che
  /// precede (le tre schermate di onboarding, la vista della schermata di
  /// login) viene scartato dal gate in `AppAnalyticsService`.
  Future<void> _recordConsent() async {
    // Registrare PRIMA di emettere: il gate legge `hasConsent` in modo
    // sincrono, quindi deve già trovarlo attivo o scarterebbe proprio
    // l'evento che documenta il consenso. "First write wins": un secondo
    // tocco non sposta la data del primo.
    await ref
        .read(consentServiceProvider)
        .record(policyVersion: AppConfig.policyVersion);

    // Solo ORA gli SDK di analytics possono partire. Al bootstrap non erano
    // stati inizializzati perché il consenso non c'era ancora: senza questa
    // chiamata resterebbero spenti fino al riavvio successivo dell'app.
    // Idempotente, quindi un nuovo tentativo di login non li reinizializza.
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
    await _recordConsent();
    if (!mounted) return;
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
                  borderRadius: BorderRadius.circular(
                    AppConstants.modalBorderRadius,
                  ),
                  child: Image.asset(
                    'assets/images/login_logo.png',
                    width: 120,
                    height: 120,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.app_shortcut, size: context.iconSizeDisplay),
                  ),
                ),
                SizedBox(height: context.spacingLg),

                Text(
                  'app_name'.tr(),
                  style: textTheme.headlineLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: context.spacingSm),

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
                  onPressed: _signInWithGoogle,
                ),

                SizedBox(height: context.spacingSm),
                DsLinkButton(
                  key: const Key('login_promo_code'),
                  label: 'promo.link'.tr(),
                  onPressed: () =>
                      showPromoCodeSheet(context, redeemNow: false),
                ),

                SizedBox(height: context.spacingSm),
                _ConsentNotice(
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

/// Avviso sotto il bottone: continuare vale come accettazione dei Termini e
/// presa visione della Privacy Policy. I due nomi sono link ai documenti.
class _ConsentNotice extends StatefulWidget {
  const _ConsentNotice({required this.onPrivacyTap, required this.onTermsTap});

  final VoidCallback onPrivacyTap;
  final VoidCallback onTermsTap;

  @override
  State<_ConsentNotice> createState() => _ConsentNoticeState();
}

class _ConsentNoticeState extends State<_ConsentNotice> {
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
    final baseStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final linkStyle = baseStyle?.copyWith(
      color: cs.onSurface,
      decoration: TextDecoration.underline,
    );

    _privacyRecognizer.onTap = widget.onPrivacyTap;
    _termsRecognizer.onTap = widget.onTermsTap;

    return Text.rich(
      key: const Key('login_consent_notice'),
      textAlign: TextAlign.center,
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: 'login.consent_prefix'.tr()),
          TextSpan(
            text: 'login.consent_terms'.tr(),
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
          TextSpan(text: 'login.consent_separator'.tr()),
          TextSpan(
            text: 'login.consent_privacy'.tr(),
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          TextSpan(text: 'login.consent_suffix'.tr()),
        ],
      ),
    );
  }
}

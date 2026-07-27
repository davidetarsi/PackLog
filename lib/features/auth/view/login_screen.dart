import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/auth/auth_exceptions.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/config/app_config.dart';
import '../../../shared/helpers/exception_message.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';

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

  Future<void> _showDevLoginDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('[DEV] Email login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            AppSpacing.gapSm,
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final password = passwordController.text;
              Navigator.of(context).pop();
              await _devSignIn(email, password);
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );

    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> _devSignIn(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Dev login fallito: $e');
        debugPrint('[DevLogin] $e');
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

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_isLoading || !_consentGiven)
                        ? null
                        : _signInWithGoogle,
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.g_mobiledata, size: 28),
                    label: Text(
                      _isLoading
                          ? 'common.loading'.tr()
                          : 'login.sign_in_google'.tr(),
                      style: TextStyle(
                        fontSize: context.fontSizeSm,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                AppSpacing.gapMd,
                _ConsentRow(
                  value: _consentGiven,
                  onChanged: (v) => setState(() => _consentGiven = v ?? false),
                  onPrivacyTap: () => _openLegalDoc(AppConfig.privacyPolicyUrl),
                  onTermsTap: () => _openLegalDoc(AppConfig.termsOfServiceUrl),
                ),

                if (kDebugMode) ...[
                  AppSpacing.gapSm,
                  TextButton(
                    onPressed: _isLoading ? null : _showDevLoginDialog,
                    child: const Text(
                      '[DEV] Email login',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],

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
class _ConsentRow extends StatelessWidget {
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(value: value, onChanged: onChanged),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: baseStyle,
              children: [
                TextSpan(text: 'login.consent_prefix'.tr()),
                TextSpan(
                  text: 'login.consent_privacy'.tr(),
                  style: linkStyle,
                  recognizer: TapGestureRecognizer()..onTap = onPrivacyTap,
                ),
                TextSpan(text: 'login.consent_separator'.tr()),
                TextSpan(
                  text: 'login.consent_terms'.tr(),
                  style: linkStyle,
                  recognizer: TapGestureRecognizer()..onTap = onTermsTap,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

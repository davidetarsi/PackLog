import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/auth/auth_exceptions.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';

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

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    ref.read(analyticsServiceProvider).logEvent(
      'login_attempted',
      properties: {'method': 'google'},
    );

    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      ref.read(analyticsServiceProvider).logEvent(
        'login_completed',
        properties: {'method': 'google'},
      );
    } on SignInFailedException catch (e) {
      ref.read(analyticsServiceProvider).logEvent(
        'login_failed',
        properties: {'method': 'google', 'error': e.toString()},
      );
      if (mounted) {
        AppSnackBar.showError(context, 'login.sign_in_failed'.tr());
        debugPrint('[LoginScreen] Sign-in failed: $e');
      }
    } catch (e) {
      ref.read(analyticsServiceProvider).logEvent(
        'login_failed',
        properties: {'method': 'google', 'error': e.toString()},
      );
      if (mounted) {
        AppSnackBar.showError(context, 'login.sign_in_failed'.tr());
        debugPrint('[LoginScreen] Unexpected error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.app_shortcut, size: 80),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Pack Log',
                  style: textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),

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
                    onPressed: _isLoading ? null : _signInWithGoogle,
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

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

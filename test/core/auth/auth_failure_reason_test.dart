import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:pack_log/core/auth/auth_exceptions.dart';

void main() {
  group('reasonFromSupabaseError - Supabase AuthException codes', () {
    test('invalid_credentials → AuthFailureReason.invalidCredentials', () {
      final err = sb.AuthException(
        'Invalid login',
        code: 'invalid_credentials',
      );
      expect(
        reasonFromSupabaseError(err),
        equals(AuthFailureReason.invalidCredentials),
      );
    });

    test(
      'invalid_login_credentials → AuthFailureReason.invalidCredentials',
      () {
        final err = sb.AuthException(
          'Invalid login credentials',
          code: 'invalid_login_credentials',
        );
        expect(
          reasonFromSupabaseError(err),
          equals(AuthFailureReason.invalidCredentials),
        );
      },
    );

    test('user_not_found → AuthFailureReason.invalidCredentials', () {
      final err = sb.AuthException('Not found', code: 'user_not_found');
      expect(
        reasonFromSupabaseError(err),
        equals(AuthFailureReason.invalidCredentials),
      );
    });

    test('email_not_confirmed → AuthFailureReason.emailNotConfirmed', () {
      final err = sb.AuthException(
        'Email not confirmed',
        code: 'email_not_confirmed',
      );
      expect(
        reasonFromSupabaseError(err),
        equals(AuthFailureReason.emailNotConfirmed),
      );
    });

    test('AuthException with "network" in message → networkError', () {
      final err = sb.AuthException('network error: dns', code: null);
      expect(
        reasonFromSupabaseError(err),
        equals(AuthFailureReason.networkError),
      );
    });

    test('AuthException with "timeout" in message → networkError', () {
      final err = sb.AuthException('Connection timeout', code: null);
      expect(
        reasonFromSupabaseError(err),
        equals(AuthFailureReason.networkError),
      );
    });

    test('AuthException with unknown code falls back to unknown', () {
      final err = sb.AuthException('weird', code: 'some_new_code_supabase');
      expect(reasonFromSupabaseError(err), equals(AuthFailureReason.unknown));
    });
  });

  group('reasonFromSupabaseError - non-Supabase errors', () {
    test('TimeoutException → networkError', () {
      expect(
        reasonFromSupabaseError(TimeoutException('boom')),
        equals(AuthFailureReason.networkError),
      );
    });

    test('arbitrary Exception → unknown', () {
      expect(
        reasonFromSupabaseError(Exception('boom')),
        equals(AuthFailureReason.unknown),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:pack_log/core/auth/auth_exceptions.dart';
import 'package:pack_log/core/database/exceptions/backup_exceptions.dart';
import 'package:pack_log/core/database/exceptions/database_exceptions.dart';
import 'package:pack_log/shared/helpers/exception_message.dart';

class _FakeBackup extends BackupException {
  const _FakeBackup() : super('test');
}

void main() {
  group('exceptionMessageKey - typed AppExceptions', () {
    test('EntitySaveException → errors.save_failed', () {
      expect(
        exceptionMessageKey(const EntitySaveException('addHouse')),
        equals('errors.save_failed'),
      );
    });

    test('EntityNotFoundException → errors.load_failed', () {
      expect(
        exceptionMessageKey(const EntityNotFoundException('getById')),
        equals('errors.load_failed'),
      );
    });

    test('SignInFailedException (default unknown reason) → login.sign_in_failed', () {
      expect(
        exceptionMessageKey(const SignInFailedException('wrong')),
        equals('login.sign_in_failed'),
      );
    });

    test('SignInFailedException (invalidCredentials) → login.invalid_credentials', () {
      expect(
        exceptionMessageKey(
          const SignInFailedException(
            'bad',
            reason: AuthFailureReason.invalidCredentials,
          ),
        ),
        equals('login.invalid_credentials'),
      );
    });

    test('SignInFailedException (emailNotConfirmed) → login.email_not_confirmed', () {
      expect(
        exceptionMessageKey(
          const SignInFailedException(
            'check inbox',
            reason: AuthFailureReason.emailNotConfirmed,
          ),
        ),
        equals('login.email_not_confirmed'),
      );
    });

    test('SignInFailedException (networkError) → login.network_error', () {
      expect(
        exceptionMessageKey(
          const SignInFailedException(
            'no net',
            reason: AuthFailureReason.networkError,
          ),
        ),
        equals('login.network_error'),
      );
    });

    test('SignInFailedException (cancelled) → login.cancelled', () {
      expect(
        exceptionMessageKey(
          const SignInFailedException(
            'user closed sheet',
            reason: AuthFailureReason.cancelled,
          ),
        ),
        equals('login.cancelled'),
      );
    });

    test('SignOutFailedException → login.sign_out_failed', () {
      expect(
        exceptionMessageKey(const SignOutFailedException('net')),
        equals('login.sign_out_failed'),
      );
    });

    test('SessionExpiredException collapses to login.sign_in_failed', () {
      expect(
        exceptionMessageKey(const SessionExpiredException('expired')),
        equals('login.sign_in_failed'),
      );
    });

    test('BackupException → errors.operation_failed', () {
      expect(
        exceptionMessageKey(const _FakeBackup()),
        equals('errors.operation_failed'),
      );
    });
  });

  group('exceptionMessageKey - fallback', () {
    test('Plain Exception → errors.generic', () {
      expect(
        exceptionMessageKey(Exception('boom')),
        equals('errors.generic'),
      );
    });

    test('Arbitrary Object → errors.generic', () {
      expect(exceptionMessageKey('a string error'), equals('errors.generic'));
    });
  });
}

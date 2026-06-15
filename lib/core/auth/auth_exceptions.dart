import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../errors/app_exception.dart';

abstract class AuthDomainException extends AppException {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const AuthDomainException(
    this.message, {
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() =>
      '$runtimeType: $message'
      '${originalError != null ? ' (${originalError.toString()})' : ''}';
}

/// Discriminator semantico per i fallimenti di login. Permette alla UI
/// di mostrare messaggi specifici (credenziali errate vs. email non
/// confermata vs. rete) invece del generico "login fallito".
enum AuthFailureReason {
  /// Email/password non corrispondono a un utente esistente.
  invalidCredentials,

  /// L'utente esiste ma non ha ancora confermato l'email.
  emailNotConfirmed,

  /// Errore di rete/timeout (DNS, server irraggiungibile, ecc.).
  networkError,

  /// L'utente ha annullato il flusso (es. chiusura di Google sign-in).
  cancelled,

  /// Categoria fallback: errore noto a Supabase ma non specificamente mappato,
  /// oppure errore non-Supabase.
  unknown,
}

class SignInFailedException extends AuthDomainException {
  final AuthFailureReason reason;

  const SignInFailedException(
    super.message, {
    this.reason = AuthFailureReason.unknown,
    super.originalError,
    super.stackTrace,
  });
}

class SignUpFailedException extends AuthDomainException {
  const SignUpFailedException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

class SignOutFailedException extends AuthDomainException {
  const SignOutFailedException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

class SessionExpiredException extends AuthDomainException {
  const SessionExpiredException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

/// Mappa un errore generico (tipicamente lanciato dal Supabase SDK durante
/// signIn) al [AuthFailureReason] semantico più aderente.
///
/// Pure function: estratta a parte per essere testabile senza mockare il
/// client Supabase. La policy di mapping include sia il `code` di
/// [sb.AuthException] sia ispezione del `message` per i casi in cui il code
/// non viene fornito (es. timeout di rete).
AuthFailureReason reasonFromSupabaseError(Object error) {
  if (error is sb.AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
      case 'invalid_login_credentials':
      case 'user_not_found':
        return AuthFailureReason.invalidCredentials;
      case 'email_not_confirmed':
        return AuthFailureReason.emailNotConfirmed;
      default:
        final msg = error.message.toLowerCase();
        if (msg.contains('network') || msg.contains('timeout')) {
          return AuthFailureReason.networkError;
        }
        return AuthFailureReason.unknown;
    }
  }
  if (error is TimeoutException) return AuthFailureReason.networkError;
  return AuthFailureReason.unknown;
}

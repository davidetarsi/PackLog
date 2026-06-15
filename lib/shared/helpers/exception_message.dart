import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

import '../../core/auth/auth_exceptions.dart';
import '../../core/database/exceptions/backup_exceptions.dart';
import '../../core/database/exceptions/database_exceptions.dart';

/// Mappa un'eccezione applicativa nota in una chiave i18n user-friendly.
///
/// Pattern: la chiave è raw (non tradotta) così il caller può anche usarla
/// con `tr(args: [...])` se serve interpolazione, o passarla altrove.
String exceptionMessageKey(Object error) {
  if (error is EntitySaveException) return 'errors.save_failed';
  if (error is EntityNotFoundException) return 'errors.load_failed';
  if (error is AppDatabaseException) return 'errors.operation_failed';
  if (error is SignInFailedException) {
    // Discriminator semantico per dare messaggi specifici all'utente
    // (credenziali errate vs. email non confermata vs. rete).
    switch (error.reason) {
      case AuthFailureReason.invalidCredentials:
        return 'login.invalid_credentials';
      case AuthFailureReason.emailNotConfirmed:
        return 'login.email_not_confirmed';
      case AuthFailureReason.networkError:
        return 'login.network_error';
      case AuthFailureReason.cancelled:
        return 'login.cancelled';
      case AuthFailureReason.unknown:
        return 'login.sign_in_failed';
    }
  }
  if (error is SignUpFailedException) return 'login.sign_in_failed';
  if (error is SignOutFailedException) return 'login.sign_out_failed';
  if (error is SessionExpiredException) return 'login.sign_in_failed';
  if (error is BackupException) return 'errors.operation_failed';
  return 'errors.generic';
}

/// Versione user-facing già tradotta. In debug mode, per gli errori non
/// riconosciuti, append il `toString()` per facilitare il triage; in
/// release nasconde sempre i dettagli tecnici.
String exceptionMessage(Object error) {
  final key = exceptionMessageKey(error);
  if (key == 'errors.generic' && kDebugMode) {
    return '${key.tr()}: $error';
  }
  return key.tr();
}

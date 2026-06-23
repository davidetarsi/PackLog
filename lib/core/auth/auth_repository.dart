import 'auth_state.dart';

abstract class AuthRepository {
  AuthState get currentAuthState;

  Stream<AuthState> get authStateChanges;

  Future<void> signInWithGoogle();

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();

  /// GDPR Article 17 — Right to Erasure.
  ///
  /// Cancella HARD tutti i dati dell'utente sul server (via edge function
  /// `hard-delete-account` con `SERVICE_ROLE_KEY`) e l'account `auth.users`
  /// stesso. Effetto irreversibile.
  ///
  /// Lo `user.id` viene preso server-side dal JWT, MAI dal client.
  /// Dopo il completamento, qualsiasi JWT esistente diventa invalido al
  /// prossimo refresh. Il chiamante deve poi:
  ///   1. fare `signOut()` locale per liberare la sessione
  ///   2. invocare `SyncService.wipeAllUserData()` per pulire il DB Drift
  ///   3. navigare l'utente fuori dalle screen autenticate
  ///
  /// Throws [DeleteAccountFailedException] su qualsiasi errore (rete,
  /// 401 JWT scaduto, 500 dal server).
  Future<void> deleteAccount();
}

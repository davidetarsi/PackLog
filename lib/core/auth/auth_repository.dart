import 'auth_state.dart';

abstract class AuthRepository {
  AuthState get currentAuthState;

  Stream<AuthState> get authStateChanges;

  /// Unico metodo di accesso dell'app.
  ///
  /// Un login email/password è stato implementato e poi rimosso (2026-08-01):
  /// per la revisione Play si è scelto di fornire un **account Google di
  /// test** invece di un secondo provider. Vedi `ROADMAP_RILASCIO.md` §2.3 per
  /// la decisione e per il rischio che comporta (il risk engine di Google può
  /// sfidare l'accesso del revisore da IP datacenter).
  Future<void> signInWithGoogle();

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

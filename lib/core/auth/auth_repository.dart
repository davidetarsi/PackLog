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
}

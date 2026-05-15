import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../shared/config/app_config.dart';
import 'auth_exceptions.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

class SupabaseAuthRepository implements AuthRepository {
  final sb.SupabaseClient _client;
  final GoogleSignIn _googleSignIn;

  SupabaseAuthRepository({
    sb.SupabaseClient? client,
    GoogleSignIn? googleSignIn,
  })  : _client = client ?? sb.Supabase.instance.client,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(serverClientId: AppConfig.googleWebClientId);

  @override
  AuthState get currentAuthState {
    final session = _client.auth.currentSession;
    final user = _client.auth.currentUser;
    if (session != null && user != null) {
      return AuthState.authenticated(
        userId: user.id,
        email: user.email ?? '',
      );
    }
    return const AuthState.unauthenticated();
  }

  @override
  Stream<AuthState> get authStateChanges {
    return _client.auth.onAuthStateChange.map((event) {
      final session = event.session;
      final user = session?.user;
      if (session != null && user != null) {
        return AuthState.authenticated(
          userId: user.id,
          email: user.email ?? '',
        );
      }
      return const AuthState.unauthenticated();
    });
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      debugPrint('[Auth] 1/4 avvio Google sign-in...');
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const SignInFailedException('Google sign-in cancelled by user');
      }
      debugPrint('[Auth] 2/4 Google user ottenuto, richiedo tokens...');

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      debugPrint('[Auth] 3/4 Tokens ottenuti, invio a Supabase...');

      if (idToken == null) {
        throw const SignInFailedException(
          'Failed to obtain Google ID token',
        );
      }

      await _client.auth.signInWithIdToken(
        provider: sb.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw const SignInFailedException(
          'Connessione a Supabase scaduta. Controlla la connessione o riprova.',
        ),
      );
      debugPrint('[Auth] 4/4 ✅ Supabase auth completata');
    } on SignInFailedException {
      rethrow;
    } on sb.AuthException catch (e, st) {
      throw SignInFailedException(
        e.message,
        originalError: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw SignInFailedException(
        'Unexpected error during Google sign-in',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on sb.AuthException catch (e, st) {
      throw SignInFailedException(
        e.message,
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
      );
    } on sb.AuthException catch (e, st) {
      throw SignUpFailedException(
        e.message,
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _client.auth.signOut();
    } on sb.AuthException catch (e, st) {
      throw SignOutFailedException(
        e.message,
        originalError: e,
        stackTrace: st,
      );
    }
  }
}

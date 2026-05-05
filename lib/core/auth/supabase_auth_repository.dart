import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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
        _googleSignIn = googleSignIn ?? GoogleSignIn();

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
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const SignInFailedException('Google sign-in cancelled by user');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw const SignInFailedException(
          'Failed to obtain Google ID token',
        );
      }

      await _client.auth.signInWithIdToken(
        provider: sb.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
// `show Supabase`: il package esporta un proprio `AuthState` che collide con
// quello di dominio in `auth_state.dart`.
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/core_analytics_service.dart';
import '../../core/consent/consent_provider.dart';
import '../../core/monitoring/monitoring_service.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
import 'supabase_auth_repository.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return SupabaseAuthRepository();
}

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    final repo = ref.watch(authRepositoryProvider);

    final initial = repo.currentAuthState;
    _resolveIdentity(initial);

    AuthState previous = initial;
    final subscription = repo.authStateChanges.listen((authState) {
      _trackAuthTransition(previous, authState);
      previous = authState;
      state = authState;
      _resolveIdentity(authState);
    });

    ref.onDispose(subscription.cancel);

    return initial;
  }

  /// Aggiorna l'identità utente in Sentry e Amplitude a ogni cambio di stato auth.
  /// Passa SOLO lo userId — niente email o PII (GDPR).
  void _resolveIdentity(AuthState authState) {
    debugPrint('[Auth] _resolveIdentity: $authState');
    switch (authState) {
      case Authenticated(:final userId):
        ref.read(monitoringServiceProvider).identifyUser(userId);
        ref.read(analyticsServiceProvider).identifyUser(userId);
        unawaited(_flushConsentToRemote());
      case Unauthenticated():
        ref.read(monitoringServiceProvider).clearUser();
        ref.read(analyticsServiceProvider).clearUser();
    }
    debugPrint('[Auth] _resolveIdentity completato');
  }

  /// Riversa su Supabase il consenso registrato in locale.
  ///
  /// Non può avvenire quando il consenso viene prestato: in quel momento non
  /// esiste ancora una sessione autenticata né la riga in `public.users`
  /// (creata dal trigger `on_auth_user_created`), e la RPC richiede
  /// `auth.uid()`. Il primo login utile è quindi la prima occasione possibile.
  ///
  /// Viene trasmesso il timestamp **originale** della spunta, non quello di
  /// adesso: il registro deve dire quando il consenso è stato prestato.
  ///
  /// Errori assorbiti: se la RPC fallisce (rete assente, riga non ancora
  /// creata) il flag locale resta non sincronizzato e si riprova al login
  /// successivo. La RPC è idempotente, quindi ripetere non fa danno.
  Future<void> _flushConsentToRemote() async {
    final consent = ref.read(consentServiceProvider);
    if (!consent.needsRemoteFlush) return;

    final givenAt = consent.givenAt;
    if (givenAt == null) return;

    try {
      await Supabase.instance.client.rpc(
        'record_consent',
        params: {
          'p_given_at': givenAt.toIso8601String(),
          'p_policy_version': consent.policyVersion,
        },
      );
      await consent.markSyncedRemote();
      debugPrint('[Auth] consenso registrato su Supabase');
    } catch (e) {
      debugPrint(
        '[Auth] flush consenso fallito (riprovo al prossimo login): $e',
      );
    }
  }

  /// Traccia il funnel di attivazione: emette `login_completed` alla prima
  /// transizione Unauthenticated → Authenticated, e `logout` alla transizione
  /// inversa. Idempotente sugli "stessi stati ripetuti".
  void _trackAuthTransition(AuthState prev, AuthState next) {
    final analytics = ref.read(coreAnalyticsServiceProvider);
    if (next is Authenticated && prev is! Authenticated) {
      analytics.trackLoginCompleted();
    } else if (next is Unauthenticated && prev is Authenticated) {
      analytics.trackLogout();
    }
  }
}

/// User ID dell'utente loggato, nullable.
/// La responsabilità di gestire il caso null spetta al chiamante.
@Riverpod(keepAlive: true)
String? currentUserId(Ref ref) {
  final authState = ref.watch(authNotifierProvider);
  return switch (authState) {
    Authenticated(:final userId) => userId,
    Unauthenticated() => null,
  };
}

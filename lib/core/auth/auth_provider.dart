import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/analytics/analytics_service.dart';
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

    final subscription = repo.authStateChanges.listen((authState) {
      state = authState;
      _resolveIdentity(authState);
    });

    ref.onDispose(subscription.cancel);

    return initial;
  }

  /// Aggiorna l'identità utente in Sentry e Amplitude a ogni cambio di stato auth.
  /// Passa SOLO lo userId — niente email o PII (GDPR).
  void _resolveIdentity(AuthState authState) {
    switch (authState) {
      case Authenticated(:final userId):
        ref.read(monitoringServiceProvider).identifyUser(userId);
        ref.read(analyticsServiceProvider).identifyUser(userId);
      case Unauthenticated():
        ref.read(monitoringServiceProvider).clearUser();
        ref.read(analyticsServiceProvider).clearUser();
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

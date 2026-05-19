import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_state.freezed.dart';

@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.authenticated({
    required String userId,
    required String email,
  }) = Authenticated;

  const factory AuthState.unauthenticated() = Unauthenticated;
}

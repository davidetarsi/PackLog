import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/auth/auth_provider.dart';
import 'package:pack_log/core/auth/auth_repository.dart';
import 'package:pack_log/core/auth/auth_state.dart';

import '../../helpers/mock_analytics.dart';
import '../../helpers/mock_monitoring.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  group('AuthNotifier', () {
    test('returns initial auth state from repository', () {
      const expected = AuthState.authenticated(
        userId: 'user-1',
        email: 'test@test.com',
      );
      when(() => mockRepo.currentAuthState).thenReturn(expected);
      when(
        () => mockRepo.authStateChanges,
      ).thenAnswer((_) => const Stream.empty());

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockRepo),
          ...mockAnalyticsOverrides(),
          ...mockMonitoringOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(authNotifierProvider);
      expect(state, equals(expected));
    });

    test('includes displayName from repository state', () {
      const expected = AuthState.authenticated(
        userId: 'user-3',
        email: 'name@test.com',
        displayName: 'Mario Rossi',
      );
      when(() => mockRepo.currentAuthState).thenReturn(expected);
      when(
        () => mockRepo.authStateChanges,
      ).thenAnswer((_) => const Stream.empty());

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockRepo),
          ...mockAnalyticsOverrides(),
          ...mockMonitoringOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(authNotifierProvider);
      expect(state, equals(expected));
      expect((state as Authenticated).displayName, equals('Mario Rossi'));
    });

    test('updates state when auth stream emits', () async {
      final controller = StreamController<AuthState>.broadcast();
      when(
        () => mockRepo.currentAuthState,
      ).thenReturn(const AuthState.unauthenticated());
      when(
        () => mockRepo.authStateChanges,
      ).thenAnswer((_) => controller.stream);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockRepo),
          ...mockAnalyticsOverrides(),
          ...mockMonitoringOverrides(),
        ],
      );
      addTearDown(() {
        container.dispose();
        controller.close();
      });

      expect(container.read(authNotifierProvider), isA<Unauthenticated>());

      const authenticated = AuthState.authenticated(
        userId: 'user-2',
        email: 'new@test.com',
      );
      controller.add(authenticated);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authNotifierProvider), equals(authenticated));
    });
  });

  group('currentUserId', () {
    test('returns userId when authenticated', () {
      const state = AuthState.authenticated(
        userId: 'abc-123',
        email: 'test@test.com',
      );
      when(() => mockRepo.currentAuthState).thenReturn(state);
      when(
        () => mockRepo.authStateChanges,
      ).thenAnswer((_) => const Stream.empty());

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockRepo),
          ...mockAnalyticsOverrides(),
          ...mockMonitoringOverrides(),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(currentUserIdProvider), equals('abc-123'));
    });

    test('returns null when unauthenticated', () {
      when(
        () => mockRepo.currentAuthState,
      ).thenReturn(const AuthState.unauthenticated());
      when(
        () => mockRepo.authStateChanges,
      ).thenAnswer((_) => const Stream.empty());

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockRepo),
          ...mockAnalyticsOverrides(),
          ...mockMonitoringOverrides(),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(currentUserIdProvider), isNull);
    });
  });
}

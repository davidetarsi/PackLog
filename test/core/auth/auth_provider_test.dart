import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/core/auth/auth_provider.dart';
import 'package:pack_log/core/auth/auth_repository.dart';
import 'package:pack_log/core/auth/auth_state.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/core/sync/sync_session.dart';
import 'package:pack_log/features/items/providers/item_metadata_service_provider.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/items/services/item_metadata_backfill.dart';
import 'package:pack_log/features/items/services/item_metadata_service.dart';

import '../../helpers/mock_analytics.dart';
import '../../helpers/mock_monitoring.dart';
import '../../helpers/prepared_sync_orchestrator.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class _RecordingBackfill extends ItemMetadataBackfill {
  _RecordingBackfill(PreparedSyncOrchestrator orchestrator)
    : super(
        repository: MockItemRepository(),
        service: ItemMetadataService(url: '', anonKey: ''),
        orchestrator: orchestrator,
      );

  final contexts = <Object>[];

  @override
  Future<Set<String>> run(SyncSessionContext context) async {
    contexts.add(context);
    return const {};
  }
}

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

    test(
      'avvia il backfill solo dopo un trigger con sessione preparata',
      () async {
        final controller = StreamController<AuthState>.broadcast();
        when(
          () => mockRepo.currentAuthState,
        ).thenReturn(const AuthState.unauthenticated());
        when(
          () => mockRepo.authStateChanges,
        ).thenAnswer((_) => controller.stream);
        final sync = PreparedSyncOrchestrator(userId: null, ready: false);
        final backfill = _RecordingBackfill(sync);
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepo),
            syncOrchestratorProvider.overrideWithValue(sync),
            itemMetadataBackfillProvider.overrideWithValue(backfill),
            ...mockAnalyticsOverrides(),
            ...mockMonitoringOverrides(),
          ],
        );
        addTearDown(() {
          container.dispose();
          controller.close();
        });

        container.read(authNotifierProvider);
        controller.add(
          const AuthState.authenticated(userId: 'user-1', email: 'x'),
        );
        await Future<void>.delayed(Duration.zero);
        container.read(syncTriggerProvider.notifier).increment();
        await Future<void>.delayed(Duration.zero);
        expect(backfill.contexts, isEmpty);

        await sync.replaceSession(
          'user-1',
          prepareLocalData: () async => false,
        );
        container.read(syncTriggerProvider.notifier).increment();
        await Future<void>.delayed(Duration.zero);
        expect(backfill.contexts, hasLength(1));
      },
    );

    // Regressione: `login_completed` veniva emesso sia qui sia in LoginScreen,
    // raddoppiando il conteggio del funnel. Questa transizione scatta anche al
    // riavvio con sessione ripristinata, che non è un login — quindi
    // l'emissione vive solo in LoginScreen, sul tap dell'utente.
    test(
      'non emette login_completed sulla transizione verso Authenticated',
      () async {
        final controller = StreamController<AuthState>.broadcast();
        final analytics = MockAnalyticsService();
        when(
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        ).thenAnswer((_) async {});
        when(() => analytics.identifyUser(any())).thenReturn(null);
        when(() => analytics.clearUser()).thenReturn(null);

        when(
          () => mockRepo.currentAuthState,
        ).thenReturn(const AuthState.unauthenticated());
        when(
          () => mockRepo.authStateChanges,
        ).thenAnswer((_) => controller.stream);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepo),
            analyticsServiceProvider.overrideWithValue(analytics),
            ...mockMonitoringOverrides(),
          ],
        );
        addTearDown(() {
          container.dispose();
          controller.close();
        });

        container.read(authNotifierProvider);

        controller.add(
          const AuthState.authenticated(userId: 'u1', email: 'a@b.c'),
        );
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => analytics.logEvent(
            'login_completed',
            properties: any(named: 'properties'),
          ),
        );

        // `logout` invece resta responsabilità di questa transizione.
        controller.add(const AuthState.unauthenticated());
        await Future<void>.delayed(Duration.zero);

        verify(() => analytics.logEvent('logout', properties: null)).called(1);
      },
    );
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

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/core/sync/sync_service.dart';
import 'package:pack_log/core/auth/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSyncService extends Mock implements SyncService {}

class _Preferences extends Mock implements SharedPreferences {}

void main() {
  late MockSyncService mockSyncService;
  late List<String> order;

  setUp(() {
    mockSyncService = MockSyncService();
    order = [];
    when(() => mockSyncService.wipeAllUserData()).thenAnswer((_) async {
      order.add('wipe');
    });
  });

  Future<void> handle(String userId, SharedPreferences prefs) async {
    await handleAuthenticatedUser(
      userId: userId,
      syncService: mockSyncService,
      getPreferences: () async => prefs,
      replaceSession: (prepare) async {
        order.add('replace');
        final needsRestore = await prepare();
        order.add('prepared:$needsRestore');
      },
    );
  }

  test('auth A to auth B is a direct owner replacement', () {
    final result = authSessionReplacement(
      const AuthState.authenticated(userId: 'A', email: 'a@example.test'),
      const AuthState.authenticated(userId: 'B', email: 'b@example.test'),
    );
    expect(result.changed, isTrue);
    expect(result.userId, 'B');
  });

  test('same authenticated owner does not replace its session', () {
    final result = authSessionReplacement(
      const AuthState.authenticated(userId: 'A', email: 'a@example.test'),
      const AuthState.authenticated(userId: 'A', email: 'a@example.test'),
    );
    expect(result.changed, isFalse);
  });

  group('handleAuthenticatedUser - account switch detection', () {
    test('a marker that cannot be persisted prevents wipe/ready', () async {
      final prefs = _Preferences();
      when(() => prefs.getString(kLastKnownUserIdKey)).thenReturn('user-A');
      when(
        () => prefs.setBool(pendingRestoreUserKey('user-B'), true),
      ).thenAnswer((_) async => false);
      var preparationFailed = false;

      await expectLater(
        handleAuthenticatedUser(
          userId: 'user-B',
          syncService: mockSyncService,
          getPreferences: () async => prefs,
          replaceSession: (prepare) async {
            try {
              await prepare();
            } catch (_) {
              preparationFailed = true;
              rethrow;
            }
          },
        ),
        throwsStateError,
      );

      expect(preparationFailed, isTrue);
      verifyNever(() => mockSyncService.wipeAllUserData());
    });

    test(
      'first login does not wipe and remains unconfirmed until pull',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await handle('user-A', prefs);

        verifyNever(() => mockSyncService.wipeAllUserData());
        expect(order, ['replace', 'prepared:true']);
        expect(prefs.getString(kLastKnownUserIdKey), equals('user-A'));
        expect(prefs.getBool(pendingRestoreUserKey('user-A')), isTrue);
      },
    );

    test('same user re-login does not wipe', () async {
      SharedPreferences.setMockInitialValues({kLastKnownUserIdKey: 'user-A'});
      final prefs = await SharedPreferences.getInstance();

      await handle('user-A', prefs);

      verifyNever(() => mockSyncService.wipeAllUserData());
      expect(order, ['replace', 'prepared:false']);
    });

    test(
      'switch marks restore before wipe and then prepares new owner',
      () async {
        SharedPreferences.setMockInitialValues({kLastKnownUserIdKey: 'user-A'});
        final prefs = await SharedPreferences.getInstance();

        await handle('user-B', prefs);

        verify(() => mockSyncService.wipeAllUserData()).called(1);
        expect(order, ['replace', 'wipe', 'prepared:true']);
        expect(prefs.getString(kLastKnownUserIdKey), equals('user-B'));
        expect(prefs.getBool(pendingRestoreUserKey('user-B')), isTrue);
      },
    );

    test(
      'restart retains pending restore until matching pull succeeds',
      () async {
        SharedPreferences.setMockInitialValues({
          kLastKnownUserIdKey: 'user-B',
          'sync.pending_full_pull.user-B': true,
        });
        final prefs = await SharedPreferences.getInstance();

        await handle('user-B', prefs);

        verifyNever(() => mockSyncService.wipeAllUserData());
        expect(order, ['replace', 'prepared:true']);
        expect(prefs.getBool(pendingRestoreUserKey('user-B')), isTrue);
      },
    );
  });
}

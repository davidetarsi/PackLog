import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/core/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSyncService extends Mock implements SyncService {}

void main() {
  late MockSyncService mockSyncService;
  late List<String> fullPullCalls;

  setUp(() {
    mockSyncService = MockSyncService();
    fullPullCalls = [];
    when(() => mockSyncService.wipeAllUserData()).thenAnswer((_) async {});
  });

  group('handleAuthenticatedUser - account switch detection', () {
    test('first login (no prior userId) only triggers fullPull, no wipe', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await handleAuthenticatedUser(
        userId: 'user-A',
        syncService: mockSyncService,
        requestFullPull: fullPullCalls.add,
        prefs: prefs,
      );

      verifyNever(() => mockSyncService.wipeAllUserData());
      expect(fullPullCalls, equals(['user-A']));
      expect(prefs.getString(kLastKnownUserIdKey), equals('user-A'));
    });

    test('same user re-logging in does not trigger wipe', () async {
      SharedPreferences.setMockInitialValues({
        kLastKnownUserIdKey: 'user-A',
      });
      final prefs = await SharedPreferences.getInstance();

      await handleAuthenticatedUser(
        userId: 'user-A',
        syncService: mockSyncService,
        requestFullPull: fullPullCalls.add,
        prefs: prefs,
      );

      verifyNever(() => mockSyncService.wipeAllUserData());
      expect(fullPullCalls, equals(['user-A']));
    });

    test('different user triggers wipe before fullPull', () async {
      SharedPreferences.setMockInitialValues({
        kLastKnownUserIdKey: 'user-A',
      });
      final prefs = await SharedPreferences.getInstance();

      await handleAuthenticatedUser(
        userId: 'user-B',
        syncService: mockSyncService,
        requestFullPull: fullPullCalls.add,
        prefs: prefs,
      );

      verify(() => mockSyncService.wipeAllUserData()).called(1);
      expect(fullPullCalls, equals(['user-B']));
      expect(prefs.getString(kLastKnownUserIdKey), equals('user-B'));
    });
  });
}

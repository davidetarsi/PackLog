import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/core/sync/sync_service.dart';

class _Service extends Mock implements SyncService {}

class _Connectivity extends Mock implements Connectivity {}

class _Monitoring extends Mock implements AppMonitoringService {}

void main() {
  test(
    'derived pull flag uses owner snapshot before stream data arrives',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final service = _Service();
      final connectivity = _Connectivity();
      final monitoring = _Monitoring();
      final pullStarted = Completer<void>();
      final finishPull = Completer<void>();

      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.wifi]);
      when(() => service.fullPull('user')).thenAnswer((_) {
        pullStarted.complete();
        return finishPull.future;
      });
      when(() => service.countPendingChanges()).thenAnswer((_) async => 0);

      final orchestrator = SyncOrchestrator(
        service,
        monitoring,
        connectivity: connectivity,
      );
      orchestrator.requestFullPull('user');
      await pullStarted.future;

      final container = ProviderContainer(
        overrides: [
          syncOrchestratorProvider.overrideWith((ref) => orchestrator),
        ],
      );
      expect(container.read(syncingProvider), isTrue);
      expect(container.read(syncPushInProgressProvider), isFalse);

      finishPull.complete();
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      orchestrator.dispose();
    },
  );
}

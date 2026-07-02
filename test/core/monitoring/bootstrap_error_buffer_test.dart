import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/monitoring/bootstrap_error_buffer.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';

class MockMonitoringService extends Mock implements AppMonitoringService {}

void main() {
  test('record accumula e flush invia con tag source/phase, poi svuota', () {
    final buffer = BootstrapErrorBuffer();
    final monitoring = MockMonitoringService();
    final err = StateError('db corrotto');
    final stack = StackTrace.current;

    buffer.record('persistence', err, stack);
    buffer.record('auto_backup', Exception('disk full'), stack);
    expect(buffer.length, 2);

    buffer.flush(monitoring);

    verify(
      () => monitoring.captureException(
        err,
        stackTrace: stack,
        tags: {'source': 'bootstrap', 'phase': 'persistence'},
      ),
    ).called(1);
    verify(
      () => monitoring.captureException(
        any(that: isA<Exception>()),
        stackTrace: stack,
        tags: {'source': 'bootstrap', 'phase': 'auto_backup'},
      ),
    ).called(1);
    expect(buffer.length, 0);

    // Flush su buffer vuoto: no-op, nessuna chiamata ulteriore.
    buffer.flush(monitoring);
    verifyNoMoreInteractions(monitoring);
  });
}

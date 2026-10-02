import 'monitoring_service.dart';

/// Buffer per eccezioni avvenute prima che Sentry sia inizializzato.
///
/// Il bootstrap è deferito (anti-ANR): Sentry parte DOPO la persistenza
/// (migrazione DB, SQLCipher, backup). Un'eccezione in quella finestra
/// andrebbe persa — Sentry pre-init è un no-op e in release anche
/// `debugPrint` è silenziato. Qui la accumuliamo; il bootstrap la flusha
/// appena l'init di Sentry completa.
class BootstrapErrorBuffer {
  final List<({String phase, Object error, StackTrace stack})> _entries = [];

  int get length => _entries.length;

  void record(String phase, Object error, StackTrace stack) {
    _entries.add((phase: phase, error: error, stack: stack));
  }

  /// Invia tutti gli errori bufferizzati tramite [monitoring] e svuota.
  void flush(AppMonitoringService monitoring) {
    for (final entry in _entries) {
      monitoring.captureException(
        entry.error,
        stackTrace: entry.stack,
        tags: {'source': 'bootstrap', 'phase': entry.phase},
      );
    }
    _entries.clear();
  }
}

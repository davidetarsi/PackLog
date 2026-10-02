import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

part 'monitoring_service.g.dart';

class AppMonitoringService {
  void identifyUser(String userId) {
    Sentry.configureScope((scope) => scope.setUser(SentryUser(id: userId)));
  }

  void clearUser() {
    Sentry.configureScope((scope) => scope.setUser(null));
  }

  void logBreadcrumb(
    String message, {
    String category = 'sync',
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        data: data,
        level: SentryLevel.info,
      ),
    );
  }

  /// Invia un'eccezione a Sentry con contesto opzionale.
  ///
  /// [level] permette di classificare la gravità: usare [SentryLevel.fatal]
  /// per errori che indicano stato inconsistente del database (es. rollback
  /// fallito), [SentryLevel.error] per i casi standard.
  ///
  /// [tags] aggiunge coppie chiave-valore visibili nel pannello Sentry
  /// per facilitare il filtraggio (es. `{'operation': 'deleteHouse'}`).
  ///
  /// ## Convenzione sulle tag e PII
  /// Le tag finiscono nel pannello Sentry visibile in ricerca/breadcrumb,
  /// quindi DEVONO restare PII-free. Le chiavi `*_id` (es. `item_id`,
  /// `house_id`, `trip_id`) sono OK perché sono UUID v4 generati dal client
  /// → non riconducibili a un utente per ispezione diretta.
  ///
  /// **NON** mettere in [tags]: email, displayName, nomi reali, numeri di
  /// telefono, contenuto di campi di input utente (es. nome casa,
  /// descrizione item). Il filtraggio per quei campi non vale il rischio
  /// di leak in caso di breach del progetto Sentry.
  ///
  /// L'identità utente è già nello scope Sentry come `user.id` (UUID
  /// `auth.users`) — vedi [identifyUser]. Non duplicarla in tag.
  void captureException(
    Object exception, {
    StackTrace? stackTrace,
    SentryLevel level = SentryLevel.error,
    Map<String, String>? tags,
  }) {
    Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.level = level;
        tags?.forEach(scope.setTag);
      },
    );
  }

  String generateTraceId() => const Uuid().v4().replaceAll('-', '');
}

@Riverpod(keepAlive: true)
AppMonitoringService monitoringService(Ref ref) => AppMonitoringService();

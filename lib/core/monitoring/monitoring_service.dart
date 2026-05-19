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

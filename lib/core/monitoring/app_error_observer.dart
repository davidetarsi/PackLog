import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../database/exceptions/database_exceptions.dart';

class AppErrorObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (newValue is! AsyncError) return;

    final error = newValue.error;
    final providerName = provider.name ?? provider.runtimeType.toString();
    const level = SentryLevel.error;

    Sentry.captureException(
      error,
      stackTrace: newValue.stackTrace,
      withScope: (scope) {
        scope.level = level;
        scope.setTag('provider', providerName);
        scope.setTag('source', 'provider_observer');
        if (error is AppDatabaseException) {
          scope.setTag('db_operation', error.operation);
        }
      },
    );
  }
}

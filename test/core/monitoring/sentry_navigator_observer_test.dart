import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class _Hub extends Mock implements Hub {}

void main() {
  test('niente transazioni automatiche: solo le schermate negli errori', () {
    final options = SentryFlutterOptions(dsn: 'https://k@o.ingest.sentry.io/1');
    final hub = _Hub();
    // `options` è interno a Sentry; qui serve solo a leggere cosa l'observer
    // ha registrato.
    // ignore: invalid_use_of_internal_member
    when(() => hub.options).thenReturn(options);

    appSentryNavigatorObserver(hub: hub);

    // Con le transazioni automatiche accese l'observer registra questa
    // integrazione, e ogni cambio di schermata consuma quota performance.
    expect(options.sdk.integrations, isNot(contains('UINavigationTracing')));
  });
}

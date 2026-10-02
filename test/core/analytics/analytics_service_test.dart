import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:tgram_analytics/tgram_analytics.dart';

/// Copre le due guardie del sink tgram in [AppAnalyticsService].
///
/// Il valore di questi test non è "l'evento arriva" (servirebbe un server),
/// ma l'invariante opposta: **finché tgram non è inizializzato non deve
/// succedere nulla**. È la protezione contro il pre-init buffering dell'SDK,
/// che in flavor dev — dove `TGA.init()` non viene mai chiamato — farebbe
/// crescere un buffer in memoria a ogni evento tracciato.
void main() {
  setUp(TGA.reset);
  tearDown(TGA.reset);

  group('sink tgram disattivo (sessionId null)', () {
    test('i tre metodi non lanciano e non inizializzano tgram', () async {
      final service = AppAnalyticsService(null);

      await service.logEvent('house_created', properties: {'house_id': 'h1'});
      service.identifyUser('user-1');
      service.clearUser();

      expect(TGA.isInitialized, isFalse);
    });
  });

  group('sink tgram con sessionId ma TGA non inizializzato', () {
    test('non bufferizza: TGA resta non inizializzato', () async {
      final service = AppAnalyticsService(null, tgramSessionId: 'session-abc');

      await service.logEvent('item_added', properties: {'count': 3});
      service.identifyUser('user-1');
      service.clearUser();

      // Se la guardia `!TGA.isInitialized` sparisse, queste chiamate
      // finirebbero nel buffer interno dell'SDK invece di essere scartate.
      expect(TGA.isInitialized, isFalse);
      expect(TGA.instance, isNull);
    });

    test('properties non serializzabili non propagano l\'eccezione', () async {
      final service = AppAnalyticsService(null, tgramSessionId: 'session-abc');

      // Map annidata: TGA.track lancerebbe ArgumentError se mai raggiunto.
      // L'app non deve rompersi comunque — le analytics sono best-effort.
      await expectLater(
        service.logEvent('weird', properties: {'nested': <String, int>{}}),
        completes,
      );
    });
  });
}

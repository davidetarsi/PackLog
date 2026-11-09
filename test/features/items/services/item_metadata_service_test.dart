import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/features/items/services/item_metadata_service.dart';

class _MockAnalytics extends Mock implements CoreAnalyticsService {}

class _MockMonitoring extends Mock implements AppMonitoringService {}

void main() {
  group('ItemMetadataService.fromName: tetti ed errori', () {
    late _MockAnalytics analytics;
    late _MockMonitoring monitoring;

    setUp(() {
      analytics = _MockAnalytics();
      monitoring = _MockMonitoring();
    });

    ItemMetadataService serviceAnswering(
      Future<http.Response> Function() answer,
    ) => ItemMetadataService(
      url: 'https://fake.supabase.co/functions/v1/item-metadata',
      anonKey: 'anon',
      jwtProvider: () => 'jwt',
      client: MockClient((_) => answer()),
      analytics: analytics,
      monitoring: monitoring,
    );

    void verifyNoSentry() => verifyNever(
      () => monitoring.captureException(
        any(),
        stackTrace: any(named: 'stackTrace'),
        tags: any(named: 'tags'),
      ),
    );

    test('429: ai_limit_reached, niente Sentry, risultato null', () async {
      final service = serviceAnswering(() async => http.Response('{}', 429));
      expect(await service.fromName('felpa'), isNull);
      verify(
        () => analytics.trackAiLimitReached(feature: 'item_name'),
      ).called(1);
      verifyNoSentry();
    });

    test('500: in Sentry con lo stato', () async {
      final service = serviceAnswering(() async => http.Response('{}', 500));
      expect(await service.fromName('felpa'), isNull);
      verify(
        () => monitoring.captureException(
          any(),
          stackTrace: any(named: 'stackTrace'),
          tags: {'operation': 'item_metadata', 'status': '500'},
        ),
      ).called(1);
      verifyNever(
        () => analytics.trackAiLimitReached(feature: any(named: 'feature')),
      );
    });

    test('rete assente: né evento né Sentry', () async {
      final service = serviceAnswering(
        () async => throw http.ClientException('offline'),
      );
      expect(await service.fromName('felpa'), isNull);
      verifyNoSentry();
      verifyNever(
        () => analytics.trackAiLimitReached(feature: any(named: 'feature')),
      );
    });

    test('risposta illeggibile: in Sentry, senza il corpo', () async {
      // Il corpo può ripetere il nome scritto dall'utente.
      final service = serviceAnswering(
        () async => http.Response('felpa grigia di Marta', 200),
      );
      expect(await service.fromName('felpa'), isNull);
      final sent = verify(
        () => monitoring.captureException(
          captureAny(),
          stackTrace: any(named: 'stackTrace'),
          tags: {'operation': 'item_metadata'},
        ),
      ).captured.single;
      expect(sent, isA<ItemMetadataParseException>());
      expect('$sent', isNot(contains('Marta')));
    });
  });

  group('ItemMetadataService.fromName', () {
    Future<Map<String, dynamic>> bodyFor({String Function()? language}) async {
      late http.Request request;
      final service = ItemMetadataService(
        url: 'https://fake.supabase.co/functions/v1/item-metadata',
        anonKey: 'anon',
        jwtProvider: () => 'jwt',
        language: language,
        client: MockClient((req) async {
          request = req;
          return http.Response(jsonEncode({'items': []}), 200);
        }),
      );
      await service.fromName('  felpa grigia ');
      return jsonDecode(request.body) as Map<String, dynamic>;
    }

    test('manda il nome e la lingua dell\'app', () async {
      expect(await bodyFor(language: () => 'en'), {
        'name': 'felpa grigia',
        'lang': 'en',
      });
    });

    test('senza lingua indicata manda l\'italiano', () async {
      expect((await bodyFor())['lang'], 'it');
    });
  });
}

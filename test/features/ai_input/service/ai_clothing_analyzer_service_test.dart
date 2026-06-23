import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_exception.dart';
import 'package:pack_log/features/ai_input/service/ai_clothing_analyzer_service.dart';

/// Wraps a content string in the minimal OpenAI response envelope.
String _openAiResponse(String content) => jsonEncode({
  'choices': [
    {'message': {'content': content}},
  ],
});

File _fakeImageFile() {
  final f = File('${Directory.systemTemp.path}/test_img.png')
    ..writeAsBytesSync(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]));
  return f;
}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockAppMonitoringService extends Mock implements AppMonitoringService {}

AiClothingAnalyzerService _makeService(
  http.Client mockClient, {
  CoreAnalyticsService? analytics,
  AppMonitoringService? monitoring,
}) => AiClothingAnalyzerService(
  proxyUrl: 'https://fake.supabase.co/functions/v1/openai-proxy',
  anonKey: 'fake-anon-key',
  client: mockClient,
  jwtProvider: () => 'fake-jwt-token',
  analytics: analytics,
  monitoring: monitoring,
);

void main() {
  group('AiClothingAnalyzerService', () {
    test('throws GptLimitExceededException on HTTP 429', () async {
      final service = _makeService(
        MockClient(
          (_) async =>
              http.Response('{"error":"Monthly GPT limit reached"}', 429),
        ),
      );

      await expectLater(
        service.processClothingItem(_fakeImageFile()),
        throwsA(isA<GptLimitExceededException>()),
      );
    });

    test('throws VisionAnalysisException on HTTP 500', () async {
      final service = _makeService(
        MockClient((_) async => http.Response('{"error":"internal"}', 500)),
      );

      await expectLater(
        service.processClothingItem(_fakeImageFile()),
        throwsA(isA<VisionAnalysisException>()),
      );
    });

    test(
      'throws VisionAnalysisException on HTTP 503 (OpenAI upstream rate limit)',
      () async {
        final service = _makeService(
          MockClient(
            (_) async => http.Response('{"error":"Service unavailable"}', 503),
          ),
        );

        await expectLater(
          service.processClothingItem(_fakeImageFile()),
          throwsA(isA<VisionAnalysisException>()),
        );
      },
    );

    test(
      'throws VisionAnalysisException when jwtProvider returns null',
      () async {
        final service = AiClothingAnalyzerService(
          proxyUrl: 'https://fake.supabase.co/functions/v1/openai-proxy',
          anonKey: 'fake-anon-key',
          jwtProvider: () => null,
        );

        await expectLater(
          service.processClothingItem(_fakeImageFile()),
          throwsA(isA<VisionAnalysisException>()),
        );
      },
    );

    group('processClothingItem — success and parsing', () {
      const _validItemsJson =
          '[{"name":"T-Shirt","category":"Upper Body","subCategory":"T-Shirt","baseColor":"Bianco",'
          '"pattern":"Solid","coverage":"Short-sleeve","fit":"Regular",'
          '"warmth":2,"formality":"Casual","activityTags":["Everyday"]}]';

      test('returns correct ClothingItem list from valid JSON response',
          () async {
        final service = _makeService(
          MockClient(
            (_) async =>
                http.Response(_openAiResponse(_validItemsJson), 200),
          ),
        );

        final items = await service.processClothingItem(_fakeImageFile());

        expect(items, hasLength(1));
        expect(items.first.name, 'T-Shirt');
        expect(items.first.category, 'Upper Body');
        expect(items.first.subCategory, 'T-Shirt');
        expect(items.first.baseColor, 'Bianco');
        expect(items.first.warmth, 2);
        expect(items.first.activityTags, ['Everyday']);
      });

      test('strips markdown fences from content before parsing', () async {
        // GPT sometimes wraps its JSON output in ```json ... ``` fences.
        const fencedContent = '```json\n$_validItemsJson\n```';
        final service = _makeService(
          MockClient(
            (_) async =>
                http.Response(_openAiResponse(fencedContent), 200),
          ),
        );

        final items = await service.processClothingItem(_fakeImageFile());

        expect(items, hasLength(1));
        expect(items.first.name, 'T-Shirt');
      });

      test('throws ResponseParsingException on malformed JSON content',
          () async {
        final service = _makeService(
          MockClient(
            (_) async =>
                http.Response(_openAiResponse('not valid json'), 200),
          ),
        );

        await expectLater(
          service.processClothingItem(_fakeImageFile()),
          throwsA(isA<ResponseParsingException>()),
        );
      });

      test(
          'throws ResponseParsingException when choices array is empty',
          () async {
        final service = _makeService(
          MockClient(
            (_) async =>
                http.Response(jsonEncode({'choices': []}), 200),
          ),
        );

        await expectLater(
          service.processClothingItem(_fakeImageFile()),
          throwsA(isA<ResponseParsingException>()),
        );
      });
    });

    group('Body sent to proxy', () {
      test(
        'envia SOLO image_base64, niente model/messages/max_tokens/prompt',
        () async {
          http.Request? capturedRequest;
          final service = _makeService(
            MockClient((req) async {
              capturedRequest = req;
              return http.Response(
                _openAiResponse('[{"name":"T","category":"Upper Body",'
                    '"subCategory":"T-Shirt","baseColor":"Bianco",'
                    '"pattern":"Solid","coverage":"Short-sleeve",'
                    '"fit":"Regular","warmth":2,"formality":"Casual",'
                    '"activityTags":["Everyday"]}]'),
                200,
              );
            }),
          );

          await service.processClothingItem(_fakeImageFile());

          expect(capturedRequest, isNotNull);
          final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
          // Solo image_base64. Tutto il resto è server-side.
          expect(body.keys, ['image_base64']);
          expect(body['image_base64'], isA<String>());
          expect((body['image_base64'] as String).isNotEmpty, true);
          // Difese esplicite contro regressioni: se qualcuno reintroduce
          // questi campi, l'utente potrebbe iniettarli e bypassare il
          // controllo server-side.
          expect(body.containsKey('model'), false);
          expect(body.containsKey('messages'), false);
          expect(body.containsKey('max_tokens'), false);
          expect(body.containsKey('temperature'), false);
        },
      );
    });

    group('processClothingItem — auth and network', () {
      test('throws VisionAnalysisException on empty JWT string', () async {
        final service = AiClothingAnalyzerService(
          proxyUrl: 'https://fake.supabase.co/functions/v1/openai-proxy',
          anonKey: 'fake-anon-key',
          jwtProvider: () => '',
        );

        await expectLater(
          service.processClothingItem(_fakeImageFile()),
          throwsA(isA<VisionAnalysisException>()),
        );
      });

      test('throws VisionAnalysisException on socket/network error', () async {
        final service = _makeService(
          MockClient(
            (_) async => throw const SocketException('Network unreachable'),
          ),
        );

        await expectLater(
          service.processClothingItem(_fakeImageFile()),
          throwsA(isA<VisionAnalysisException>()),
        );
      });
    });

    group('Analytics tracking', () {
      late MockCoreAnalyticsService mockAnalytics;
      late MockAppMonitoringService mockMonitoring;

      const validOpenAiResponse = '''
{
  "choices": [{
    "message": {
      "content": "[{\\"name\\": \\"T-Shirt\\", \\"category\\": \\"Upper Body\\", \\"subCategory\\": \\"T-Shirt\\", \\"baseColor\\": \\"Bianco\\", \\"pattern\\": \\"Solid\\", \\"coverage\\": \\"Short-sleeve\\", \\"fit\\": \\"Regular\\", \\"warmth\\": 2, \\"formality\\": \\"Casual\\", \\"activityTags\\": [\\"Everyday\\"]}]"
    }
  }]
}
''';

      setUp(() {
        mockAnalytics = MockCoreAnalyticsService();
        mockMonitoring = MockAppMonitoringService();
        when(() => mockAnalytics.trackAiInputSubmitted()).thenReturn(null);
        when(
          () => mockAnalytics.trackAiInputCompleted(
            itemCount: any(named: 'itemCount'),
          ),
        ).thenReturn(null);
        when(
          () => mockAnalytics.trackAiInputFailed(
            errorType: any(named: 'errorType'),
          ),
        ).thenReturn(null);
        when(
          () => mockMonitoring.captureException(
            any(),
            stackTrace: any(named: 'stackTrace'),
            tags: any(named: 'tags'),
          ),
        ).thenReturn(null);
      });

      test(
        'processClothingItem fires submitted + completed on success',
        () async {
          final service = _makeService(
            MockClient((_) async => http.Response(validOpenAiResponse, 200)),
            analytics: mockAnalytics,
          );

          await service.processClothingItem(_fakeImageFile());

          verify(() => mockAnalytics.trackAiInputSubmitted()).called(1);
          verify(
            () => mockAnalytics.trackAiInputCompleted(itemCount: 1),
          ).called(1);
          verifyNever(
            () => mockAnalytics.trackAiInputFailed(
              errorType: any(named: 'errorType'),
            ),
          );
        },
      );

      test(
        'processClothingItem fires submitted + failed on error, then rethrows',
        () async {
          final service = _makeService(
            MockClient((_) async => http.Response('{}', 500)),
            analytics: mockAnalytics,
            monitoring: mockMonitoring,
          );

          await expectLater(
            service.processClothingItem(_fakeImageFile()),
            throwsA(isA<VisionAnalysisException>()),
          );

          verify(() => mockAnalytics.trackAiInputSubmitted()).called(1);
          verify(
            () => mockAnalytics.trackAiInputFailed(
              errorType: 'VisionAnalysisException',
            ),
          ).called(1);
          verify(
            () => mockMonitoring.captureException(
              any(),
              stackTrace: any(named: 'stackTrace'),
              tags: any(named: 'tags'),
            ),
          ).called(1);
        },
      );
    });
  });
}

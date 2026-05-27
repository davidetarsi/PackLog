import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/features/ai_input/service/ai_clothing_analyzer_service.dart';

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

    group('Analytics tracking', () {
      late MockCoreAnalyticsService mockAnalytics;
      late MockAppMonitoringService mockMonitoring;

      const validOpenAiResponse = '''
{
  "choices": [{
    "message": {
      "content": "[{\\"name\\": \\"T-Shirt\\", \\"category\\": \\"Upper Body\\", \\"baseColor\\": \\"Bianco\\", \\"pattern\\": \\"Solid\\", \\"coverage\\": \\"Short-sleeve\\", \\"fit\\": \\"Regular\\", \\"warmth\\": 2, \\"formality\\": \\"Casual\\", \\"activityTags\\": [\\"Everyday\\"]}]"
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

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pack_log/features/ai_input/service/ai_clothing_analyzer_service.dart';

File _fakeImageFile() {
  final f = File('${Directory.systemTemp.path}/test_img.png')
    ..writeAsBytesSync(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]));
  return f;
}

AiClothingAnalyzerService _makeService(http.Client mockClient) =>
    AiClothingAnalyzerService(
      proxyUrl: 'https://fake.supabase.co/functions/v1/openai-proxy',
      anonKey: 'fake-anon-key',
      client: mockClient,
      jwtProvider: () => 'fake-jwt-token',
    );

void main() {
  group('AiClothingAnalyzerService', () {
    test('throws GptLimitExceededException on HTTP 429', () {
      final service = _makeService(
        MockClient(
          (_) async => http.Response(
            '{"error":"Monthly GPT limit reached"}',
            429,
          ),
        ),
      );

      expect(
        () => service.processClothingItem(_fakeImageFile()),
        throwsA(isA<GptLimitExceededException>()),
      );
    });

    test('throws VisionAnalysisException on HTTP 500', () {
      final service = _makeService(
        MockClient(
          (_) async => http.Response('{"error":"internal"}', 500),
        ),
      );

      expect(
        () => service.processClothingItem(_fakeImageFile()),
        throwsA(isA<VisionAnalysisException>()),
      );
    });

    test('throws VisionAnalysisException when jwtProvider returns null', () {
      final service = AiClothingAnalyzerService(
        proxyUrl: 'https://fake.supabase.co/functions/v1/openai-proxy',
        anonKey: 'fake-anon-key',
        jwtProvider: () => null,
      );

      expect(
        () => service.processClothingItem(_fakeImageFile()),
        throwsA(isA<VisionAnalysisException>()),
      );
    });
  });
}

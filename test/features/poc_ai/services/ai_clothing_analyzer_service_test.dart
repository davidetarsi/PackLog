import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/poc_ai/models/clothing_analysis_result.dart';
import 'package:pack_log/features/poc_ai/services/ai_clothing_analyzer_service.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockHttpClient extends Mock implements http.Client {}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds a valid OpenAI chat-completions response envelope whose
/// assistant message content is the given [innerJson].
String _openAiEnvelope(String innerJson) => jsonEncode({
      'choices': [
        {
          'message': {'role': 'assistant', 'content': innerJson},
        }
      ]
    });

/// A valid JSON array as returned by GPT-4o for a single clothing item.
/// Unknown keys (e.g. `fit`, `versatility`) are gracefully ignored by fromJson.
const _validInnerJson = '['
    '{'
    '"name":"T-shirt bianca",'
    '"category":"Upper Body",'
    '"baseColor":"Bianco",'
    '"colorTone":"Light",'
    '"weather":["Hot","Mild"],'
    '"coverage":"Partial",'
    '"pattern":"Solid",'
    '"formality":2,'
    '"activityTags":["Casual","Sport"]'
    '}'
    ']';

final _expectedItem = ClothingAnalysisResult(
  name: 'T-shirt bianca',
  category: 'Upper Body',
  baseColor: 'Bianco',
  colorTone: 'Light',
  weather: ['Hot', 'Mild'],
  coverage: 'Partial',
  pattern: 'Solid',
  formality: 2,
  activityTags: ['Casual', 'Sport'],
);

// ── Test suite ─────────────────────────────────────────────────────────────────

void main() {
  late MockHttpClient mockClient;
  late AiClothingAnalyzerService service;
  late File tempImageFile;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://example.com'));
    registerFallbackValue(http.Request('POST', Uri.parse('http://example.com')));
  });

  setUp(() async {
    mockClient = MockHttpClient();
    service = AiClothingAnalyzerService(
      // removeBgApiKey: 'test-removebg-key', // ← REMOVE.BG DISABILITATO
      openAiApiKey: 'test-openai-key',
      client: mockClient,
    );

    tempImageFile = File('${Directory.systemTemp.path}/test_clothing.jpg');
    await tempImageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG magic bytes
  });

  tearDown(() async {
    if (await tempImageFile.exists()) await tempImageFile.delete();
  });

  // ── ClothingAnalysisResult ──────────────────────────────────────────────────

  group('ClothingAnalysisResult', () {
    test('fromJson parses a complete valid JSON map', () {
      final result = ClothingAnalysisResult.fromJson({
        'name': 'Jeans blu',
        'category': 'Lower Body',
        'baseColor': 'Blu',
        'colorTone': 'Dark',
        'weather': ['Mild', 'Cold'],
        'coverage': 'Full',
        'pattern': 'Solid',
        'formality': 3,
        'activityTags': ['Casual', 'Work'],
      });

      expect(result.name, 'Jeans blu');
      expect(result.category, 'Lower Body');
      expect(result.baseColor, 'Blu');
      expect(result.colorTone, 'Dark');
      expect(result.weather, ['Mild', 'Cold']);
      expect(result.coverage, 'Full');
      expect(result.pattern, 'Solid');
      expect(result.formality, 3);
      expect(result.activityTags, ['Casual', 'Work']);
    });

    test('fromJson uses safe defaults for all missing fields', () {
      final result = ClothingAnalysisResult.fromJson({});

      expect(result.name, 'Sconosciuto');
      expect(result.category, '');
      expect(result.baseColor, '');
      expect(result.colorTone, '');
      expect(result.weather, isEmpty);
      expect(result.coverage, '');
      expect(result.pattern, '');
      expect(result.formality, 5);
      expect(result.activityTags, isEmpty);
    });

    test('fromJson ignores non-String entries in weather and activityTags', () {
      final result = ClothingAnalysisResult.fromJson({
        'weather': ['Hot', 42, null, 'Mild'],
        'activityTags': ['Casual', 99, null, 'Work'],
      });

      expect(result.weather, ['Hot', 'Mild']);
      expect(result.activityTags, ['Casual', 'Work']);
    });

    test('equality holds for two identical instances', () {
      const a = ClothingAnalysisResult(
        name: 'Sneakers',
        category: 'Shoes',
        baseColor: 'Bianco',
        colorTone: 'Light',
        weather: ['Hot', 'Mild'],
        coverage: 'Partial',
        pattern: 'Solid',
        formality: 1,
        activityTags: ['Casual', 'Sport'],
      );
      const b = ClothingAnalysisResult(
        name: 'Sneakers',
        category: 'Shoes',
        baseColor: 'Bianco',
        colorTone: 'Light',
        weather: ['Hot', 'Mild'],
        coverage: 'Partial',
        pattern: 'Solid',
        formality: 1,
        activityTags: ['Casual', 'Sport'],
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toJson round-trips through fromJson', () {
      final original = ClothingAnalysisResult(
        name: 'Cappotto nero',
        category: 'Outerwear',
        baseColor: 'Nero',
        colorTone: 'Dark',
        weather: ['Cold'],
        coverage: 'Full',
        pattern: 'Solid',
        formality: 7,
        activityTags: ['Formal', 'Work'],
      );

      final roundTripped = ClothingAnalysisResult.fromJson(original.toJson());
      expect(roundTripped, equals(original));
    });
  });

  // ── calculatedVersatility ──────────────────────────────────────────────────

  group('calculatedVersatility getter', () {
    test('returns 1 immediately for Sports activityTag', () {
      final item = ClothingAnalysisResult(
        name: 'Canotta da palestra',
        category: 'Upper Body',
        baseColor: 'Nero',
        colorTone: 'Dark',
        weather: ['Hot'],
        coverage: 'Sleeveless',
        pattern: 'Solid',
        formality: 1,
        activityTags: ['Sports'],
      );
      expect(item.calculatedVersatility, 1);
    });

    test('returns 1 immediately for Sleeping activityTag', () {
      final item = ClothingAnalysisResult(
        name: 'Pigiama',
        category: 'Upper Body',
        baseColor: 'Bianco',
        colorTone: 'Light',
        weather: ['Mild'],
        coverage: 'Long-sleeve',
        pattern: 'Solid',
        formality: 0,
        activityTags: ['Sleeping'],
      );
      expect(item.calculatedVersatility, 1);
    });

    test('neutral colour tone adds +1', () {
      // formality 5 (+1), Neutral tone (+1), Solid pattern → 3+1+1 = 5
      final item = ClothingAnalysisResult(
        name: 'Camicia',
        category: 'Upper Body',
        baseColor: 'Grigio',
        colorTone: 'Neutral',
        weather: ['Mild'],
        coverage: 'Long-sleeve',
        pattern: 'Solid',
        formality: 5,
        activityTags: ['Casual'],
      );
      expect(item.calculatedVersatility, 5);
    });

    test('non-Solid pattern subtracts 1', () {
      // formality 5 (+1), colorTone not neutral → 3+1-1 = 3
      final item = ClothingAnalysisResult(
        name: 'Camicia a righe',
        category: 'Upper Body',
        baseColor: 'Blu',
        colorTone: 'Dark',
        weather: ['Mild'],
        coverage: 'Long-sleeve',
        pattern: 'Striped',
        formality: 5,
        activityTags: ['Casual'],
      );
      expect(item.calculatedVersatility, 3);
    });

    test('very high formality subtracts 1', () {
      // formality 9 (-1), Nero base (+1), Solid → 3-1+1 = 3
      final item = ClothingAnalysisResult(
        name: 'Abito da sera',
        category: 'Outerwear',
        baseColor: 'Nero',
        colorTone: 'Dark',
        weather: ['Mild'],
        coverage: 'Full-length',
        pattern: 'Solid',
        formality: 9,
        activityTags: ['Formal'],
      );
      expect(item.calculatedVersatility, 3);
    });

    test('score is clamped to minimum 1', () {
      // formality 1 (-1), non-neutral colour, Striped (-1) → 3-1-1 = 1
      final item = ClothingAnalysisResult(
        name: 'Canottiera floreale',
        category: 'Upper Body',
        baseColor: 'Rosa',
        colorTone: 'Pastel',
        weather: ['Hot'],
        coverage: 'Sleeveless',
        pattern: 'Floral',
        formality: 1,
        activityTags: ['Casual'],
      );
      expect(item.calculatedVersatility, greaterThanOrEqualTo(1));
    });

    test('score is clamped to maximum 5', () {
      // formality 5 (+1), Bianco base (+1), Solid → 3+1+1 = 5
      final item = ClothingAnalysisResult(
        name: 'T-shirt bianca',
        category: 'Upper Body',
        baseColor: 'Bianco',
        colorTone: 'Light',
        weather: ['Hot'],
        coverage: 'Short-sleeve',
        pattern: 'Solid',
        formality: 5,
        activityTags: ['Casual'],
      );
      expect(item.calculatedVersatility, lessThanOrEqualTo(5));
    });
  });

  // ── processClothingItem – happy path ──────────────────────────────────────

  group('processClothingItem – happy path', () {
    test('returns a non-empty list with correctly parsed ClothingItem', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer(
        (_) async => http.Response(_openAiEnvelope(_validInnerJson), 200),
      );

      final result = await service.processClothingItem(tempImageFile);

      expect(result, isA<List<ClothingItem>>());
      expect(result, isNotEmpty);
      expect(result.first, equals(_expectedItem));
    });

    test('returns multiple items when GPT identifies more than one', () async {
      final multiJson = jsonEncode([
        {
          'name': 'T-shirt',
          'category': 'Upper Body',
          'baseColor': 'Bianco',
          'colorTone': 'Light',
          'weather': ['Hot'],
          'coverage': 'Partial',
          'pattern': 'Solid',
          'formality': 2,
          'activityTags': ['Casual'],
        },
        {
          'name': 'Jeans',
          'category': 'Lower Body',
          'baseColor': 'Blu',
          'colorTone': 'Dark',
          'weather': ['Mild'],
          'coverage': 'Full',
          'pattern': 'Solid',
          'formality': 3,
          'activityTags': ['Casual'],
        },
      ]);

      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer(
        (_) async => http.Response(_openAiEnvelope(multiJson), 200),
      );

      final result = await service.processClothingItem(tempImageFile);

      expect(result.length, 2);
      expect(result[0].name, 'T-shirt');
      expect(result[1].name, 'Jeans');
    });

    test('calls only OpenAI – Remove.bg is disabled', () async {
      var openAiCallCount = 0;

      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {
        openAiCallCount++;
        return http.Response(_openAiEnvelope(_validInnerJson), 200);
      });

      await service.processClothingItem(tempImageFile);

      expect(openAiCallCount, 1);
      verifyNever(() => mockClient.send(any()));
    });
  });

  // ── Vision analysis failures ──────────────────────────────────────────────

  group('processClothingItem – vision analysis failures', () {
    test('throws VisionAnalysisException on OpenAI 401', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Unauthorized', 401));

      expect(
        () => service.processClothingItem(tempImageFile),
        throwsA(isA<VisionAnalysisException>()),
      );
    });

    test('throws VisionAnalysisException on OpenAI 500', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer(
        (_) async => http.Response('Internal Server Error', 500),
      );

      expect(
        () => service.processClothingItem(tempImageFile),
        throwsA(isA<VisionAnalysisException>()),
      );
    });

    test('wraps network exception in VisionAnalysisException', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenThrow(const SocketException('Connection refused'));

      expect(
        () => service.processClothingItem(tempImageFile),
        throwsA(isA<VisionAnalysisException>()),
      );
    });
  });

  // ── Response parsing failures ─────────────────────────────────────────────

  group('processClothingItem – response parsing failures', () {
    test('throws ResponseParsingException on malformed outer JSON', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('not json at all', 200));

      expect(
        () => service.processClothingItem(tempImageFile),
        throwsA(isA<ResponseParsingException>()),
      );
    });

    test('throws ResponseParsingException when choices array is missing',
        () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer(
        (_) async => http.Response(jsonEncode({'id': 'chatcmpl-xyz'}), 200),
      );

      expect(
        () => service.processClothingItem(tempImageFile),
        throwsA(isA<ResponseParsingException>()),
      );
    });

    test('throws ResponseParsingException when content is not valid JSON',
        () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer(
        (_) async => http.Response(
          _openAiEnvelope('```json\n{broken json}```'),
          200,
        ),
      );

      expect(
        () => service.processClothingItem(tempImageFile),
        throwsA(isA<ResponseParsingException>()),
      );
    });

    test('ResponseParsingException message contains raw body for debugging',
        () async {
      const rawBody = 'totally broken response';
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(rawBody, 200));

      await expectLater(
        service.processClothingItem(tempImageFile),
        throwsA(
          isA<ResponseParsingException>().having(
            (e) => e.message,
            'message',
            contains(rawBody),
          ),
        ),
      );
    });

    test('tolerates missing optional fields – uses safe defaults', () async {
      const innerJson = '[{"name":"Scarpa","category":"Shoes"}]';
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer(
        (_) async => http.Response(_openAiEnvelope(innerJson), 200),
      );

      final result = await service.processClothingItem(tempImageFile);

      expect(result.first.name, 'Scarpa');
      expect(result.first.weather, isEmpty);
      expect(result.first.activityTags, isEmpty);
      expect(result.first.formality, 5);
      // formality 5 (+1), no neutral/black/white, empty pattern (-1) → 3+1-1 = 3
      expect(result.first.calculatedVersatility, 3);
    });
  });
}

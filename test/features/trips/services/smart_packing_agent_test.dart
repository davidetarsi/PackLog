import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/trips/services/smart_packing_agent.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;
  late SmartPackingAgent agent;

  setUp(() {
    mockClient = MockHttpClient();
    agent = SmartPackingAgent(apiKey: 'test-key', client: mockClient);
    registerFallbackValue(Uri());
  });

  // ── Helpers ───────────────────────────────────────────────────────────────

  ItemModel _makeItem(String id, {ItemCategory category = ItemCategory.vestiti}) {
    return ItemModel(
      id: id,
      houseId: 'h1',
      name: 'Item $id',
      category: category,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );
  }

  http.Response _mockGptResponse(List<Map<String, dynamic>> items) {
    return http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {
              'content': jsonEncode(items),
            },
          },
        ],
      }),
      200,
    );
  }

  Future<List<SmartPackingRecommendation>> _callAgent({
    List<ItemModel>? wardrobe,
    List<ItemModel>? essentials,
  }) {
    return agent.generatePackingList(
      destination: 'Parigi',
      tripDurationDays: 5,
      weatherTags: ['Rain', 'Cold'],
      quotas: {'tops': 3, 'bottoms': 2},
      wardrobeBucket: wardrobe ?? [_makeItem('w1'), _makeItem('w2')],
      essentialsBucket: essentials ?? [_makeItem('e1', category: ItemCategory.toiletries)],
    );
  }

  group('SmartPackingAgent - generatePackingList', () {
    group('Happy path', () {
      test('returns parsed recommendations on 200 OK', () async {
        when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer(
          (_) async => _mockGptResponse([
            {'itemId': 'w1', 'motivation': 'Ottima per la pioggia.'},
            {'itemId': 'e1', 'motivation': 'Indispensabile per 5 giorni.'},
          ]),
        );

        final result = await _callAgent();

        expect(result.length, equals(2));
        expect(result[0].itemId, equals('w1'));
        expect(result[0].motivation, equals('Ottima per la pioggia.'));
        expect(result[1].itemId, equals('e1'));
      });

      test('strips optional markdown code fences from response', () async {
        final jsonContent = jsonEncode([
          {'itemId': 'w2', 'motivation': 'Versatile.'},
        ]);
        when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': '```json\n$jsonContent\n```',
                  },
                },
              ],
            }),
            200,
          ),
        );

        final result = await _callAgent();
        expect(result.length, equals(1));
        expect(result[0].itemId, equals('w2'));
      });

      test('filters out recommendations with empty itemId', () async {
        when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer(
          (_) async => _mockGptResponse([
            {'itemId': '', 'motivation': 'No id.'},
            {'itemId': 'w1', 'motivation': 'Valid.'},
          ]),
        );

        final result = await _callAgent();
        expect(result.length, equals(1));
        expect(result[0].itemId, equals('w1'));
      });

      test('returns empty list when GPT returns empty array', () async {
        when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer((_) async => _mockGptResponse([]));

        final result = await _callAgent();
        expect(result, isEmpty);
      });
    });

    group('HTTP error handling', () {
      test('throws on non-200 HTTP status', () async {
        when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer((_) async => http.Response('Unauthorized', 401));

        expect(() => _callAgent(), throwsException);
      });

      test('throws on 500 server error', () async {
        when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(() => _callAgent(), throwsException);
      });
    });

    group('Response parsing errors', () {
      test('throws FormatException when choices array is empty', () async {
        when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer(
          (_) async => http.Response(
            jsonEncode({'choices': []}),
            200,
          ),
        );

        expect(() => _callAgent(), throwsA(isA<FormatException>()));
      });

      test('throws FormatException when content is not a JSON array', () async {
        when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'choices': [
                {'message': {'content': '{"key": "value"}'}},
              ],
            }),
            200,
          ),
        );

        expect(() => _callAgent(), throwsA(isA<FormatException>()));
      });
    });

    group('Request construction', () {
      test('sends request to correct OpenAI endpoint', () async {
        when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer((_) async => _mockGptResponse([]));

        await _callAgent();

        final captured = verify(
          () => mockClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.toString(), contains('api.openai.com'));
        expect(uri.toString(), contains('chat/completions'));
      });

      test('sends correct model and temperature in body', () async {
        when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer((_) async => _mockGptResponse([]));

        await _callAgent();

        final captured = verify(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        final body = jsonDecode(captured.first as String) as Map<String, dynamic>;
        expect(body['model'], equals('gpt-4o-mini'));
        expect(body['temperature'], equals(0.0));
      });

      test('includes destination in system prompt', () async {
        when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer((_) async => _mockGptResponse([]));

        await agent.generatePackingList(
          destination: 'Tokyo',
          tripDurationDays: 7,
          weatherTags: ['Sunny'],
          quotas: {'tops': 4},
          wardrobeBucket: [],
          essentialsBucket: [],
        );

        final captured = verify(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        final body = jsonDecode(captured.first as String) as Map<String, dynamic>;
        final messages = body['messages'] as List;
        final systemContent = (messages.first)['content'] as String;
        expect(systemContent, contains('Tokyo'));
        expect(systemContent, contains('7 days'));
      });
    });
  });

  group('SmartPackingRecommendation model', () {
    test('fromJson parses correctly', () {
      final rec = SmartPackingRecommendation.fromJson({
        'itemId': 'item-abc',
        'motivation': 'Perfetto per il clima.',
      });
      expect(rec.itemId, equals('item-abc'));
      expect(rec.motivation, equals('Perfetto per il clima.'));
    });

    test('fromJson handles missing fields with safe defaults', () {
      final rec = SmartPackingRecommendation.fromJson({});
      expect(rec.itemId, equals(''));
      expect(rec.motivation, equals(''));
    });

    test('toJson round-trips correctly', () {
      const original = SmartPackingRecommendation(
        itemId: 'x',
        motivation: 'reason',
      );
      final rec = SmartPackingRecommendation.fromJson(original.toJson());
      expect(rec.itemId, equals(original.itemId));
      expect(rec.motivation, equals(original.motivation));
    });
  });
}

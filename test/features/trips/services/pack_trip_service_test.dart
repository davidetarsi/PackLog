import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/services/pack_trip_service.dart';

const _houseId = '6f1c2b3a-0000-4000-8000-000000000001';

final _now = DateTime.utc(2026, 10, 24, 9);

final _body = <String, dynamic>{
  'house_id': _houseId,
  'trip': {'giorni': 4},
};

/// Risposta di esempio del server: due capi, un avviso, un punto del "perche".
Map<String, dynamic> _okResponse() => {
  'valigia': {'ideali': <dynamic>[]},
  'motivi': {'capi': <dynamic>[], 'essenziali': <dynamic>[]},
  'perche': [
    {
      'codice': 'giorno',
      'titolo': 'Tutti i giorni',
      'frasi': ['2 pezzi per 4 giorni'],
      'capi': ['T-shirt'],
    },
  ],
  'geo': <String, dynamic>{},
  'meteo': <String, dynamic>{},
  'note_tecniche': <dynamic>[],
  'capi': [
    {
      'item_id': 'item-1',
      'quantita': 2,
      'in_partenza': true,
      'motivo': {
        'codice': 'giorno',
        'etichetta': 'Tutti i giorni',
        'frase': '2 pezzi per 4 giorni',
      },
    },
    {
      'item_id': 'item-2',
      'quantita': 1,
      'in_partenza': false,
      'motivo': {
        'codice': 'essenziale',
        'etichetta': 'Essenziale',
        'frase': 'Serve sempre',
      },
    },
  ],
  'avvisi': <dynamic>[
    {
      'id': 'pochi_pezzi:0',
      'codice': 'pochi_pezzi',
      'livello': 'importante',
      'titolo': 'Ti servono più pezzi di T-shirt',
      'perche': "Ne servirebbero 4, nell'armadio ne hai 2.",
      'cerca': 'T-shirt',
    },
  ],
};

PackTripService _service(http.Client Function() client) =>
    PackTripService(client: client, token: () => 'jwt');

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('PackTripService.generate', () {
    test('200: proposta, avvisi e motivi dalla risposta', () async {
      late http.Request sent;
      final service = _service(
        () => MockClient((request) async {
          sent = request;
          return _json(200, _okResponse());
        }),
      );

      final result = await service.generate(_body, houseId: _houseId);

      expect(sent.method, 'POST');
      expect(sent.url.path, endsWith('/functions/v1/pack-trip'));
      expect(sent.headers['Authorization'], 'Bearer jwt');
      expect(sent.headers['Content-Type'], 'application/json');
      expect(jsonDecode(sent.body), _body);

      expect(result.houseId, _houseId);
      expect(result.proposal, [
        const AiPackedItem(
          itemId: 'item-1',
          quantity: 2,
          inDeparture: true,
          reason: AiReason(
            code: 'giorno',
            label: 'Tutti i giorni',
            sentence: '2 pezzi per 4 giorni',
          ),
        ),
        const AiPackedItem(
          itemId: 'item-2',
          quantity: 1,
          inDeparture: false,
          reason: AiReason(
            code: 'essenziale',
            label: 'Essenziale',
            sentence: 'Serve sempre',
          ),
        ),
      ]);
      expect(result.warnings, [
        const AiWarning(
          id: 'pochi_pezzi:0',
          code: 'pochi_pezzi',
          level: AiWarningLevel.important,
          title: 'Ti servono più pezzi di T-shirt',
          why: "Ne servirebbero 4, nell'armadio ne hai 2.",
          search: 'T-shirt',
        ),
      ]);
      expect(result.reasons, [
        const AiReasonPoint(
          code: 'giorno',
          title: 'Tutti i giorni',
          sentences: ['2 pezzi per 4 giorni'],
          items: ['T-shirt'],
        ),
      ]);
    });

    test('429: PackTripCreditsException', () async {
      final service = _service(
        () => MockClient(
          (_) async => _json(429, {'error': 'AI usage limit reached'}),
        ),
      );

      await expectLater(
        service.generate(_body, houseId: _houseId),
        throwsA(isA<PackTripCreditsException>()),
      );
    });

    test('422 "Wardrobe is empty": PackTripEmptyWardrobeException', () async {
      final service = _service(
        () =>
            MockClient((_) async => _json(422, {'error': 'Wardrobe is empty'})),
      );

      await expectLater(
        service.generate(_body, houseId: _houseId),
        throwsA(isA<PackTripEmptyWardrobeException>()),
      );
    });

    test(
      '422 "Wardrobe too large": PackTripWardrobeTooLargeException',
      () async {
        final service = _service(
          () => MockClient(
            (_) async =>
                _json(422, {'error': 'Wardrobe too large (max 400 items)'}),
          ),
        );

        await expectLater(
          service.generate(_body, houseId: _houseId),
          throwsA(isA<PackTripWardrobeTooLargeException>()),
        );
      },
    );

    test('502: PackTripException', () async {
      final service = _service(
        () => MockClient(
          (_) async => _json(502, {'error': 'Packing upstream error'}),
        ),
      );

      await expectLater(
        service.generate(_body, houseId: _houseId),
        throwsA(isA<PackTripException>()),
      );
    });

    test('corpo non JSON: PackTripException', () async {
      final service = _service(
        () => MockClient((_) async => http.Response('<html>oops</html>', 200)),
      );

      await expectLater(
        service.generate(_body, houseId: _houseId),
        throwsA(isA<PackTripException>()),
      );
    });

    test('errore di rete: PackTripException', () async {
      final service = _service(
        () => MockClient((_) async => throw http.ClientException('offline')),
      );

      await expectLater(
        service.generate(_body, houseId: _houseId),
        throwsA(isA<PackTripException>()),
      );
    });

    test('senza sessione: PackTripException', () async {
      final service = PackTripService(
        client: () => MockClient((_) async => _json(200, _okResponse())),
        token: () => null,
      );

      await expectLater(
        service.generate(_body, houseId: _houseId),
        throwsA(isA<PackTripException>()),
      );
    });

    test(
      'cancel: la generate in corso solleva PackTripException(annullata)',
      () async {
        final release = Completer<void>();
        final service = _service(
          () => MockClient((_) async {
            await release.future;
            return _json(200, _okResponse());
          }),
        );

        final pending = service.generate(_body, houseId: _houseId);
        final outcome = expectLater(
          pending,
          throwsA(
            isA<PackTripException>().having(
              (e) => e.message,
              'message',
              'annullata',
            ),
          ),
        );
        service.cancel();
        release.complete();

        await outcome;
      },
    );
  });

  group('parsePackTripResponse', () {
    test('un avviso con livello sconosciuto si scarta', () {
      final json = _okResponse();
      (json['avvisi'] as List).add(<String, dynamic>{
        'id': 'x:1',
        'codice': 'altro',
        'livello': 'forse',
        'titolo': 'Titolo',
        'perche': 'Perche',
        'cerca': null,
      });

      final result = parsePackTripResponse(json, houseId: _houseId, now: _now);

      expect(result.warnings.map((w) => w.id), ['pochi_pezzi:0']);
    });

    test('array opzionali mancanti: liste vuote', () {
      final result = parsePackTripResponse(
        {'valigia': <String, dynamic>{}},
        houseId: _houseId,
        now: _now,
      );

      expect(result.proposal, isEmpty);
      expect(result.warnings, isEmpty);
      expect(result.reasons, isEmpty);
      expect(result.dismissedWarnings, isEmpty);
      expect(result.generatedAt, _now);
    });

    test('struttura illeggibile: PackTripException', () {
      final json = _okResponse();
      json['capi'] = 'non una lista';

      expect(
        () => parsePackTripResponse(json, houseId: _houseId, now: _now),
        throwsA(isA<PackTripException>()),
      );
    });
  });
}

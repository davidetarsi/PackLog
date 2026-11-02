import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pack_log/core/once_per_day.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  var chiamate = 0;
  Future<int> azione() async => ++chiamate;
  setUp(() => chiamate = 0);

  Future<int?> esegui({
    bool sessione = true,
    Future<int> Function()? fai,
    DateTime? ora,
  }) => runOncePerDay<int>(
    key: 'prova_checked_on',
    hasSession: sessione,
    action: fai ?? azione,
    now: () => ora ?? DateTime(2026, 11, 1, 9),
  );

  test(
    'il primo controllo del giorno gira e restituisce il risultato, il secondo no',
    () async {
      expect(await esegui(), 1);
      expect(await esegui(ora: DateTime(2026, 11, 1, 22)), isNull);
      expect(chiamate, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('prova_checked_on'), '2026-11-01');
    },
  );

  test('il giorno dopo gira di nuovo', () async {
    await esegui();
    expect(await esegui(ora: DateTime(2026, 11, 2, 8)), 2);
  });

  test('senza sessione non gira e non segna il giorno', () async {
    expect(await esegui(sessione: false), isNull);
    expect(chiamate, 0);
    expect(await esegui(), 1);
  });

  for (final rete in <Object>[
    const SocketException('giù'),
    TimeoutException('lento'),
    http.ClientException('giù'),
    const HandshakeException('tls'),
  ]) {
    test('${rete.runtimeType} non segna il giorno e si rilancia', () async {
      await expectLater(esegui(fai: () async => throw rete), throwsA(rete));
      expect(await esegui(), 1, reason: 'il giorno è ancora libero');
    });
  }

  test(
    'una risposta d\'errore del server segna il giorno e si rilancia',
    () async {
      await expectLater(
        esegui(fai: () async => throw Exception('HTTP 500')),
        throwsException,
      );
      expect(await esegui(), isNull);
      expect(chiamate, 0);
    },
  );

  test(
    'due chiamate insieme con la stessa chiave: gira una volta sola',
    () async {
      final via = Completer<int>();
      final prima = esegui(fai: () => via.future);
      await Future<void>.delayed(Duration.zero);
      expect(await esegui(), isNull);
      via.complete(7);
      expect(await prima, 7);
    },
  );
}

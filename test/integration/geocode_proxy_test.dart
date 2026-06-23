// Integration test: verifica il proxy `geocode-proxy` su un progetto
// Supabase reale.
//
// Cosa copre:
//   - Chiamata senza JWT → 401
//   - Chiamata con JWT ma `text` troppo lungo → 400
//   - Chiamata con JWT e parametri validi → 200 + body JSON con `features`
//
// Cosa NON copre (rinviato per pragmatismo):
//   - Il cap del rate-limit (100/h) non viene saturato: richiederebbe 100
//     chiamate reali a Geoapify e attesa di 1 ora prima del test successivo.
//     Resta da verificare manualmente con uno script bash che fa 101 GET
//     in rapida sequenza e si aspetta un 429 sull'ultima.
//
// Setup: stesso del test RLS (riusa lo user A pre-creato).
//
//   flutter test test/integration/geocode_proxy_test.dart \
//     --dart-define=RLS_TEST_SUPABASE_URL=https://xxx.supabase.co \
//     --dart-define=RLS_TEST_SUPABASE_ANON_KEY=eyJ... \
//     --dart-define=RLS_TEST_USER_A_EMAIL=test-a@example.com \
//     --dart-define=RLS_TEST_USER_A_PASSWORD=...

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const _kSupabaseUrl = String.fromEnvironment('RLS_TEST_SUPABASE_URL');
const _kSupabaseAnonKey = String.fromEnvironment('RLS_TEST_SUPABASE_ANON_KEY');
const _kUserAEmail = String.fromEnvironment('RLS_TEST_USER_A_EMAIL');
const _kUserAPassword = String.fromEnvironment('RLS_TEST_USER_A_PASSWORD');

bool get _envConfigured =>
    _kSupabaseUrl.isNotEmpty &&
    _kSupabaseAnonKey.isNotEmpty &&
    _kUserAEmail.isNotEmpty &&
    _kUserAPassword.isNotEmpty;

void main() {
  if (!_envConfigured) {
    test('Geocode proxy integration (SKIPPED — env vars mancanti)', () {
      // ignore: avoid_print
      print(
        '[geocode_test] SKIPPED: configurare RLS_TEST_SUPABASE_URL, '
        'RLS_TEST_SUPABASE_ANON_KEY, RLS_TEST_USER_A_EMAIL, '
        'RLS_TEST_USER_A_PASSWORD via --dart-define per eseguirlo.',
      );
    }, skip: 'env vars non configurate');
    return;
  }

  late SupabaseClient clientA;
  late String jwtA;
  late Uri proxyUri;

  setUpAll(() async {
    HttpOverrides.global = null;

    clientA = SupabaseClient(_kSupabaseUrl, _kSupabaseAnonKey);
    final session = await clientA.auth.signInWithPassword(
      email: _kUserAEmail,
      password: _kUserAPassword,
    );
    jwtA = session.session!.accessToken;

    proxyUri = Uri.parse('$_kSupabaseUrl/functions/v1/geocode-proxy');
  });

  tearDownAll(() async {
    await clientA.auth.signOut();
  });

  group('geocode-proxy', () {
    test('rifiuta chiamate senza Authorization header (401)', () async {
      final response = await http.get(
        proxyUri.replace(queryParameters: {'text': 'Milano'}),
        // niente Authorization → il proxy/gateway deve respingere
        headers: {'apikey': _kSupabaseAnonKey},
      );
      expect(
        response.statusCode,
        anyOf(401, 403),
        reason:
            'Senza JWT il proxy/gateway deve rispondere 401 (o 403 per il '
            'gateway Supabase, equivalente in pratica)',
      );
    });

    test('rifiuta text troppo lungo (400)', () async {
      final longText = 'a' * 200; // sopra il limite di 100
      final response = await http.get(
        proxyUri.replace(queryParameters: {'text': longText}),
        headers: {
          'Authorization': 'Bearer $jwtA',
          'apikey': _kSupabaseAnonKey,
        },
      );
      expect(response.statusCode, 400);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('too long'));
    });

    test('rifiuta limit fuori range (400)', () async {
      final response = await http.get(
        proxyUri.replace(
          queryParameters: {'text': 'Milano', 'limit': '999'},
        ),
        headers: {
          'Authorization': 'Bearer $jwtA',
          'apikey': _kSupabaseAnonKey,
        },
      );
      expect(response.statusCode, 400);
    });

    test('happy path: 200 + features array (autenticato, params validi)',
        () async {
      final response = await http.get(
        proxyUri.replace(
          queryParameters: {
            'text': 'Milano',
            'lang': 'it',
            'limit': '5',
          },
        ),
        headers: {
          'Authorization': 'Bearer $jwtA',
          'apikey': _kSupabaseAnonKey,
        },
      );
      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body, contains('features'));
      expect(body['features'], isA<List<dynamic>>());
    });
  });
}

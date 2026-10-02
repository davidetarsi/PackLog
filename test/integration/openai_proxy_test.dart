// Integration test: verifica le difese di input del proxy `openai-proxy`
// su un progetto Supabase reale.
//
// Cosa copre (zero chiamate reali a OpenAI):
//   - Chiamata senza JWT → 401
//   - JSON body malformato → 400
//   - Body non-oggetto → 400
//   - Body senza `image_base64` → 400
//   - `image_base64` di tipo sbagliato (numero) → 400
//   - `image_base64` enorme (sopra il limite) → 413
//
// Cosa NON copre (per non bruciare quota OpenAI):
//   - Happy path con immagine valida — va testato manualmente dall'app o con
//     uno script bash dedicato.
//
// Setup: riusa lo user A pre-creato come il test RLS.

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
    test(
      'OpenAI proxy integration (SKIPPED — env vars mancanti)',
      () {
        // ignore: avoid_print
        print(
          '[openai_test] SKIPPED: configurare RLS_TEST_SUPABASE_URL, '
          'RLS_TEST_SUPABASE_ANON_KEY, RLS_TEST_USER_A_EMAIL, '
          'RLS_TEST_USER_A_PASSWORD via --dart-define per eseguirlo.',
        );
      },
      skip: 'env vars non configurate',
    );
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

    proxyUri = Uri.parse('$_kSupabaseUrl/functions/v1/openai-proxy');
  });

  tearDownAll(() async {
    await clientA.auth.signOut();
  });

  Map<String, String> authHeaders() => {
    'Authorization': 'Bearer $jwtA',
    'apikey': _kSupabaseAnonKey,
    'Content-Type': 'application/json',
  };

  group('openai-proxy', () {
    test('rifiuta chiamate senza Authorization header (401)', () async {
      final response = await http.post(
        proxyUri,
        headers: {
          'apikey': _kSupabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'image_base64': 'AAAA'}),
      );
      expect(
        response.statusCode,
        anyOf(401, 403),
        reason: 'Senza JWT il gateway/proxy deve rifiutare',
      );
    });

    test('rifiuta body JSON malformato (400)', () async {
      final response = await http.post(
        proxyUri,
        headers: authHeaders(),
        body: 'not-a-json',
      );
      expect(response.statusCode, 400);
    });

    test('rifiuta body che non è oggetto JSON (400)', () async {
      final response = await http.post(
        proxyUri,
        headers: authHeaders(),
        body: jsonEncode([1, 2, 3]),
      );
      expect(response.statusCode, 400);
    });

    test('rifiuta body senza image_base64 (400)', () async {
      final response = await http.post(
        proxyUri,
        headers: authHeaders(),
        body: jsonEncode({'foo': 'bar'}),
      );
      expect(response.statusCode, 400);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('image_base64'));
    });

    test('rifiuta image_base64 di tipo sbagliato (400)', () async {
      final response = await http.post(
        proxyUri,
        headers: authHeaders(),
        body: jsonEncode({'image_base64': 12345}),
      );
      expect(response.statusCode, 400);
    });

    test('rifiuta image_base64 vuota (400)', () async {
      final response = await http.post(
        proxyUri,
        headers: authHeaders(),
        body: jsonEncode({'image_base64': ''}),
      );
      expect(response.statusCode, 400);
    });

    test('rifiuta image_base64 oltre il limite (413)', () async {
      // 6MB + 1 char: appena sopra MAX_IMAGE_BASE64_LENGTH del proxy.
      // Stringa fittizia (non base64 valido) — comunque l'unica cosa che
      // controlliamo qui è la dimensione, non il contenuto.
      final huge = 'A' * (6 * 1024 * 1024 + 1);
      final response = await http.post(
        proxyUri,
        headers: authHeaders(),
        body: jsonEncode({'image_base64': huge}),
      );
      expect(response.statusCode, 413);
    });
  });
}

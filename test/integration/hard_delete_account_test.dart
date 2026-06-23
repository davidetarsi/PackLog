// Integration test: verifica l'endpoint `hard-delete-account` end-to-end
// su un progetto Supabase reale (deve essere lo stesso usato per gli altri
// integration test).
//
// Cosa fa, in ordine:
//   1. Crea un utente burner via admin API (service_role)
//   2. Logga quell'utente per ottenere un JWT
//   3. Popola dati (1 house, 1 item, 1 trip)
//   4. Chiama l'edge function `hard-delete-account`
//   5. Verifica che:
//        - response.deleted abbia conteggi attesi
//        - le righe siano sparite (query con service_role per bypassare RLS)
//        - l'utente auth.users non esiste più
//
// Setup richiesto:
//   - Le stesse env var degli altri integration test +
//     RLS_TEST_SUPABASE_SERVICE_ROLE_KEY (l'admin key, NON committarla mai).
//
// ⚠️ Crea/cancella account reali su Supabase. Usa SOLO sul progetto di test.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _kSupabaseUrl = String.fromEnvironment('RLS_TEST_SUPABASE_URL');
const _kSupabaseAnonKey = String.fromEnvironment('RLS_TEST_SUPABASE_ANON_KEY');
const _kServiceRoleKey =
    String.fromEnvironment('RLS_TEST_SUPABASE_SERVICE_ROLE_KEY');

bool get _envConfigured =>
    _kSupabaseUrl.isNotEmpty &&
    _kSupabaseAnonKey.isNotEmpty &&
    _kServiceRoleKey.isNotEmpty;

void main() {
  if (!_envConfigured) {
    test('Hard-delete account integration (SKIPPED — env vars mancanti)', () {
      // ignore: avoid_print
      print(
        '[hard_delete_test] SKIPPED: serve anche '
        'RLS_TEST_SUPABASE_SERVICE_ROLE_KEY (oltre alle altre RLS_TEST_*).',
      );
    }, skip: 'env vars non configurate');
    return;
  }

  late SupabaseClient adminClient;     // service_role: bypassa RLS
  late SupabaseClient userClient;      // session dell'utente burner
  late String burnerEmail;
  late String burnerPassword;
  late String burnerUserId;

  setUpAll(() async {
    HttpOverrides.global = null;

    adminClient = SupabaseClient(_kSupabaseUrl, _kServiceRoleKey);

    // Email burner con uuid per evitare collisioni se il test gira più volte
    // (al netto della cancellazione finale, che è proprio quello che testiamo).
    burnerEmail = 'hard-delete-test-${const Uuid().v4()}@packlog.dev';
    burnerPassword = 'Test-${const Uuid().v4()}!Aa1';

    final created = await adminClient.auth.admin.createUser(
      AdminUserAttributes(
        email: burnerEmail,
        password: burnerPassword,
        emailConfirm: true,
      ),
    );
    burnerUserId = created.user!.id;

    userClient = SupabaseClient(_kSupabaseUrl, _kSupabaseAnonKey);
    await userClient.auth.signInWithPassword(
      email: burnerEmail,
      password: burnerPassword,
    );
  });

  tearDownAll(() async {
    // Safety net: se il test fallisce a metà, prova a ripulire l'utente
    // burner per non lasciare account orfani su Supabase.
    try {
      await adminClient.auth.admin.deleteUser(burnerUserId);
    } catch (_) {/* potrebbe essere già stato cancellato dal test */}
  });

  test('crea dati, hard-delete, verifica wipe completo', () async {
    // ── 1. Popola dati per l'utente burner ───────────────────────────────
    final now = DateTime.now().toUtc().toIso8601String();
    final houseId = const Uuid().v4();
    final itemId = const Uuid().v4();
    final tripId = const Uuid().v4();

    await userClient.from('houses').insert({
      'id': houseId,
      'user_id': burnerUserId,
      'name': 'Burner house',
      'icon_name': 'home',
      'is_primary': false,
      'created_at': now,
      'updated_at': now,
      'is_deleted': false,
    });
    await userClient.from('items').insert({
      'id': itemId,
      'user_id': burnerUserId,
      'house_id': houseId,
      'name': 'Burner item',
      'category': 'varie',
      'created_at': now,
      'updated_at': now,
      'is_deleted': false,
    });
    await userClient.from('trips').insert({
      'id': tripId,
      'user_id': burnerUserId,
      'name': 'Burner trip',
      'created_at': now,
      'updated_at': now,
      'is_deleted': false,
      'is_saved': false,
    });

    // ── 2. Sanity check: i dati ci sono davvero ────────────────────────
    final preHouses = await adminClient
        .from('houses')
        .select('id')
        .eq('user_id', burnerUserId);
    expect(preHouses, hasLength(1));

    // ── 3. Chiama l'edge function dall'utente burner ───────────────────
    final response = await userClient.functions.invoke(
      'hard-delete-account',
      method: HttpMethod.post,
    );
    expect(
      response.status,
      200,
      reason: 'Hard-delete should return 200, got: ${response.data}',
    );
    final body = response.data as Map<String, dynamic>;
    final deleted = body['deleted'] as Map<String, dynamic>;
    expect(deleted['houses'], 1);
    expect(deleted['items'], 1);
    expect(deleted['trips'], 1);
    expect(deleted['users'], 1);

    // ── 4. Verifica wipe completo con admin (RLS-bypass) ───────────────
    final postHouses = await adminClient
        .from('houses')
        .select('id')
        .eq('user_id', burnerUserId);
    expect(postHouses, isEmpty);

    final postItems = await adminClient
        .from('items')
        .select('id')
        .eq('user_id', burnerUserId);
    expect(postItems, isEmpty);

    final postTrips = await adminClient
        .from('trips')
        .select('id')
        .eq('user_id', burnerUserId);
    expect(postTrips, isEmpty);

    final postUsersTable = await adminClient
        .from('users')
        .select('id')
        .eq('id', burnerUserId);
    expect(postUsersTable, isEmpty);

    // ── 5. auth.users: deve sparire (verifica via admin.getUserById) ──
    try {
      final lookup = await adminClient.auth.admin.getUserById(burnerUserId);
      // L'API può ritornare un GoTrueAdminResponse vuoto invece di lanciare.
      expect(
        lookup.user,
        isNull,
        reason: 'auth.users row should be deleted',
      );
    } on AuthException {
      // OK — l'utente non esiste più, l'API ha tirato l'eccezione attesa.
    }
  });
}

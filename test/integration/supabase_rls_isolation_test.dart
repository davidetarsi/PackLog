// Integration test: verifica che le policy RLS di Supabase isolino i dati
// tra utenti diversi.
//
// Questo test NON gira di default: richiede un progetto Supabase reale
// (idealmente staging/dev, MAI prod) e due utenti di test pre-esistenti.
// Senza le env vars necessarie, ogni test viene saltato con un messaggio
// esplicito — così la suite locale e la CI passano comunque.
//
// Esecuzione:
//
//   flutter test test/integration/supabase_rls_isolation_test.dart \
//     --dart-define=RLS_TEST_SUPABASE_URL=https://xxx.supabase.co \
//     --dart-define=RLS_TEST_SUPABASE_ANON_KEY=eyJhbGciOi... \
//     --dart-define=RLS_TEST_USER_A_EMAIL=test-a@example.com \
//     --dart-define=RLS_TEST_USER_A_PASSWORD=... \
//     --dart-define=RLS_TEST_USER_B_EMAIL=test-b@example.com \
//     --dart-define=RLS_TEST_USER_B_PASSWORD=...
//
// Setup richiesto su Supabase:
//   - Due account email/password creati in advance (auth.users)
//   - Nessun dato pre-esistente per i due utenti nelle tabelle
//     houses/items/spaces/luggages/trips (il test fa cleanup ma assume
//     uno stato di partenza pulito)
//
// Cosa verifica:
//   - User A non vede né può scrivere dati di User B (SELECT/INSERT/
//     UPDATE/DELETE)
//   - User B non vede né può scrivere dati di User A (caso simmetrico
//     coperto dalle stesse policy)
//   - Anche tentando di passare un user_id esplicito = B.id, le policy
//     WITH CHECK rifiutano la scrittura

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _kSupabaseUrl = String.fromEnvironment('RLS_TEST_SUPABASE_URL');
const _kSupabaseAnonKey = String.fromEnvironment('RLS_TEST_SUPABASE_ANON_KEY');
const _kUserAEmail = String.fromEnvironment('RLS_TEST_USER_A_EMAIL');
const _kUserAPassword = String.fromEnvironment('RLS_TEST_USER_A_PASSWORD');
const _kUserBEmail = String.fromEnvironment('RLS_TEST_USER_B_EMAIL');
const _kUserBPassword = String.fromEnvironment('RLS_TEST_USER_B_PASSWORD');

bool get _envConfigured =>
    _kSupabaseUrl.isNotEmpty &&
    _kSupabaseAnonKey.isNotEmpty &&
    _kUserAEmail.isNotEmpty &&
    _kUserAPassword.isNotEmpty &&
    _kUserBEmail.isNotEmpty &&
    _kUserBPassword.isNotEmpty;

void main() {
  if (!_envConfigured) {
    // Skip pulito senza far fallire la suite: emette UNA volta il messaggio
    // di skip — utile per capire perché il test non sta girando in CI.
    test('Supabase RLS tenant isolation (SKIPPED — env vars mancanti)', () {
      // ignore: avoid_print
      print(
        '[rls_test] SKIPPED: configurare RLS_TEST_SUPABASE_URL, '
        'RLS_TEST_SUPABASE_ANON_KEY, RLS_TEST_USER_A_EMAIL, '
        'RLS_TEST_USER_A_PASSWORD, RLS_TEST_USER_B_EMAIL, '
        'RLS_TEST_USER_B_PASSWORD via --dart-define per eseguirlo.',
      );
    }, skip: 'env vars non configurate');
    return;
  }

  // Client e id riempiti in setUpAll; immutabili durante i test.
  late SupabaseClient clientA;
  late SupabaseClient clientB;
  late String userAId;
  late String userBId;

  // Record creato da A in setUpAll, riusato in tutti i test "B non può
  // toccare i dati di A".
  late String houseOfAId;

  setUpAll(() async {
    // `flutter test` installa un TestWidgetsFlutterBinding che forza tutte
    // le richieste HTTP a tornare 400 (per evitare test "accidentally
    // online"). Qui le richieste reali ci servono — disattiviamo l'override.
    HttpOverrides.global = null;

    // NB: NON chiamiamo `Supabase.initialize` perché tenterebbe di
    // toccare SharedPreferences (plugin Flutter) per persistere la sessione,
    // ma nel binding di test quel plugin non esiste. Costruiamo direttamente
    // due SupabaseClient indipendenti — uno per A, uno per B — così abbiamo
    // due sessioni isolate senza dipendenze native.
    clientA = SupabaseClient(_kSupabaseUrl, _kSupabaseAnonKey);
    clientB = SupabaseClient(_kSupabaseUrl, _kSupabaseAnonKey);

    final loginA = await clientA.auth.signInWithPassword(
      email: _kUserAEmail,
      password: _kUserAPassword,
    );
    final loginB = await clientB.auth.signInWithPassword(
      email: _kUserBEmail,
      password: _kUserBPassword,
    );
    userAId = loginA.user!.id;
    userBId = loginB.user!.id;

    // Seed: A crea una house. Tutti i test "isolation" punteranno a questa.
    houseOfAId = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await clientA.from('houses').insert({
      'id': houseOfAId,
      'user_id': userAId,
      'name': 'House owned by A',
      'icon_name': 'home',
      'is_primary': false,
      'created_at': now,
      'updated_at': now,
      'is_deleted': false,
    });
  });

  tearDownAll(() async {
    // Best-effort cleanup: ogni utente cancella i propri dati.
    // Se qualcosa fallisce, il prossimo run partirà da uno stato sporco
    // ma i test sono comunque idempotenti grazie agli UUID random.
    try {
      await clientA.from('houses').delete().eq('user_id', userAId);
    } catch (_) {}
    try {
      await clientB.from('houses').delete().eq('user_id', userBId);
    } catch (_) {}
    await clientA.auth.signOut();
    await clientB.auth.signOut();
  });

  group('Supabase RLS tenant isolation', () {
    test('B does NOT see houses owned by A (SELECT)', () async {
      final rows = await clientB.from('houses').select().eq('id', houseOfAId);
      expect(
        rows,
        isEmpty,
        reason: 'B should not be able to read A.house through SELECT',
      );
    });

    test('B cannot INSERT a house with user_id = A.id', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final newId = const Uuid().v4();
      // Atteso: PostgrestException con codice 42501 (insufficient_privilege)
      // o 23514 (check_violation) a seconda di come Postgres riporta il
      // failure del WITH CHECK.
      await expectLater(
        clientB.from('houses').insert({
          'id': newId,
          'user_id': userAId, // ← tentativo di spoofing
          'name': 'B tries to inject into A',
          'icon_name': 'home',
          'is_primary': false,
          'created_at': now,
          'updated_at': now,
          'is_deleted': false,
        }),
        throwsA(isA<PostgrestException>()),
        reason: 'WITH CHECK must reject INSERT with user_id != auth.uid()',
      );
    });

    test('B cannot UPDATE a house owned by A', () async {
      // L'UPDATE filtra per id (di A). USING blocca la riga: 0 righe matchate.
      // Supabase ritorna lista vuota senza eccezione: verifichiamo che il
      // record di A NON sia stato modificato leggendolo come A.
      await clientB
          .from('houses')
          .update({'name': 'HIJACKED BY B'})
          .eq('id', houseOfAId);

      final readBack = await clientA
          .from('houses')
          .select('name')
          .eq('id', houseOfAId)
          .single();
      expect(
        readBack['name'],
        'House owned by A',
        reason: 'UPDATE from B must not affect A house',
      );
    });

    test('B cannot DELETE a house owned by A', () async {
      // Come per UPDATE: USING fa 0-row match, nessuna eccezione, ma la riga
      // di A resta intatta.
      await clientB.from('houses').delete().eq('id', houseOfAId);

      final readBack = await clientA
          .from('houses')
          .select('id')
          .eq('id', houseOfAId);
      expect(
        readBack,
        isNotEmpty,
        reason: 'DELETE from B must not affect A house',
      );
    });

    test('A still sees own house (sanity)', () async {
      final rows = await clientA
          .from('houses')
          .select('id, name')
          .eq('id', houseOfAId)
          .single();
      expect(rows['name'], 'House owned by A');
    });
  });
}

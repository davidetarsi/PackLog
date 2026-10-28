import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pack_log/features/items/services/item_metadata_service.dart';

void main() {
  group('ItemMetadataService.fromName', () {
    Future<Map<String, dynamic>> bodyFor({String Function()? language}) async {
      late http.Request request;
      final service = ItemMetadataService(
        url: 'https://fake.supabase.co/functions/v1/item-metadata',
        anonKey: 'anon',
        jwtProvider: () => 'jwt',
        language: language,
        client: MockClient((req) async {
          request = req;
          return http.Response(jsonEncode({'items': []}), 200);
        }),
      );
      await service.fromName('  felpa grigia ');
      return jsonDecode(request.body) as Map<String, dynamic>;
    }

    test('manda il nome e la lingua dell\'app', () async {
      expect(await bodyFor(language: () => 'en'), {
        'name': 'felpa grigia',
        'lang': 'en',
      });
    });

    test('senza lingua indicata manda l\'italiano', () async {
      expect((await bodyFor())['lang'], 'it');
    });
  });
}

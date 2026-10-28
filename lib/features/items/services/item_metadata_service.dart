import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/item_model.dart';

/// La scheda di un oggetto aggiunto a mano, dall'edge function
/// `item-metadata` (`{ name }`): la stessa che riempie lo scan da foto.
class ItemMetadataResult {
  const ItemMetadataResult({required this.metadata, this.category});

  /// Da salvare in `items.ai_metadata`.
  final Map<String, dynamic> metadata;

  /// La categoria dell'app decisa dal server; null se non è una nota.
  final ItemCategory? category;
}

/// Chiede la scheda di un oggetto dal solo nome.
///
/// Non lancia mai: senza rete, senza sessione, a limite raggiunto o con una
/// risposta strana restituisce null e l'oggetto resta com'è. Il nome non
/// consuma crediti AI (ha un limite giornaliero lato server).
class ItemMetadataService {
  ItemMetadataService({
    required String url,
    required String anonKey,
    http.Client? client,
    String? Function()? jwtProvider,
    String Function()? language,
  }) : _url = url,
       _language = language ?? (() => 'it'),
       _anonKey = anonKey,
       _client = client ?? http.Client(),
       _jwtProvider =
           jwtProvider ??
           (() => Supabase.instance.client.auth.currentSession?.accessToken);

  final String _url;
  final String _anonKey;
  final http.Client _client;
  final String? Function() _jwtProvider;

  /// La lingua dell'app ('it' o 'en'), per i testi che scrive il server.
  final String Function() _language;

  Future<ItemMetadataResult?> fromName(String name) async {
    try {
      final jwt = _jwtProvider();
      if (jwt == null || jwt.isEmpty || name.trim().isEmpty) return null;
      final response = await _client
          .post(
            Uri.parse(_url),
            headers: {
              'Authorization': 'Bearer $jwt',
              'apikey': _anonKey,
              'Content-Type': 'application/json',
            },
            body: utf8.encode(
              jsonEncode({'name': name.trim(), 'lang': _language()}),
            ),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        debugPrint('[ItemMetadata] ${response.statusCode}: ${response.body}');
        return null;
      }
      return parse(response.body);
    } catch (e) {
      debugPrint('[ItemMetadata] scheda non ottenuta: $e');
      return null;
    }
  }

  /// `{ items: [{ metadata, app_category, dubbi }] }` -> il primo capo.
  @visibleForTesting
  static ItemMetadataResult? parse(String body) {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) return null;
    final items = json['items'];
    if (items is! List || items.isEmpty) return null;
    final first = items.first;
    if (first is! Map<String, dynamic>) return null;
    final metadata = first['metadata'];
    if (metadata is! Map<String, dynamic>) return null;
    final appCategory = first['app_category'];
    return ItemMetadataResult(
      metadata: metadata,
      category: ItemCategory.values
          .where((c) => c.name == appCategory)
          .firstOrNull,
    );
  }
}

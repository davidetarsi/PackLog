import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'catalog.dart';

/// Il file del repo, copia identica di `supabase/functions/_shared/catalogo/catalogo.json`.
/// È la copia di riserva per il primo avvio senza rete.
const String kCatalogoAsset =
    'supabase/functions/_shared/catalogo/catalogo.json';

/// Da dove arriva il catalogo sul server: la versione e le righe (sola lettura).
abstract class CatalogSource {
  /// `app_config.catalog_version`, o null se la riga manca.
  Future<int?> remoteVersion();

  /// Tutte le righe di `catalog_entries`.
  Future<List<Map<String, dynamic>>> remoteEntries();
}

class SupabaseCatalogSource implements CatalogSource {
  SupabaseCatalogSource(this._client);

  final SupabaseClient _client;

  @override
  Future<int?> remoteVersion() async {
    final riga = await _client
        .from('app_config')
        .select('value')
        .eq('key', 'catalog_version')
        .maybeSingle();
    if (riga == null) return null;
    return int.tryParse('${riga['value']}');
  }

  @override
  Future<List<Map<String, dynamic>>> remoteEntries() async {
    final righe = await _client
        .from('catalog_entries')
        .select('domain, id, sort, active, label_it, label_en, data');
    return List<Map<String, dynamic>>.from(righe);
  }
}

/// Il catalogo: copia locale (SharedPreferences), file del repo come riserva,
/// aggiornamento dal server quando la versione è più nuova.
class CatalogRepository {
  CatalogRepository({
    this.source,
    this.bundle,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Null: niente rete, si legge solo la copia locale o il file del repo.
  final CatalogSource? source;
  final AssetBundle? bundle;
  final DateTime Function() _now;

  static const _jsonKey = 'catalog_json_cache';
  static const _versionKey = 'catalog_version_cache';
  static const _controlloKey = 'catalog_checked_on';

  /// La copia locale se c'è e si legge; altrimenti il file del repo (versione 0).
  Future<Catalog> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final copia = prefs.getString(_jsonKey);
    if (copia != null) {
      try {
        final json = jsonDecode(copia) as Map<String, dynamic>;
        return Catalog.fromJson(
          json,
          version: prefs.getInt(_versionKey) ?? (json['version'] as int? ?? 0),
        );
      } catch (e) {
        debugPrint('[CatalogRepository] copia locale illeggibile: $e');
      }
    }
    final testo = await (bundle ?? rootBundle).loadString(kCatalogoAsset);
    return Catalog.fromJson(
      jsonDecode(testo) as Map<String, dynamic>,
      version: 0,
    );
  }

  /// Il catalogo dal server se la sua versione è più nuova di [localVersion]
  /// (salvato in locale), altrimenti null. Gli errori diventano null e un log.
  Future<Catalog?> refresh(int localVersion) async {
    final fonte = source;
    if (fonte == null) return null;
    try {
      final remota = await fonte.remoteVersion();
      if (remota == null || remota <= localVersion) return null;
      final righe = await fonte.remoteEntries();
      final catalogo = Catalog.fromJson({'entries': righe}, version: remota);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_jsonKey, jsonEncode(catalogo.toJson()));
      await prefs.setInt(_versionKey, remota);
      return catalogo;
    } catch (e) {
      debugPrint('[CatalogRepository] aggiornamento non riuscito: $e');
      return null;
    }
  }

  /// Il controllo del server al massimo una volta al giorno, all'apertura
  /// (decisione di Davide del 31 ottobre: letture rare). Un errore conta come
  /// controllo: niente nuovo tentativo a ogni avvio.
  Future<Catalog?> refreshIfDue({required int localVersion}) async {
    final prefs = await SharedPreferences.getInstance();
    final oggi = _giorno(_now());
    if (prefs.getString(_controlloKey) == oggi) return null;
    await prefs.setString(_controlloKey, oggi);
    return refresh(localVersion);
  }

  static String _giorno(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

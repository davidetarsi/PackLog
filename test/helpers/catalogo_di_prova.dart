import 'dart:convert';
import 'dart:io';

import 'package:pack_log/core/catalog/catalog.dart';
import 'package:pack_log/core/catalog/catalog_store.dart';

/// Il catalogo del repo: lo stesso file che è l'asset dell'app e la copia del
/// server (supabase/functions/_shared/catalogo/catalogo.json).
Catalog catalogoDelRepo() => Catalog.fromJson(
  jsonDecode(
        File(
          'supabase/functions/_shared/catalogo/catalogo.json',
        ).readAsStringSync(),
      )
      as Map<String, dynamic>,
  version: 1,
);

/// Mette il catalogo del repo nello store, nella lingua data. Da chiamare in
/// `setUp`: lo store è globale.
void caricaCatalogoDelRepo({String lingua = 'it'}) {
  CatalogStore.set(catalogoDelRepo());
  CatalogStore.languageCode = lingua;
}

/// Il catalogo del repo con la voce [id] di [domain] disattivata (tutto il resto
/// uguale), come dopo `UPDATE catalog_entries SET active = false`.
Catalog catalogoConVoceDisattivata(String domain, String id) {
  final repo = catalogoDelRepo();
  return Catalog(
    version: repo.version + 1,
    entries: [
      for (final e in repo.entries)
        if (e.domain == domain && e.id == id)
          CatalogEntry(
            domain: e.domain,
            id: e.id,
            sort: e.sort,
            active: false,
            labelIt: e.labelIt,
            labelEn: e.labelEn,
            data: e.data,
          )
        else
          e,
    ],
  );
}

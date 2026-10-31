/// Il catalogo dei tag (spec del 31 ottobre 2026, § 6): tipi, usi, stile, colori,
/// attività e alloggi del viaggio. Stesse voci del server: la tabella
/// `catalog_entries` e il file `catalogo.json` del repo hanno le stesse righe, con
/// le etichette in due forme (`label_it`/`label_en` e `label: {it, en}`).
library;

class CatalogEntry {
  const CatalogEntry({
    required this.domain,
    required this.id,
    required this.sort,
    required this.active,
    required this.labelIt,
    required this.labelEn,
    this.data = const {},
  });

  final String domain;
  final String id;
  final int sort;

  /// Le voci disattivate non si propongono, ma restano leggibili dove già usate.
  final bool active;
  final String labelIt;
  final String labelEn;

  /// I campi di significato del dominio (testi per il generatore, prompt, ...).
  final Map<String, dynamic> data;

  /// L'etichetta nella lingua data: italiano per `it`, inglese per tutto il resto.
  String label(String languageCode) => languageCode == 'it' ? labelIt : labelEn;

  factory CatalogEntry.fromJson(Map<String, dynamic> json) {
    final label = json['label'];
    final etichettaIt = label is Map ? label['it'] : json['label_it'];
    final etichettaEn = label is Map ? label['en'] : json['label_en'];
    final data = json['data'];
    return CatalogEntry(
      domain: json['domain'] as String,
      id: json['id'] as String,
      sort: (json['sort'] as num).toInt(),
      active: json['active'] as bool? ?? true,
      labelIt: (etichettaIt ?? '') as String,
      labelEn: (etichettaEn ?? '') as String,
      data: data is Map ? Map<String, dynamic>.from(data) : const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'id': id,
    'sort': sort,
    'active': active,
    'label': {'it': labelIt, 'en': labelEn},
    'data': data,
  };
}

class Catalog {
  Catalog({required this.version, required List<CatalogEntry> entries})
    : entries = List.unmodifiable(
        [...entries]..sort((a, b) => a.sort.compareTo(b.sort)),
      );

  /// Il catalogo prima che arrivi il primo: nessuna voce.
  static final Catalog vuoto = Catalog(version: 0, entries: const []);

  /// La versione di `app_config.catalog_version`; 0 per il file del repo.
  final int version;

  /// Tutte le voci, ordinate per `sort`.
  final List<CatalogEntry> entries;

  /// Le voci di un dominio, ordinate; con [activeOnly] solo quelle da proporre.
  List<CatalogEntry> domain(String domain, {bool activeOnly = true}) => entries
      .where((e) => e.domain == domain && (!activeOnly || e.active))
      .toList();

  /// La voce [id] del dominio, anche disattivata.
  CatalogEntry? find(String domain, String id) {
    for (final e in entries) {
      if (e.domain == domain && e.id == id) return e;
    }
    return null;
  }

  /// Dal file del repo (`entries`), dalla copia locale (`version` + `entries`)
  /// o dalle righe della tabella. [version] vince sul campo del JSON.
  factory Catalog.fromJson(Map<String, dynamic> json, {int? version}) {
    final righe = (json['entries'] as List<dynamic>? ?? const [])
        .map((e) => CatalogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return Catalog(
      version: version ?? (json['version'] as num?)?.toInt() ?? 0,
      entries: righe,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'entries': entries.map((e) => e.toJson()).toList(),
  };
}

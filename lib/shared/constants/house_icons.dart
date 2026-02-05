import 'package:flutter/material.dart';

/// Icone predefinite disponibili per le case.
/// 
/// Ogni casa può avere un'icona personalizzata scelta tra queste opzioni.
class HouseIcons {
  HouseIcons._(); // Costruttore privato per impedire l'istanziazione

  /// Mappa di tutte le icone disponibili.
  /// La chiave è il nome dell'icona (stringa), il valore è l'IconData corrispondente.
  static const Map<String, IconData> all = {
    'home': Icons.home_rounded,
    'apartment': Icons.apartment_rounded,
    'cottage': Icons.cottage_rounded,
    'house': Icons.house_rounded,
    'villa': Icons.villa_rounded,
    'cabin': Icons.cabin_rounded,
    'chalet': Icons.chalet_rounded,
    'warehouse': Icons.warehouse_rounded,
    'business': Icons.business_rounded,
    'location_city': Icons.location_city_rounded,
    'holiday_village': Icons.holiday_village_rounded,
    'castle': Icons.castle_rounded,
    'hotel': Icons.hotel_rounded,
    'store': Icons.store_rounded,
    'beach_access': Icons.beach_access_rounded,
    'terrain': Icons.terrain_rounded,
    'landscape': Icons.landscape_rounded,
  };

  /// Nomi visualizzabili per ogni icona
  static const Map<String, String> displayNames = {
    'home': 'Casa',
    'apartment': 'Appartamento',
    'cottage': 'Casetta',
    'house': 'Abitazione',
    'villa': 'Villa',
    'cabin': 'Baita',
    'chalet': 'Chalet',
    'warehouse': 'Magazzino',
    'business': 'Ufficio',
    'location_city': 'Città',
    'holiday_village': 'Villaggio',
    'castle': 'Castello',
    'hotel': 'Hotel',
    'store': 'Negozio',
    'beach_access': 'Casa al mare',
    'terrain': 'Campagna',
    'landscape': 'Paesaggio',
  };

  /// Restituisce l'IconData per un nome di icona dato.
  /// Se il nome non esiste, restituisce l'icona 'home' come default.
  static IconData getIcon(String iconName) {
    return all[iconName] ?? all['home']!;
  }

  /// Restituisce il nome visualizzabile per un nome di icona dato.
  /// Se il nome non esiste, restituisce 'Casa' come default.
  static String getDisplayName(String iconName) {
    return displayNames[iconName] ?? displayNames['home']!;
  }
}

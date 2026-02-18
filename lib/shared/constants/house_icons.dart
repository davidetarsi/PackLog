import 'package:flutter/material.dart';

/// Icone predefinite disponibili per le case.
/// 
/// Ogni casa può avere un'icona personalizzata scelta tra queste opzioni.
class HouseIcons {
  HouseIcons._(); // Costruttore privato per impedire l'istanziazione

  /// Mappa di tutte le icone disponibili.
  /// La chiave è il nome dell'icona (stringa), il valore è l'IconData corrispondente.
  /// Mappa icone con chiavi basate sul nome dell'icona Icons.*
  static const Map<String, IconData> all = {
    'home': Icons.home_rounded,
    'apartment': Icons.apartment_rounded,
    'business': Icons.business_rounded,
    'homeWork': Icons.home_work_rounded,
    'sailing': Icons.sailing_rounded,        // villaggio vacanze/mare
    'castle': Icons.castle_rounded,
    'hotel': Icons.hotel_rounded,
    'store': Icons.store_rounded,
    'beachAccess': Icons.beach_access_rounded,
    'landscape': Icons.landscape_rounded,
  };

  /// Nomi visualizzabili coerenti con le icone
  static const Map<String, String> displayNames = {
    'home': 'Casa',
    'apartment': 'Appartamento', 
    'business': 'Ufficio',
    'homeWork': 'Casa con ufficio',
    'sailing': 'Casa vacanze',
    'castle': 'Castello',
    'hotel': 'Hotel',
    'store': 'Negozio',
    'beachAccess': 'Casa al mare',
    'landscape': 'Casa in montagna',
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

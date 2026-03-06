import 'package:easy_localization/easy_localization.dart';
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
  static Map<String, String> get displayNames => {
    'home': 'house_icons.home'.tr(),
    'apartment': 'house_icons.apartment'.tr(), 
    'business': 'house_icons.business'.tr(),
    'homeWork': 'house_icons.homeWork'.tr(),
    'sailing': 'house_icons.sailing'.tr(),
    'castle': 'house_icons.castle'.tr(),
    'hotel': 'house_icons.hotel'.tr(),
    'store': 'house_icons.store'.tr(),
    'beachAccess': 'house_icons.beachAccess'.tr(),
    'landscape': 'house_icons.landscape'.tr(),
  };

  /// Restituisce l'IconData per un nome di icona dato.
  /// Se il nome non esiste, restituisce l'icona 'home' come default.
  static IconData getIcon(String iconName) {
    return all[iconName] ?? all['home']!;
  }

  /// Restituisce il nome visualizzabile per un nome di icona dato.
  /// Se il nome non esiste, restituisce la chiave 'house_icons.home' come default.
  static String getDisplayName(String iconName) {
    return displayNames[iconName] ?? displayNames['home']!;
  }
}

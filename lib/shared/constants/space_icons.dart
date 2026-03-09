import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Icone predefinite disponibili per gli spazi/armadi.
/// 
/// Ogni spazio può avere un'icona personalizzata scelta tra queste opzioni.
class SpaceIcons {
  SpaceIcons._();

  /// Mappa di tutte le icone disponibili per spazi.
  static const Map<String, IconData> all = {
    'meeting_room': Icons.meeting_room,
    'kitchen': Icons.kitchen,
    'bed': Icons.bed,
    'living': Icons.living,
    'bathroom': Icons.bathroom,
    'door_sliding': Icons.door_sliding,
    'garage': Icons.garage,
    'yard': Icons.yard,
    'balcony': Icons.balcony,
    'storage': Icons.storage,
    'workspaces': Icons.workspaces,
    'dining': Icons.restaurant,
    'desk': Icons.desk,
    'chair': Icons.chair,
    'shelves': Icons.shelves,
  };

  /// Nomi visualizzabili coerenti con le icone
  static Map<String, String> get displayNames => {
    'meeting_room': 'space_icons.meeting_room'.tr(),
    'kitchen': 'space_icons.kitchen'.tr(),
    'bed': 'space_icons.bed'.tr(),
    'living': 'space_icons.living'.tr(),
    'bathroom': 'space_icons.bathroom'.tr(),
    'door_sliding': 'space_icons.door_sliding'.tr(),
    'garage': 'space_icons.garage'.tr(),
    'yard': 'space_icons.yard'.tr(),
    'balcony': 'space_icons.balcony'.tr(),
    'storage': 'space_icons.storage'.tr(),
    'workspaces': 'space_icons.workspaces'.tr(),
    'dining': 'space_icons.dining'.tr(),
    'desk': 'space_icons.desk'.tr(),
    'chair': 'space_icons.chair'.tr(),
    'shelves': 'space_icons.shelves'.tr(),
  };

  /// Restituisce l'IconData per un nome di icona dato.
  /// Se il nome non esiste, restituisce l'icona 'meeting_room' come default.
  static IconData getIcon(String iconName) {
    return all[iconName] ?? all['meeting_room']!;
  }

  /// Restituisce il nome visualizzabile per un nome di icona dato.
  static String getDisplayName(String iconName) {
    return displayNames[iconName] ?? displayNames['meeting_room']!;
  }
}

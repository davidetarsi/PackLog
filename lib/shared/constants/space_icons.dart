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

  /// Restituisce l'IconData per un nome di icona dato.
  /// Se il nome non esiste, restituisce l'icona 'meeting_room' come default.
  static IconData getIcon(String iconName) {
    return all[iconName] ?? all['meeting_room']!;
  }
}

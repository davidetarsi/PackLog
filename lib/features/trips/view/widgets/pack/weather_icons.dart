import 'package:flutter/material.dart';

/// Icona di un codice meteo WMO, come lo dà Open-Meteo: sereno, poco nuvoloso,
/// coperto, nebbia, pioggia, neve, temporale. Con [night] il sereno è la luna.
IconData weatherCodeIcon(int? code, {bool night = false}) {
  if (code == null) return Icons.cloud_outlined;
  if (code <= 1) {
    return night ? Icons.nightlight_outlined : Icons.wb_sunny_outlined;
  }
  if (code == 2) return Icons.filter_drama_outlined;
  if (code == 3) return Icons.cloud_outlined;
  if (code == 45 || code == 48) return Icons.foggy;
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return Icons.ac_unit;
  }
  if (code >= 95) return Icons.thunderstorm_outlined;
  // 51-67 pioggerella e pioggia, 80-82 rovesci.
  return Icons.water_drop_outlined;
}

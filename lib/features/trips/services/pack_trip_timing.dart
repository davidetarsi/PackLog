import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tempo medio di una generazione finché non se ne conosce uno vero.
const kDefaultPackTripMs = 10000;

/// Quanto dura di solito `pack-trip` su questo telefono: l'attesa spartisce
/// questo tempo fra i suoi passi. Media semplice delle ultime generazioni
/// riuscite, salvata in locale (stesso schema della stima dell'import AI).
abstract final class PackTripTiming {
  static const _key = 'pack_trip_avg_ms';
  static const _keep = 5;
  static const _minMs = 3000;
  static const _maxMs = 60000;

  /// La stima in millisecondi; il valore di partenza se non c'è storia o il
  /// disco non risponde.
  static Future<int> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _average(_read(prefs)) ?? kDefaultPackTripMs;
    } catch (e) {
      debugPrint('[PackTripTiming] $e');
      return kDefaultPackTripMs;
    }
  }

  /// Aggiunge il tempo di una generazione riuscita. Chi chiama lo fa solo con
  /// i successi: errori e annullamenti non contano.
  static Future<void> record(Duration elapsed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = [..._read(prefs), elapsed.inMilliseconds];
      final recent = all.sublist(all.length > _keep ? all.length - _keep : 0);
      await prefs.setStringList(_key, [for (final ms in recent) '$ms']);
    } catch (e) {
      debugPrint('[PackTripTiming] $e');
    }
  }

  static List<int> _read(SharedPreferences prefs) => [
    for (final raw in prefs.getStringList(_key) ?? const <String>[])
      ?int.tryParse(raw),
  ];

  static int? _average(List<int> values) {
    if (values.isEmpty) return null;
    final mean = values.reduce((a, b) => a + b) / values.length;
    return mean.round().clamp(_minMs, _maxMs);
  }
}

import 'dart:convert';

import 'package:drift/drift.dart';

/// Drift [TypeConverter] that maps `List<String>` ↔ `String` (JSON array).
///
/// Used by columns that need to store ordered string collections in SQLite
/// (e.g. [Trips.extraEvents], [Trips.weatherTags]).
///
/// Null-safe: a decode error or unexpected type silently falls back to `[]`
/// rather than throwing, so corrupted rows never crash the app.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    try {
      final decoded = jsonDecode(fromDb);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

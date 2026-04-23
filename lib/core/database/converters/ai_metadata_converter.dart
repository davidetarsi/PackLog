import 'dart:convert';

import 'package:drift/drift.dart';

/// Drift [TypeConverter] that maps `Map<String, dynamic>` ↔ `String` (JSON).
///
/// Used by the [Items.aiMetadata] column to persist arbitrary AI-extracted
/// metadata as a compact JSON blob in SQLite, while exposing a typed Dart
/// map to the application layer.
///
/// Null-safe: a null value in the database is returned as null by Drift before
/// this converter is even invoked (the column is declared with `.nullable()`).
class AiMetadataConverter
    extends TypeConverter<Map<String, dynamic>, String> {
  const AiMetadataConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) {
    return jsonDecode(fromDb) as Map<String, dynamic>;
  }

  @override
  String toSql(Map<String, dynamic> value) {
    return jsonEncode(value);
  }
}

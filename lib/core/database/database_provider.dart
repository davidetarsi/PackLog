import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'database.dart';

part 'database_provider.g.dart';

/// Provider singleton per il database Drift.
/// 
/// Viene creato una sola volta e mantenuto per tutta la vita dell'app.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase();
  
  // Chiudi il database quando il provider viene distrutto
  ref.onDispose(() {
    database.close();
  });
  
  return database;
}

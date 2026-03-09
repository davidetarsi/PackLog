import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/luggage_model.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/services/persistence_services.dart';
import 'drift_luggage_repository.dart';

part 'luggage_repository.g.dart';

@Riverpod(keepAlive: true)
LuggageRepository luggageRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final dbService = ref.watch(databaseServiceProvider);
  return DriftLuggageRepository(database.luggagesDao, dbService);
}

/// Interfaccia astratta per il repository dei bagagli.
/// 
/// Definisce le operazioni CRUD per i bagagli riutilizzabili
/// e la gestione delle associazioni con i viaggi (M:N).
abstract class LuggageRepository {
  Future<bool> init();
  Future<void> addLuggage(LuggageModel model);
  Future<LuggageModel> getLuggageById(String id);
  Future<List<LuggageModel>> getAllLuggages();
  Future<List<LuggageModel>> getLuggagesByHouseId(String houseId);
  Future<bool> deleteLuggage(String id);
  Future<void> updateLuggage(LuggageModel model);
  
  /// Conta il numero di bagagli in una casa
  Future<int> countLuggagesByHouse(String houseId);
  
  /// Ottiene i bagagli associati a un viaggio specifico (via junction table)
  Future<List<LuggageModel>> getLuggagesByTripId(String tripId);
  
  /// Associa un bagaglio a un viaggio
  Future<void> linkLuggageToTrip(String tripId, String luggageId);
  
  /// Rimuove l'associazione tra un bagaglio e un viaggio
  Future<void> unlinkLuggageFromTrip(String tripId, String luggageId);
  
  /// Sostituisce tutti i bagagli di un viaggio
  Future<void> replaceTripLuggages(String tripId, List<String> luggageIds);
}

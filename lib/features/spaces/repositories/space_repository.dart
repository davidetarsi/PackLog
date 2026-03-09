import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/space_model.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/services/persistence_services.dart';
import 'drift_space_repository.dart';

part 'space_repository.g.dart';

@Riverpod(keepAlive: true)
SpaceRepository spaceRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final dbService = ref.watch(databaseServiceProvider);
  return DriftSpaceRepository(database.spacesDao, dbService);
}

/// Interfaccia astratta per il repository degli spazi.
/// 
/// Definisce le operazioni CRUD per gli spazi/armadi all'interno delle case.
abstract class SpaceRepository {
  Future<bool> init();
  Future<void> addSpace(SpaceModel model);
  Future<SpaceModel> getSpaceById(String id);
  Future<List<SpaceModel>> getAllSpaces();
  Future<List<SpaceModel>> getSpacesByHouseId(String houseId);
  Future<bool> deleteSpace(String id);
  Future<void> updateSpace(SpaceModel model);
  
  /// Conta il numero di spazi in una casa
  Future<int> countSpacesByHouse(String houseId);
}

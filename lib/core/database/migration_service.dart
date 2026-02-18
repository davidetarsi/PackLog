import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/houses/model/house_model.dart';
import '../../features/items/model/item_model.dart';
import '../../features/trips/model/trip_model.dart';
import '../../shared/constants/app_constants.dart';
import 'converters/item_category_converter.dart';
import 'converters/location_type_converter.dart';
import 'database.dart';

/// Chiave per tracciare se la migrazione è già stata eseguita.
const String _migrationCompletedKey = 'drift_migration_completed';

/// Servizio per migrare i dati da SharedPreferences a Drift.
/// 
/// Questa migrazione viene eseguita una sola volta al primo avvio
/// dopo l'aggiornamento dell'app. I dati vengono copiati da
/// SharedPreferences al database SQLite, poi le vecchie chiavi
/// vengono eliminate.
/// 
/// **NOTA**: Questo file può essere eliminato in una versione futura
/// quando tutti gli utenti avranno migrato i dati.
class MigrationService {
  final AppDatabase _database;
  final SharedPreferences _prefs;

  MigrationService(this._database, this._prefs);

  /// Verifica se la migrazione è già stata completata.
  bool get isMigrationCompleted {
    return _prefs.getBool(_migrationCompletedKey) ?? false;
  }

  /// Esegue la migrazione se necessario.
  /// 
  /// Ritorna `true` se la migrazione è stata eseguita o era già completata,
  /// `false` se c'è stato un errore.
  Future<bool> migrateIfNeeded() async {
    // Se già migrato, non fare nulla
    if (isMigrationCompleted) {
      debugPrint('Migrazione già completata');
      return true;
    }

    // Verifica se ci sono dati da migrare
    final hasData = _hasLegacyData();
    
    if (!hasData) {
      // Nessun dato da migrare, segna come completato
      debugPrint('Nessun dato legacy da migrare');
      await _prefs.setBool(_migrationCompletedKey, true);
      return true;
    }

    debugPrint('Inizio migrazione da SharedPreferences a Drift...');

    try {
      // Esegui la migrazione
      await _migrateData();
      
      // Elimina i vecchi dati
      await _clearLegacyData();
      
      // Segna la migrazione come completata
      await _prefs.setBool(_migrationCompletedKey, true);
      
      debugPrint('Migrazione completata con successo!');
      return true;
    } catch (e, stackTrace) {
      // In caso di errore, non segnare come completato
      // così può essere ritentata al prossimo avvio
      debugPrint('Errore durante la migrazione: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Verifica se ci sono dati legacy in SharedPreferences.
  bool _hasLegacyData() {
    final hasHouses = _prefs.containsKey(AppConstants.housesKey);
    final hasItems = _prefs.containsKey(AppConstants.itemsKey);
    final hasTrips = _prefs.containsKey(AppConstants.tripsKey);
    debugPrint('Dati legacy: houses=$hasHouses, items=$hasItems, trips=$hasTrips');
    return hasHouses || hasItems || hasTrips;
  }

  /// Migra tutti i dati da SharedPreferences a Drift.
  Future<void> _migrateData() async {
    // 1. Migra le case (devono essere migrate prima degli items)
    final houses = _loadHousesFromPrefs();
    debugPrint('Case da migrare: ${houses.length}');
    if (houses.isNotEmpty) {
      await _migrateHouses(houses);
    }

    // 2. Migra gli oggetti
    final items = _loadItemsFromPrefs();
    debugPrint('Items da migrare: ${items.length}');
    if (items.isNotEmpty) {
      await _migrateItems(items);
    }

    // 3. Migra i viaggi (con i loro trip items)
    final trips = _loadTripsFromPrefs();
    debugPrint('Viaggi da migrare: ${trips.length}');
    if (trips.isNotEmpty) {
      await _migrateTrips(trips);
    }
  }

  /// Carica le case da SharedPreferences.
  List<HouseModel> _loadHousesFromPrefs() {
    final housesJson = _prefs.getStringList(AppConstants.housesKey) ?? [];
    return housesJson
        .map((json) => HouseModel.fromJson(jsonDecode(json)))
        .toList();
  }

  /// Carica gli oggetti da SharedPreferences.
  List<ItemModel> _loadItemsFromPrefs() {
    final itemsJson = _prefs.getStringList(AppConstants.itemsKey) ?? [];
    return itemsJson
        .map((json) => ItemModel.fromJson(jsonDecode(json)))
        .toList();
  }

  /// Carica i viaggi da SharedPreferences.
  List<TripModel> _loadTripsFromPrefs() {
    final tripsJson = _prefs.getStringList(AppConstants.tripsKey) ?? [];
    final List<TripModel> trips = [];
    
    for (int i = 0; i < tripsJson.length; i++) {
      try {
        final trip = TripModel.fromJson(jsonDecode(tripsJson[i]));
        trips.add(trip);
        debugPrint('Viaggio caricato: ${trip.name} (id: ${trip.id})');
      } catch (e) {
        debugPrint('Errore nel parsing del viaggio $i: $e');
        debugPrint('JSON: ${tripsJson[i]}');
      }
    }
    
    return trips;
  }

  /// Migra le case nel database Drift.
  Future<void> _migrateHouses(List<HouseModel> houses) async {
    final companions = houses.map((house) => HousesCompanion(
      id: Value(house.id),
      name: Value(house.name),
      description: Value(house.description),
      createdAt: Value(house.createdAt),
      updatedAt: Value(house.updatedAt),
    )).toList();

    await _database.housesDao.insertMultipleHouses(companions);
    debugPrint('Case migrate: ${houses.length}');
  }

  /// Migra gli oggetti nel database Drift.
  Future<void> _migrateItems(List<ItemModel> items) async {
    final companions = items.map((item) => ItemsCompanion(
      id: Value(item.id),
      houseId: Value(item.houseId),
      name: Value(item.name),
      category: Value(ItemCategoryConverter.toDatabase(item.category)),
      description: Value(item.description),
      quantity: Value(item.quantity),
      createdAt: Value(item.createdAt),
      updatedAt: Value(item.updatedAt),
    )).toList();

    await _database.itemsDao.insertMultipleItems(companions);
    debugPrint('Items migrati: ${items.length}');
  }

  /// Migra i viaggi nel database Drift.
  Future<void> _migrateTrips(List<TripModel> trips) async {
    int successCount = 0;
    int errorCount = 0;
    
    for (final trip in trips) {
      try {
        // Log delle date per debug
        debugPrint('Migrando viaggio: ${trip.name}');
        debugPrint('  departureDateTime: ${trip.departureDateTime}');
        debugPrint('  returnDateTime: ${trip.returnDateTime}');
        debugPrint('  destinationHouseId: ${trip.destinationHouseId}');
        debugPrint('  destinationDisplayName: ${trip.destinationDisplayName}');
        
        // Inserisci il viaggio
        final location = trip.destinationLocation;
        
        final tripCompanion = TripsCompanion(
          id: Value(trip.id),
          name: Value(trip.name),
          description: Value(trip.description),
          departureDateTime: Value(trip.departureDateTime),
          returnDateTime: Value(trip.returnDateTime),
          destinationHouseId: Value(trip.destinationHouseId),
          locationPlaceId: Value(location?.placeId),
          locationDisplayName: Value(location?.displayName ?? trip.destinationDisplayName),
          locationName: Value(location?.name),
          locationCity: Value(location?.city),
          locationState: Value(location?.state),
          locationCountry: Value(location?.country),
          locationType: Value(location != null 
              ? LocationTypeConverter.toDatabase(location.locationType)
              : null),
          locationLat: Value(location?.lat),
          locationLon: Value(location?.lon),
          isSaved: Value(trip.isSaved),
          createdAt: Value(trip.createdAt),
          updatedAt: Value(trip.updatedAt),
        );

        await _database.tripsDao.insertTrip(tripCompanion);

        // Inserisci gli oggetti del viaggio
        if (trip.items.isNotEmpty) {
          final tripItemCompanions = trip.items.map((item) => TripItemEntriesCompanion(
            id: Value(item.id),
            tripId: Value(trip.id),
            name: Value(item.name),
            category: Value(item.category.name),
            quantity: Value(item.quantity),
            originHouseId: Value(item.originHouseId),
            isChecked: Value(item.isChecked),
          )).toList();

          await _database.tripsDao.insertMultipleTripItems(tripItemCompanions);
          debugPrint('  Items del viaggio migrati: ${trip.items.length}');
        }
        
        successCount++;
        debugPrint('  Viaggio migrato con successo!');
      } catch (e, stackTrace) {
        errorCount++;
        debugPrint('  ERRORE migrando viaggio ${trip.name}: $e');
        debugPrint('  Stack: $stackTrace');
        // Continua con il prossimo viaggio invece di fermare tutto
      }
    }
    
    debugPrint('Viaggi migrati: $successCount successi, $errorCount errori');
    
    // Se tutti i viaggi hanno fallito, solleva un'eccezione
    if (successCount == 0 && trips.isNotEmpty) {
      throw Exception('Tutti i viaggi hanno fallito la migrazione');
    }
  }

  /// Elimina i vecchi dati da SharedPreferences.
  Future<void> _clearLegacyData() async {
    await _prefs.remove(AppConstants.housesKey);
    await _prefs.remove(AppConstants.itemsKey);
    await _prefs.remove(AppConstants.tripsKey);
    debugPrint('Dati legacy eliminati da SharedPreferences');
  }
}

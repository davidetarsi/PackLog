import 'package:flutter_test/flutter_test.dart';
import 'package:stuff_tracker_2/features/houses/model/house_model.dart';
import 'package:stuff_tracker_2/shared/model/location_suggestion_model.dart';
import 'package:stuff_tracker_2/shared/model/location_type.dart';

/// Unit tests for HouseModel domain logic.
/// 
/// Tests pure domain methods including:
/// - Location display name formatting
/// - City name extraction
/// - Graceful fallbacks for null/empty location data
/// - Factory methods
void main() {
  group('HouseModel - Location Display Name', () {
    test('should return location displayName when location is set', () {
      // === ARRANGE ===
      final house = HouseModel(
        id: 'house-1',
        name: 'My Apartment',
        location: LocationSuggestionModel(
          placeId: 'place-123',
          displayName: 'Milan, Italy',
          city: 'Milan',
          country: 'Italy',
          locationType: LocationType.city,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      final displayName = house.locationDisplayName;

      // === ASSERT ===
      expect(displayName, equals('Milan, Italy'));
    });

    test('should return null when location is not set', () {
      // === ARRANGE ===
      final house = HouseModel(
        id: 'house-2',
        name: 'House without Location',
        location: null, // No location
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      final displayName = house.locationDisplayName;

      // === ASSERT ===
      expect(displayName, equals(null));
    });

    test('should gracefully handle location with empty displayName', () {
      // === ARRANGE ===
      final house = HouseModel(
        id: 'house-3',
        name: 'House',
        location: LocationSuggestionModel(
          placeId: 'place-empty',
          displayName: '', // Empty string
          locationType: LocationType.other,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      final displayName = house.locationDisplayName;

      // === ASSERT ===
      expect(displayName, equals(''), reason: 'Empty string is returned as-is');
    });
  });

  group('HouseModel - City Name', () {
    test('should return city name when location has city field', () {
      // === ARRANGE ===
      final house = HouseModel(
        id: 'house-city',
        name: 'House',
        location: LocationSuggestionModel(
          placeId: 'place-456',
          displayName: 'Rome, Lazio, Italy',
          city: 'Rome',
          state: 'Lazio',
          country: 'Italy',
          locationType: LocationType.city,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      final cityName = house.cityName;

      // === ASSERT ===
      expect(cityName, equals('Rome'));
    });

    test('should return null when location is not set', () {
      // === ARRANGE ===
      final house = HouseModel(
        id: 'house-no-location',
        name: 'House',
        location: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      final cityName = house.cityName;

      // === ASSERT ===
      expect(cityName, equals(null));
    });

    test('should return null when location has no city field', () {
      // === ARRANGE ===
      // Location represents a country or state, not a city
      final house = HouseModel(
        id: 'house-country',
        name: 'House',
        location: LocationSuggestionModel(
          placeId: 'place-789',
          displayName: 'Italy',
          country: 'Italy',
          city: null, // No city field
          locationType: LocationType.country,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      final cityName = house.cityName;

      // === ASSERT ===
      expect(cityName, equals(null));
    });

    test('should gracefully handle location with empty city string', () {
      // === ARRANGE ===
      final house = HouseModel(
        id: 'house-empty-city',
        name: 'House',
        location: LocationSuggestionModel(
          placeId: 'place-empty-city',
          displayName: 'Some Location',
          city: '', // Empty string
          locationType: LocationType.other,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT ===
      final cityName = house.cityName;

      // === ASSERT ===
      expect(cityName, equals(''), reason: 'Empty string is returned as-is');
    });
  });

  group('HouseModel - Factory Methods', () {
    test('should create empty house with empty() factory', () {
      // === ACT ===
      final emptyHouse = HouseModel.empty();

      // === ASSERT ===
      expect(emptyHouse.id, equals(''));
      expect(emptyHouse.name, equals(''));
      expect(emptyHouse.description, equals(null));
      expect(emptyHouse.location, equals(null));
      expect(emptyHouse.iconName, equals('home'), reason: 'Default icon');
      expect(emptyHouse.isPrimary, isFalse, reason: 'Default not primary');
    });
  });

  group('HouseModel - Icon and Primary Flag', () {
    test('should use default icon name when not specified', () {
      // === ARRANGE ===
      final house = HouseModel(
        id: 'house-default-icon',
        name: 'House',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT & ASSERT ===
      expect(house.iconName, equals('home'));
    });

    test('should preserve custom icon name', () {
      // === ARRANGE ===
      final house = HouseModel(
        id: 'house-custom-icon',
        name: 'House',
        iconName: 'apartment',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT & ASSERT ===
      expect(house.iconName, equals('apartment'));
    });

    test('should default to non-primary house', () {
      // === ARRANGE ===
      final house = HouseModel(
        id: 'house-non-primary',
        name: 'House',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT & ASSERT ===
      expect(house.isPrimary, isFalse);
    });

    test('should allow setting house as primary', () {
      // === ARRANGE ===
      final house = HouseModel(
        id: 'house-primary',
        name: 'Main House',
        isPrimary: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // === ACT & ASSERT ===
      expect(house.isPrimary, isTrue);
    });
  });
}

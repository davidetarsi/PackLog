import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'analytics_service.dart';

part 'core_analytics_service.g.dart';

class CoreAnalyticsService {
  final AppAnalyticsService _analytics;

  CoreAnalyticsService(this._analytics);

  Future<void> trackHouseCreated({
    required String houseId,
    required int totalHouses,
  }) {
    return _analytics.logEvent(
      'House_Created',
      properties: {
        'house_id': houseId,
        'is_first_house': totalHouses == 1,
      },
    );
  }

  Future<void> trackItemAdded({
    required String itemId,
    required String category,
    required int totalItems,
  }) {
    return _analytics.logEvent(
      'Item_Added',
      properties: {
        'item_id': itemId,
        'item_category': category,
        'is_first_item': totalItems == 1,
      },
    );
  }

  Future<void> trackTripCreated({
    required String tripId,
    required int totalTrips,
  }) {
    return _analytics.logEvent(
      'Trip_Created',
      properties: {
        'trip_id': tripId,
        'is_first_trip': totalTrips == 1,
      },
    );
  }
}

@Riverpod(keepAlive: true)
CoreAnalyticsService coreAnalyticsService(Ref ref) {
  return CoreAnalyticsService(ref.read(analyticsServiceProvider));
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'analytics_service.dart';

part 'core_analytics_service.g.dart';

// Analytics event names and properties use String (not domain enums) intentionally:
// this layer lives in core/ and must not import from features/.
// Callers convert enums to strings with .name before passing them here.
class CoreAnalyticsService {
  final AppAnalyticsService _analytics;

  CoreAnalyticsService(this._analytics);

  void _safeLogEvent(String eventName, {Map<String, dynamic>? properties}) {
    () async {
      try {
        await _analytics.logEvent(eventName, properties: properties);
      } catch (e) {
        // Defense-in-depth: AppAnalyticsService.logEvent already catches internally,
        // but this guards against future implementations that may not.
        debugPrint('[Analytics] _safeLogEvent failed for $eventName: $e');
      }
    }();
  }

  // ── house_ ────────────────────────────────────────────────────────────────

  void trackHouseCreated({required String houseId, required int totalHouses}) {
    _safeLogEvent(
      'house_created',
      properties: {'house_id': houseId, 'is_first_house': totalHouses == 1},
    );
  }

  void trackHouseUpdated() => _safeLogEvent('house_updated');

  void trackHouseDeleted() => _safeLogEvent('house_deleted');

  void trackHouseDuplicated() => _safeLogEvent('house_duplicated');

  // ── item_ ─────────────────────────────────────────────────────────────────

  void trackItemAdded({
    required String itemId,
    required String category,
    required int totalItems,
  }) {
    _safeLogEvent(
      'item_added',
      properties: {
        'item_id': itemId,
        'item_category': category,
        'is_first_item': totalItems == 1,
      },
    );
  }

  void trackItemUpdated({required String category}) {
    _safeLogEvent('item_updated', properties: {'item_category': category});
  }

  void trackItemDeleted({required String category}) {
    _safeLogEvent('item_deleted', properties: {'item_category': category});
  }

  void trackItemBulkDeleted({required int count}) {
    _safeLogEvent('item_bulk_deleted', properties: {'count': count});
  }

  void trackItemBulkMoved({required int count}) {
    _safeLogEvent('item_bulk_moved', properties: {'count': count});
  }

  void trackItemsAddedToTrip({required String tripId, required int count}) {
    _safeLogEvent(
      'items_added_to_trip',
      properties: {'trip_id': tripId, 'count': count},
    );
  }

  // ── space_ ────────────────────────────────────────────────────────────────

  void trackSpaceCreated() => _safeLogEvent('space_created');

  // ── luggage_ ──────────────────────────────────────────────────────────────

  void trackLuggageCreated({required String size}) {
    _safeLogEvent('luggage_created', properties: {'size': size});
  }

  // ── trip_ ─────────────────────────────────────────────────────────────────

  void trackTripCreated({required String tripId, required int totalTrips}) {
    _safeLogEvent(
      'trip_created',
      properties: {'trip_id': tripId, 'is_first_trip': totalTrips == 1},
    );
  }

  void trackTripUpdated() => _safeLogEvent('trip_updated');

  void trackTripDeleted() => _safeLogEvent('trip_deleted');

  void trackTripDuplicated() => _safeLogEvent('trip_duplicated');

  void trackTripSavedToggled({required bool isSaved}) {
    _safeLogEvent('trip_saved_toggled', properties: {'is_saved': isSaved});
  }

  // ── bulk_ ─────────────────────────────────────────────────────────────────

  void trackBulkTemplateToggled({
    required String templateKey,
    required bool isSelected,
    required int totalSelected,
  }) {
    _safeLogEvent(
      'bulk_template_toggled',
      properties: {
        'template_key': templateKey,
        'is_selected': isSelected,
        'total_selected': totalSelected,
      },
    );
  }

  void trackBulkGenderSet({required String gender}) {
    _safeLogEvent('bulk_gender_set', properties: {'gender': gender});
  }

  void trackBulkSessionSaved({
    required int itemCount,
    required int templateCount,
    required bool hasManualItems,
  }) {
    _safeLogEvent(
      'bulk_session_saved',
      properties: {
        'item_count': itemCount,
        'template_count': templateCount,
        'has_manual_items': hasManualItems,
      },
    );
  }

  // ── ai_ ───────────────────────────────────────────────────────────────────

  void trackAiInputSubmitted() => _safeLogEvent('ai_input_submitted');

  void trackAiInputCompleted({required int itemCount}) {
    _safeLogEvent('ai_input_completed', properties: {'item_count': itemCount});
  }

  void trackAiInputFailed({required String errorType}) {
    _safeLogEvent('ai_input_failed', properties: {'error_type': errorType});
  }

  void trackAiItemsSaved({required int count, required bool isOnboarding}) {
    _safeLogEvent(
      'ai_items_saved',
      properties: {'count': count, 'is_onboarding': isOnboarding},
    );
  }

  // ── onboarding_ ───────────────────────────────────────────────────────────

  void trackOnboardingStarted() => _safeLogEvent('onboarding_started');

  void trackOnboardingCompleted() => _safeLogEvent('onboarding_completed');

  // ── auth_ ─────────────────────────────────────────────────────────────────

  void trackLoginCompleted() => _safeLogEvent('login_completed');

  void trackLogout() => _safeLogEvent('logout');

  // ── screen_ ───────────────────────────────────────────────────────────────

  void trackScreenView(String screenName) {
    _safeLogEvent('screen_view', properties: {'screen_name': screenName});
  }

  // ── sync_ ─────────────────────────────────────────────────────────────────

  void trackSyncFailed({required String entity, required String errorType}) {
    _safeLogEvent(
      'sync_failed',
      properties: {'entity': entity, 'error_type': errorType},
    );
  }
}

@Riverpod(keepAlive: true)
CoreAnalyticsService coreAnalyticsService(Ref ref) {
  return CoreAnalyticsService(ref.read(analyticsServiceProvider));
}

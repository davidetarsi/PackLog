import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';

class MockAppAnalyticsService extends Mock implements AppAnalyticsService {}

void main() {
  late MockAppAnalyticsService mockAnalytics;
  late CoreAnalyticsService service;

  setUp(() {
    mockAnalytics = MockAppAnalyticsService();
    when(
      () => mockAnalytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    service = CoreAnalyticsService(mockAnalytics);
  });

  // Flush fire-and-forget microtasks
  Future<void> pump() => Future.delayed(Duration.zero);

  group('rename — snake_case', () {
    test('trackHouseCreated logs house_created', () async {
      service.trackHouseCreated(houseId: 'h1', totalHouses: 1);
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'house_created',
          properties: {'house_id': 'h1', 'is_first_house': true},
        ),
      ).called(1);
    });

    test('trackItemAdded logs item_added', () async {
      service.trackItemAdded(itemId: 'i1', category: 'tops', totalItems: 1);
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'item_added',
          properties: {
            'item_id': 'i1',
            'item_category': 'tops',
            'is_first_item': true,
          },
        ),
      ).called(1);
    });

    test('trackTripCreated logs trip_created', () async {
      service.trackTripCreated(tripId: 't1', totalTrips: 2);
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'trip_created',
          properties: {'trip_id': 't1', 'is_first_trip': false},
        ),
      ).called(1);
    });
  });

  group('house events', () {
    test('trackHouseDeleted logs house_deleted', () async {
      service.trackHouseDeleted();
      await pump();
      verify(
        () => mockAnalytics.logEvent('house_deleted', properties: null),
      ).called(1);
    });

    test('trackHouseDuplicated logs house_duplicated', () async {
      service.trackHouseDuplicated();
      await pump();
      verify(
        () => mockAnalytics.logEvent('house_duplicated', properties: null),
      ).called(1);
    });
  });

  group('item events', () {
    test('trackItemDeleted logs item_deleted with category', () async {
      service.trackItemDeleted(category: 'shoes');
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'item_deleted',
          properties: {'item_category': 'shoes'},
        ),
      ).called(1);
    });

    test('trackItemBulkDeleted logs item_bulk_deleted with count', () async {
      service.trackItemBulkDeleted(count: 5);
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'item_bulk_deleted',
          properties: {'count': 5},
        ),
      ).called(1);
    });

    test('trackItemBulkMoved logs item_bulk_moved with count', () async {
      service.trackItemBulkMoved(count: 3);
      await pump();
      verify(
        () =>
            mockAnalytics.logEvent('item_bulk_moved', properties: {'count': 3}),
      ).called(1);
    });
  });

  group('space + luggage events', () {
    test('trackSpaceCreated logs space_created', () async {
      service.trackSpaceCreated();
      await pump();
      verify(
        () => mockAnalytics.logEvent('space_created', properties: null),
      ).called(1);
    });

    test('trackLuggageCreated logs luggage_created with size', () async {
      service.trackLuggageCreated(size: 'cabin_baggage');
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'luggage_created',
          properties: {'size': 'cabin_baggage'},
        ),
      ).called(1);
    });
  });

  group('trip events', () {
    test('trackTripDeleted logs trip_deleted', () async {
      service.trackTripDeleted();
      await pump();
      verify(
        () => mockAnalytics.logEvent('trip_deleted', properties: null),
      ).called(1);
    });

    test('trackTripDuplicated logs trip_duplicated', () async {
      service.trackTripDuplicated();
      await pump();
      verify(
        () => mockAnalytics.logEvent('trip_duplicated', properties: null),
      ).called(1);
    });

    test(
      'trackTripSavedToggled logs trip_saved_toggled with is_saved',
      () async {
        service.trackTripSavedToggled(isSaved: true);
        await pump();
        verify(
          () => mockAnalytics.logEvent(
            'trip_saved_toggled',
            properties: {'is_saved': true},
          ),
        ).called(1);
      },
    );
  });

  group('bulk events', () {
    test('trackBulkTemplateToggled logs bulk_template_toggled', () async {
      service.trackBulkTemplateToggled(
        templateKey: 'beach',
        isSelected: true,
        totalSelected: 2,
      );
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'bulk_template_toggled',
          properties: {
            'template_key': 'beach',
            'is_selected': true,
            'total_selected': 2,
          },
        ),
      ).called(1);
    });

    test('trackBulkGenderSet logs bulk_gender_set', () async {
      service.trackBulkGenderSet(gender: 'male');
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'bulk_gender_set',
          properties: {'gender': 'male'},
        ),
      ).called(1);
    });

    test('trackBulkSessionSaved logs bulk_session_saved', () async {
      service.trackBulkSessionSaved(
        itemCount: 10,
        templateCount: 2,
        hasManualItems: true,
      );
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'bulk_session_saved',
          properties: {
            'item_count': 10,
            'template_count': 2,
            'has_manual_items': true,
          },
        ),
      ).called(1);
    });
  });

  group('ai events', () {
    test('trackAiInputSubmitted logs ai_input_submitted', () async {
      service.trackAiInputSubmitted();
      await pump();
      verify(
        () => mockAnalytics.logEvent('ai_input_submitted', properties: null),
      ).called(1);
    });

    test(
      'trackAiInputCompleted logs ai_input_completed with item_count',
      () async {
        service.trackAiInputCompleted(itemCount: 4);
        await pump();
        verify(
          () => mockAnalytics.logEvent(
            'ai_input_completed',
            properties: {'item_count': 4},
          ),
        ).called(1);
      },
    );

    test('trackAiInputFailed logs ai_input_failed with error_type', () async {
      service.trackAiInputFailed(errorType: 'VisionAnalysisException');
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'ai_input_failed',
          properties: {'error_type': 'VisionAnalysisException'},
        ),
      ).called(1);
    });
  });

  group('resilienza', () {
    test('analytics failure non propaga eccezione al chiamante', () async {
      when(
        () =>
            mockAnalytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenThrow(Exception('network error'));

      expect(() => service.trackHouseDeleted(), returnsNormally);
      await pump();
    });
  });
}

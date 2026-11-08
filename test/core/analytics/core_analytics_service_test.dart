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
    when(() => mockAnalytics.logPageview(any())).thenAnswer((_) async {});
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
      service.trackItemAdded(
        itemId: 'i1',
        houseId: 'h1',
        category: 'tops',
        totalItems: 1,
      );
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'item_added',
          properties: {
            'item_id': 'i1',
            'house_id': 'h1',
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
          properties: {
            'trip_id': 't1',
            'is_first_trip': false,
            'trip_number': 2,
          },
        ),
      ).called(1);
    });

    test('trackTripCreated con i giorni alla partenza', () async {
      service.trackTripCreated(tripId: 't', totalTrips: 3, daysToDeparture: 10);
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'trip_created',
          properties: {
            'trip_id': 't',
            'is_first_trip': false,
            'trip_number': 3,
            'days_to_departure': 10,
          },
        ),
      ).called(1);
    });
  });

  group('trip_created source', () {
    test('trackTripCreated porta source', () async {
      service.trackTripCreated(tripId: 't', totalTrips: 1, source: 'reuse');
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'trip_created',
          properties: {
            'trip_id': 't',
            'is_first_trip': true,
            'trip_number': 1,
            'source': 'reuse',
          },
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

  group('update events (P2 #14)', () {
    test('trackHouseUpdated emits house_updated with no properties', () async {
      service.trackHouseUpdated();
      await pump();
      verify(
        () => mockAnalytics.logEvent('house_updated', properties: null),
      ).called(1);
    });

    test(
      'trackItemDetailsEdited emits item_details_edited with source and fields',
      () async {
        service.trackItemDetailsEdited(source: 'house', fields: ['warmth']);
        await pump();
        verify(
          () => mockAnalytics.logEvent(
            'item_details_edited',
            properties: {
              'source': 'house',
              'fields': ['warmth'],
            },
          ),
        ).called(1);
      },
    );

    test('trackItemUpdated emits item_updated with category', () async {
      service.trackItemUpdated(category: 'vestiti');
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'item_updated',
          properties: {'item_category': 'vestiti'},
        ),
      ).called(1);
    });

    test('trackTripUpdated emits trip_updated with no properties', () async {
      service.trackTripUpdated();
      await pump();
      verify(
        () => mockAnalytics.logEvent('trip_updated', properties: null),
      ).called(1);
    });
  });

  group('navigazione', () {
    // Su tgram la navigazione deve essere un pageview e non un evento custom:
    // `top_pages` legge solo i pageview, e con `track('screen_view')` resta
    // vuota per sempre.
    test('trackScreenView passa da logPageview, non da logEvent', () async {
      service.trackScreenView('house-detail');
      await pump();

      verify(() => mockAnalytics.logPageview('house-detail')).called(1);
      verifyNever(
        () => mockAnalytics.logEvent(
          'screen_view',
          properties: any(named: 'properties'),
        ),
      );
    });
  });

  group('auth funnel (P2 #14)', () {
    test('trackLogout emits logout', () async {
      service.trackLogout();
      await pump();
      verify(
        () => mockAnalytics.logEvent('logout', properties: null),
      ).called(1);
    });
  });

  group('AI & onboarding funnel (P2 #14)', () {
    test('trackAiItemsSaved: conteggi della scansione', () async {
      service.trackAiItemsSaved(
        count: 4,
        isOnboarding: true,
        found: 6,
        excluded: 2,
        renamed: 1,
        detailsEdited: 1,
        photos: 2,
        excludedTypes: const ['Jewelry', 'Other'],
        renamedTypes: const ['Shorts'],
      );
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'ai_items_saved',
          properties: {
            'count': 4,
            'is_onboarding': true,
            'found': 6,
            'excluded': 2,
            'renamed': 1,
            'details_edited': 1,
            'photos': 2,
            'excluded_types': ['Jewelry', 'Other'],
            'renamed_types': ['Shorts'],
          },
        ),
      ).called(1);
    });

    test('trackAiScanDoubtResolved', () async {
      service.trackAiScanDoubtResolved(
        doubtFields: const ['warmth', 'formality'],
        choseJev: const ['warmth'],
        keptGpt: const ['formality'],
        otherValue: const [],
        correctedWithoutDoubt: const ['baseColor'],
        subCategory: 'Sweater',
      );
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'ai_scan_doubt_resolved',
          properties: {
            'doubt_fields': ['warmth', 'formality'],
            'chose_jev': ['warmth'],
            'kept_gpt': ['formality'],
            'other_value': <String>[],
            'corrected_without_doubt': ['baseColor'],
            'sub_category': 'Sweater',
          },
        ),
      ).called(1);
    });

    test(
      'trackAlreadyHereOpened logs whether manual candidates exist',
      () async {
        service.trackAlreadyHereOpened(hasManualCandidates: true);
        await pump();
        verify(
          () => mockAnalytics.logEvent(
            'already_here_opened',
            properties: {'has_manual_candidates': true},
          ),
        ).called(1);
      },
    );

    test('trackOnboardingStarted logs onboarding_started', () async {
      service.trackOnboardingStarted();
      await pump();
      verify(
        () => mockAnalytics.logEvent('onboarding_started', properties: null),
      ).called(1);
    });

    test('trackOnboardingCompleted logs onboarding_completed', () async {
      service.trackOnboardingCompleted();
      await pump();
      verify(
        () => mockAnalytics.logEvent('onboarding_completed', properties: null),
      ).called(1);
    });
  });

  group('sync observability (P2 #14)', () {
    test(
      'trackSyncFailed emits sync_failed with entity and error_type',
      () async {
        service.trackSyncFailed(entity: 'item', errorType: 'TimeoutException');
        await pump();
        verify(
          () => mockAnalytics.logEvent(
            'sync_failed',
            properties: {'entity': 'item', 'error_type': 'TimeoutException'},
          ),
        ).called(1);
      },
    );
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

  group('navigation_', () {
    test('trackCreateTapped logs create_tapped', () async {
      service.trackCreateTapped(tab: 'houses');
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'create_tapped',
          properties: {'tab': 'houses'},
        ),
      ).called(1);
    });

    test('trackCreateSheetChoice logs create_sheet_choice', () async {
      service.trackCreateSheetChoice(choice: 'ai_scan', tab: 'trips');
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'create_sheet_choice',
          properties: {'choice': 'ai_scan', 'tab': 'trips'},
        ),
      ).called(1);
    });
  });

  group('search_', () {
    test('trackSearchOpened logs search_opened', () async {
      service.trackSearchOpened(context: 'house');
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'search_opened',
          properties: {'context': 'house'},
        ),
      ).called(1);
    });

    test('trackSearchResultTapped logs search_result_tapped', () async {
      service.trackSearchResultTapped(context: 'house', position: 2);
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'search_result_tapped',
          properties: {'context': 'house', 'position': 2},
        ),
      ).called(1);
    });

    test(
      'trackSearchNoResults logs search_no_results without the text',
      () async {
        service.trackSearchNoResults(context: 'house', queryLength: 4);
        await pump();
        verify(
          () => mockAnalytics.logEvent(
            'search_no_results',
            properties: {'context': 'house', 'query_length': 4},
          ),
        ).called(1);
      },
    );
  });

  group('add_', () {
    test(
      'trackAddExistingMatchTapped logs add_existing_match_tapped',
      () async {
        service.trackAddExistingMatchTapped(position: 1);
        await pump();
        verify(
          () => mockAnalytics.logEvent(
            'add_existing_match_tapped',
            properties: {'position': 1},
          ),
        ).called(1);
      },
    );
  });

  group('eventi spostati', () {
    // Nomi e proprietà identici a quando i chiamanti usavano logEvent diretto.
    Future<void> expectEvent(String name, [Map<String, dynamic>? props]) async {
      await pump();
      verify(() => mockAnalytics.logEvent(name, properties: props)).called(1);
    }

    test('trackAppOpened', () async {
      service.trackAppOpened(trigger: 'cold_start');
      await expectEvent('app_opened', {'trigger': 'cold_start'});
    });

    test('trackOnboardingPageViewed', () async {
      service.trackOnboardingPageViewed(pageIndex: 1, pageName: 'trips');
      await expectEvent('onboarding_page_viewed', {
        'page_index': 1,
        'page_name': 'trips',
      });
    });

    test('trackOnboardingSkipped', () async {
      service.trackOnboardingSkipped(pageIndex: 0);
      await expectEvent('onboarding_skipped', {'page_index': 0});
    });

    test('trackLoginScreenViewed', () async {
      service.trackLoginScreenViewed();
      await expectEvent('login_screen_viewed');
    });

    test('trackConsentGiven', () async {
      service.trackConsentGiven(policyVersion: '2026-10');
      await expectEvent('consent_given', {'policy_version': '2026-10'});
    });

    test('trackLoginAttempted e trackLoginCompleted', () async {
      service.trackLoginAttempted(method: 'google');
      await expectEvent('login_attempted', {'method': 'google'});
      service.trackLoginCompleted(method: 'google');
      await expectEvent('login_completed', {'method': 'google'});
    });

    test('trackLoginFailed senza error_type se null', () async {
      service.trackLoginFailed(method: 'google', reason: 'cancelled');
      await expectEvent('login_failed', {
        'method': 'google',
        'reason': 'cancelled',
      });
    });

    test('trackLoginFailed con solo error_type', () async {
      service.trackLoginFailed(method: 'google', errorType: 'StateError');
      await expectEvent('login_failed', {
        'method': 'google',
        'error_type': 'StateError',
      });
    });

    test('trackAnalyticsOptIn e trackAnalyticsOptOut', () async {
      service.trackAnalyticsOptOut();
      await expectEvent('analytics_opt_out', {'enabled': false});
      service.trackAnalyticsOptIn();
      await expectEvent('analytics_opt_in', {'enabled': true});
    });

    test('step del tour', () async {
      const props = {'step_name': 'houseTooltip', 'step_index': 2};
      service.trackOnboardingStepViewed(stepName: 'houseTooltip', stepIndex: 2);
      await expectEvent('onboarding_step_viewed', props);
      service.trackOnboardingStepAdvanced(
        stepName: 'houseTooltip',
        stepIndex: 2,
      );
      await expectEvent('onboarding_step_advanced', props);
      service.trackOnboardingClosed(stepName: 'houseTooltip', stepIndex: 2);
      await expectEvent('onboarding_closed', props);
    });

    test('tour e onboarding AI senza proprietà', () async {
      service.trackAiOnboardingStarted();
      await expectEvent('ai_onboarding_started');
      service.trackAiOnboardingSkipped();
      await expectEvent('ai_onboarding_skipped');
      service.trackTourRelaunched();
      await expectEvent('tour_relaunched');
    });

    test('trackTourCompleted', () async {
      service.trackTourCompleted(skippedAi: true, lastStepIndex: 5);
      await expectEvent('tour_completed', {
        'skipped_ai': true,
        'last_step_index': 5,
      });
    });

    test('trackFirstTripStarted', () async {
      service.trackFirstTripStarted();
      await expectEvent('first_trip_started', const {});
    });

    test('trackFirstSuitcaseGenerated', () async {
      service.trackFirstSuitcaseGenerated(
        slotsImportant: 1,
        slotsProposed: 2,
        slotsTotal: 3,
        tripItems: 20,
        fromFirstRun: true,
      );
      await expectEvent('first_suitcase_generated', {
        'slots_important': 1,
        'slots_proposed': 2,
        'slots_total': 3,
        'trip_items': 20,
        'from_first_run': true,
      });
    });

    test('trackKitAutoAdded', () async {
      service.trackKitAutoAdded(kits: 2, items: 5);
      await expectEvent('kit_auto_added', {'kits': 2, 'items': 5});
    });

    test('posti', () async {
      service.trackSlotFilled(level: 'important', copies: 2);
      await expectEvent('slot_filled', {'level': 'important', 'copies': 2});
      service.trackSlotMarkedToBuy(level: 'useful', from: 'card');
      await expectEvent('slot_marked_to_buy', {
        'level': 'useful',
        'from': 'card',
      });
      service.trackSlotBought(level: 'useful');
      await expectEvent('slot_bought', {'level': 'useful'});
    });

    test('kit', () async {
      service.trackKitSuggestionAccepted(missing: 2);
      await expectEvent('kit_suggestion_accepted', {'missing': 2});
      service.trackKitSuggestionDismissed();
      await expectEvent('kit_suggestion_dismissed');
      service.trackKitUseLearned(kind: 'activity');
      await expectEvent('kit_use_learned', {'kind': 'activity'});
      service.trackKitCreated(items: 4, uses: 2);
      await expectEvent('kit_created', {'items': 4, 'uses': 2});
    });

    test('preparazione della valigia', () async {
      service.trackPackingStarted(
        tripId: 't1',
        totalItems: 10,
        daysToDeparture: null,
      );
      await expectEvent('packing_started', {
        'trip_id': 't1',
        'total_items': 10,
        'days_to_departure': null,
      });
      service.trackPackingProgress(
        tripId: 't1',
        threshold: 50,
        daysToDeparture: 2,
      );
      await expectEvent('packing_progress', {
        'trip_id': 't1',
        'threshold': 50,
        'days_to_departure': 2,
      });
      service.trackPackingCompleted(
        tripId: 't1',
        totalItems: 10,
        daysToDeparture: 0,
      );
      await expectEvent('packing_completed', {
        'trip_id': 't1',
        'total_items': 10,
        'days_to_departure': 0,
      });
    });
  });

  group('tetti e codici promo', () {
    test('trackAiLimitReached', () async {
      service.trackAiLimitReached(feature: 'weather');
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'ai_limit_reached',
          properties: {'feature': 'weather'},
        ),
      ).called(1);
    });

    test('trackPromoCodeRedeemed senza crediti', () async {
      service.trackPromoCodeRedeemed(outcome: 'expired');
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'promo_code_redeemed',
          properties: {'outcome': 'expired'},
        ),
      ).called(1);
    });

    test('trackPromoCodeRedeemed con i crediti', () async {
      service.trackPromoCodeRedeemed(outcome: 'redeemed', credits: 20);
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'promo_code_redeemed',
          properties: {'outcome': 'redeemed', 'credits': 20},
        ),
      ).called(1);
    });
  });

  group('valigia AI', () {
    test('trackAiSuitcaseChanged unisce conteggi e contesto', () async {
      service.trackAiSuitcaseChanged(
        tripId: 't1',
        counts: const {
          'removed': 1,
          'removed_types': ['Sweater'],
        },
        context: const {
          'washer': true,
          'activities': ['beach'],
        },
      );
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'ai_suitcase_changed',
          properties: {
            'trip_id': 't1',
            'removed': 1,
            'removed_types': ['Sweater'],
            'washer': true,
            'activities': ['beach'],
          },
        ),
      ).called(1);
    });

    test('trackAiSuitcaseFinished: esito, durata e proprietà', () async {
      service.trackAiSuitcaseFinished(
        outcome: 'ok',
        durationMs: 41000,
        tripId: 't1',
        properties: const {'nights': 4, 'is_regeneration': false},
      );
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'ai_suitcase_finished',
          properties: {
            'outcome': 'ok',
            'duration_ms': 41000,
            'trip_id': 't1',
            'nights': 4,
            'is_regeneration': false,
          },
        ),
      ).called(1);
    });

    test('trackAiItemReasonOpened', () async {
      service.trackAiItemReasonOpened(
        reasonCode: 'rain',
        subCategory: 'Jacket',
      );
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'ai_item_reason_opened',
          properties: {'reason_code': 'rain', 'sub_category': 'Jacket'},
        ),
      ).called(1);
    });

    test('trackAiWarningDismissed e trackAiSlotRemoved', () async {
      service.trackAiWarningDismissed(code: 'rain_gear', level: 'important');
      service.trackAiSlotRemoved(type: 'calze', level: 'useful');
      await pump();
      verify(
        () => mockAnalytics.logEvent(
          'ai_warning_dismissed',
          properties: {'code': 'rain_gear', 'level': 'important'},
        ),
      ).called(1);
      verify(
        () => mockAnalytics.logEvent(
          'ai_slot_removed',
          properties: {'type': 'calze', 'level': 'useful'},
        ),
      ).called(1);
    });
  });
}

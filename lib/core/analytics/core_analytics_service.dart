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

  // ── app_ ──────────────────────────────────────────────────────────────────

  void trackAppOpened({required String trigger}) {
    _safeLogEvent('app_opened', properties: {'trigger': trigger});
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

  /// `house_id` è la chiave di join con `house_created`: senza, il funnel
  /// "casa creata → quanti oggetti ci finiscono dentro" si può solo stimare
  /// per vicinanza temporale.
  void trackItemAdded({
    required String itemId,
    required String houseId,
    required String category,
    required int totalItems,
  }) {
    _safeLogEvent(
      'item_added',
      properties: {
        'item_id': itemId,
        'house_id': houseId,
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

  /// Dettagli di un capo modificati a mano (tag): `fields` sono i nomi dei
  /// campi cambiati, mai i valori.
  void trackItemDetailsEdited({
    required String source,
    required List<String> fields,
  }) {
    _safeLogEvent(
      'item_details_edited',
      properties: {'source': source, 'fields': fields},
    );
  }

  void trackItemsAddedToTrip({required String tripId, required int count}) {
    _safeLogEvent(
      'items_added_to_trip',
      properties: {'trip_id': tripId, 'count': count},
    );
  }

  // ── navigation_ ───────────────────────────────────────────────────────────

  /// Tocco su "Crea" nella barra. `tab` = tab da cui si apre il foglio
  /// (`houses`/`trips`): l'ordine delle voci del foglio dipende da lì.
  void trackCreateTapped({required String tab}) {
    _safeLogEvent('create_tapped', properties: {'tab': tab});
  }

  /// Scelta nel foglio Crea: `ai_scan`, `manual_items`, `new_house`,
  /// `new_trip`.
  void trackCreateSheetChoice({required String choice, required String tab}) {
    _safeLogEvent(
      'create_sheet_choice',
      properties: {'choice': choice, 'tab': tab},
    );
  }

  // ── search_ ───────────────────────────────────────────────────────────────

  /// Ricerca aperta. `context`: `house` (dentro una casa) o `houses_tab`
  /// (ricerca globale, fase successiva).
  void trackSearchOpened({required String context}) {
    _safeLogEvent('search_opened', properties: {'context': context});
  }

  /// Risultato aperto; `position` parte da 1.
  void trackSearchResultTapped({
    required String context,
    required int position,
  }) {
    _safeLogEvent(
      'search_result_tapped',
      properties: {'context': context, 'position': position},
    );
  }

  /// Ricerca senza risultati. Solo la lunghezza: il testo cercato è un dato
  /// dell'utente e non lascia il telefono.
  void trackSearchNoResults({
    required String context,
    required int queryLength,
  }) {
    _safeLogEvent(
      'search_no_results',
      properties: {'context': context, 'query_length': queryLength},
    );
  }

  // ── add_ ──────────────────────────────────────────────────────────────────

  /// Nella pagina "aggiungi" della casa si è aperto un oggetto di "Già in
  /// casa": la pagina ha evitato un doppione. `position` parte da 1.
  void trackAddExistingMatchTapped({required int position}) {
    _safeLogEvent(
      'add_existing_match_tapped',
      properties: {'position': position},
    );
  }

  // ── space_ ────────────────────────────────────────────────────────────────

  void trackSpaceCreated() => _safeLogEvent('space_created');

  // ── luggage_ ──────────────────────────────────────────────────────────────

  void trackLuggageCreated({required String size}) {
    _safeLogEvent('luggage_created', properties: {'size': size});
  }

  // ── trip_ ─────────────────────────────────────────────────────────────────

  /// `trip_number`: quanti viaggi ha l'utente con questo (il secondo viaggio
  /// è il segnale che l'app è tornata utile).
  void trackTripCreated({
    required String tripId,
    required int totalTrips,
    int? daysToDeparture,
    String? source,
  }) {
    _safeLogEvent(
      'trip_created',
      properties: {
        'trip_id': tripId,
        'is_first_trip': totalTrips == 1,
        'trip_number': totalTrips,
        'days_to_departure': ?daysToDeparture,
        'source': ?source,
      },
    );
  }

  void trackTripUpdated() => _safeLogEvent('trip_updated');

  // ── ai_suitcase_ ──────────────────────────────────────────────────────────

  /// La valigia salvata è cambiata rispetto alla proposta AI. [counts] e
  /// [context] sono già piatti (li calcola la feature): conteggi e
  /// sottocategorie, mai nomi o destinazione.
  void trackAiSuitcaseChanged({
    required String tripId,
    required Map<String, Object> counts,
    required Map<String, Object> context,
  }) {
    _safeLogEvent(
      'ai_suitcase_changed',
      properties: {'trip_id': tripId, ...counts, ...context},
    );
  }

  /// Un tentativo di generare la valigia è finito (una volta per tentativo).
  /// `outcome`: `ok`, `credits`, `empty_wardrobe`, `wardrobe_too_large`,
  /// `network`, `error`, `save_failed` (la risposta è arrivata ma non si è
  /// salvata). [properties]
  /// sono già piatte: viaggio, armadio, contesto.
  void trackAiSuitcaseFinished({
    required String outcome,
    required int durationMs,
    required String tripId,
    required Map<String, Object> properties,
  }) {
    _safeLogEvent(
      'ai_suitcase_finished',
      properties: {
        'outcome': outcome,
        'duration_ms': durationMs,
        'trip_id': tripId,
        ...properties,
      },
    );
  }

  /// Aperta la scheda di un capo proposto, con il perché dell'AI.
  void trackAiItemReasonOpened({
    required String reasonCode,
    required String subCategory,
  }) {
    _safeLogEvent(
      'ai_item_reason_opened',
      properties: {'reason_code': reasonCode, 'sub_category': subCategory},
    );
  }

  /// Un avviso "cosa manca" scartato dall'utente.
  void trackAiWarningDismissed({required String code, required String level}) {
    _safeLogEvent(
      'ai_warning_dismissed',
      properties: {'code': code, 'level': level},
    );
  }

  /// Un posto della valigia tolto dall'utente.
  void trackAiSlotRemoved({required String type, required String level}) {
    _safeLogEvent(
      'ai_slot_removed',
      properties: {'type': type, 'level': level},
    );
  }

  void trackTripDeleted() => _safeLogEvent('trip_deleted');

  void trackTripDuplicated() => _safeLogEvent('trip_duplicated');

  void trackTripSavedToggled({required bool isSaved}) {
    _safeLogEvent('trip_saved_toggled', properties: {'is_saved': isSaved});
  }

  // ── first_ ────────────────────────────────────────────────────────────────

  void trackFirstTripStarted() =>
      _safeLogEvent('first_trip_started', properties: const {});

  /// Una volta sola per dispositivo, alla prima valigia con i posti salvata.
  void trackFirstSuitcaseGenerated({
    required int slotsImportant,
    required int slotsProposed,
    required int slotsTotal,
    required int tripItems,
    required bool fromFirstRun,
  }) {
    _safeLogEvent(
      'first_suitcase_generated',
      properties: {
        'slots_important': slotsImportant,
        'slots_proposed': slotsProposed,
        'slots_total': slotsTotal,
        'trip_items': tripItems,
        'from_first_run': fromFirstRun,
      },
    );
  }

  // ── slot_ / kit_ ──────────────────────────────────────────────────────────

  void trackSlotFilled({required String level, required int copies}) {
    _safeLogEvent(
      'slot_filled',
      properties: {'level': level, 'copies': copies},
    );
  }

  void trackSlotMarkedToBuy({required String level, required String from}) {
    _safeLogEvent(
      'slot_marked_to_buy',
      properties: {'level': level, 'from': from},
    );
  }

  void trackSlotBought({required String level}) {
    _safeLogEvent('slot_bought', properties: {'level': level});
  }

  void trackKitAutoAdded({required int kits, required int items}) {
    _safeLogEvent('kit_auto_added', properties: {'kits': kits, 'items': items});
  }

  void trackKitSuggestionAccepted({required int missing}) {
    _safeLogEvent('kit_suggestion_accepted', properties: {'missing': missing});
  }

  void trackKitSuggestionDismissed() =>
      _safeLogEvent('kit_suggestion_dismissed');

  void trackKitUseLearned({required String kind}) {
    _safeLogEvent('kit_use_learned', properties: {'kind': kind});
  }

  void trackKitCreated({required int items, required int uses}) {
    _safeLogEvent('kit_created', properties: {'items': items, 'uses': uses});
  }

  // ── packing_ ──────────────────────────────────────────────────────────────

  void trackPackingStarted({
    required String tripId,
    required int totalItems,
    required int? daysToDeparture,
  }) {
    _safeLogEvent(
      'packing_started',
      properties: {
        'trip_id': tripId,
        'total_items': totalItems,
        'days_to_departure': daysToDeparture,
      },
    );
  }

  void trackPackingProgress({
    required String tripId,
    required int threshold,
    required int? daysToDeparture,
  }) {
    _safeLogEvent(
      'packing_progress',
      properties: {
        'trip_id': tripId,
        'threshold': threshold,
        'days_to_departure': daysToDeparture,
      },
    );
  }

  void trackPackingCompleted({
    required String tripId,
    required int totalItems,
    required int? daysToDeparture,
  }) {
    _safeLogEvent(
      'packing_completed',
      properties: {
        'trip_id': tripId,
        'total_items': totalItems,
        'days_to_departure': daysToDeparture,
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

  /// Tetto AI finito (risposta 429). `feature`: `suitcase`, `scan`,
  /// `weather`, `item_name`. `source` (solo per `item_name`): `manual` se
  /// l'ha toccato un'aggiunta dell'utente, `backfill` se il recupero in
  /// background delle schede.
  void trackAiLimitReached({required String feature, String? source}) {
    _safeLogEvent(
      'ai_limit_reached',
      properties: {'feature': feature, 'source': ?source},
    );
  }

  /// Una scansione salvata. `count` i capi scritti; gli altri conteggi dicono
  /// quanto l'utente ha corretto lo scan. I `*_types` sono sottocategorie
  /// della tassonomia (come le ha lette l'analisi), mai i nomi.
  void trackAiItemsSaved({
    required int count,
    required bool isOnboarding,
    required int found,
    required int excluded,
    required int renamed,
    required int detailsEdited,
    required int photos,
    required List<String> excludedTypes,
    required List<String> renamedTypes,
  }) {
    _safeLogEvent(
      'ai_items_saved',
      properties: {
        'count': count,
        'is_onboarding': isOnboarding,
        'found': found,
        'excluded': excluded,
        'renamed': renamed,
        'details_edited': detailsEdited,
        'photos': photos,
        'excluded_types': excludedTypes,
        'renamed_types': renamedTypes,
      },
    );
  }

  /// Un capo salvato con dubbi di Jev o con campi corretti: quali campi
  /// erano in dubbio e quale valore l'utente ha tenuto. Solo nomi di campo.
  void trackAiScanDoubtResolved({
    required List<String> doubtFields,
    required List<String> choseJev,
    required List<String> keptGpt,
    required List<String> otherValue,
    required List<String> correctedWithoutDoubt,
    required String subCategory,
  }) {
    _safeLogEvent(
      'ai_scan_doubt_resolved',
      properties: {
        'doubt_fields': doubtFields,
        'chose_jev': choseJev,
        'kept_gpt': keptGpt,
        'other_value': otherValue,
        'corrected_without_doubt': correctedWithoutDoubt,
        'sub_category': subCategory,
      },
    );
  }

  /// Apre il foglio che confronta i risultati AI con gli oggetti esistenti.
  void trackAlreadyHereOpened({required bool hasManualCandidates}) {
    _safeLogEvent(
      'already_here_opened',
      properties: {'has_manual_candidates': hasManualCandidates},
    );
  }

  // ── onboarding_ ───────────────────────────────────────────────────────────

  /// Carosello **pre-login**, non il tour guidato post-login: quello emette
  /// `ai_onboarding_started` / `onboarding_step_*` / `tour_completed`.
  /// I nomi si somigliano ma i due flussi sono distinti — non mescolarli nello
  /// stesso funnel.
  void trackOnboardingStarted() => _safeLogEvent('onboarding_started');

  void trackOnboardingCompleted() => _safeLogEvent('onboarding_completed');

  void trackOnboardingPageViewed({
    required int pageIndex,
    required String pageName,
  }) {
    _safeLogEvent(
      'onboarding_page_viewed',
      properties: {'page_index': pageIndex, 'page_name': pageName},
    );
  }

  void trackOnboardingSkipped({required int pageIndex}) {
    _safeLogEvent('onboarding_skipped', properties: {'page_index': pageIndex});
  }

  // ── tour_ ─────────────────────────────────────────────────────────────────

  /// Tour guidato post-login. `step_index` è 1-based e null per gli step
  /// fuori dal tour (vedi `OnboardingStepTourIndex`).
  void trackOnboardingStepViewed({
    required String stepName,
    required int? stepIndex,
  }) => _logTourStep('onboarding_step_viewed', stepName, stepIndex);

  void trackOnboardingStepAdvanced({
    required String stepName,
    required int? stepIndex,
  }) => _logTourStep('onboarding_step_advanced', stepName, stepIndex);

  /// Chiude l'intero tour, non solo lo step corrente.
  void trackOnboardingClosed({
    required String stepName,
    required int? stepIndex,
  }) => _logTourStep('onboarding_closed', stepName, stepIndex);

  void _logTourStep(String event, String stepName, int? stepIndex) {
    _safeLogEvent(
      event,
      properties: {'step_name': stepName, 'step_index': stepIndex},
    );
  }

  void trackAiOnboardingStarted() => _safeLogEvent('ai_onboarding_started');

  void trackAiOnboardingSkipped() => _safeLogEvent('ai_onboarding_skipped');

  void trackTourRelaunched() => _safeLogEvent('tour_relaunched');

  /// Solo il completamento naturale: gli abbandoni hanno già il loro evento.
  void trackTourCompleted({
    required bool skippedAi,
    required int? lastStepIndex,
  }) {
    _safeLogEvent(
      'tour_completed',
      properties: {'skipped_ai': skippedAi, 'last_step_index': lastStepIndex},
    );
  }

  // ── auth_ ─────────────────────────────────────────────────────────────────

  // `login_completed` ha un solo emettitore, il tap in LoginScreen
  // ([trackLoginCompleted]). Vedi il commento in
  // `AuthNotifier._trackAuthTransition` per il doppio conteggio che ne seguiva.

  void trackLogout() => _safeLogEvent('logout');

  void trackLoginScreenViewed() => _safeLogEvent('login_screen_viewed');

  void trackConsentGiven({required String policyVersion}) {
    _safeLogEvent(
      'consent_given',
      properties: {'policy_version': policyVersion},
    );
  }

  void trackLoginAttempted({required String method}) {
    _safeLogEvent('login_attempted', properties: {'method': method});
  }

  void trackLoginCompleted({required String method}) {
    _safeLogEvent('login_completed', properties: {'method': method});
  }

  /// `error_type` è il `runtimeType` dell'eccezione, mai il messaggio: quello
  /// di Supabase può contenere l'email.
  void trackLoginFailed({
    required String method,
    String? reason,
    String? errorType,
  }) {
    _safeLogEvent(
      'login_failed',
      properties: {
        'method': method,
        'reason': ?reason,
        'error_type': ?errorType,
      },
    );
  }

  // ── consent_ ──────────────────────────────────────────────────────────────

  /// L'opt-out va emesso PRIMA di chiudere il gate, l'opt-in DOPO averlo
  /// riaperto: `_safeLogEvent` chiama `logEvent` in modo sincrono, quindi
  /// l'ordine dei chiamanti resta valido.
  void trackAnalyticsOptIn() =>
      _safeLogEvent('analytics_opt_in', properties: {'enabled': true});

  void trackAnalyticsOptOut() =>
      _safeLogEvent('analytics_opt_out', properties: {'enabled': false});

  // ── promo_ ────────────────────────────────────────────────────────────────

  /// Esito dell'attivazione di un codice promo; mai il codice.
  void trackPromoCodeRedeemed({required String outcome, int? credits}) {
    _safeLogEvent(
      'promo_code_redeemed',
      properties: {'outcome': outcome, 'credits': ?credits},
    );
  }

  // ── screen_ ───────────────────────────────────────────────────────────────

  /// Passa da [AppAnalyticsService.logPageview] e non da `_safeLogEvent`: su
  /// tgram la navigazione è un pageview, non un evento custom, ed è l'unica
  /// forma che alimenta `top_pages`. Vedi il commento su `logPageview`.
  void trackScreenView(String screenName) {
    try {
      _analytics.logPageview(screenName);
    } catch (e) {
      debugPrint('[Analytics] trackScreenView failed for $screenName: $e');
    }
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

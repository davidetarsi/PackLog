import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../houses/model/house_model.dart';
import '../../houses/providers/house_provider.dart';
import '../../kits/model/kit_model.dart';
import '../../kits/providers/kit_provider.dart';
import '../../luggages/model/luggage_model.dart';
import '../../luggages/providers/luggage_provider.dart';
import '../model/ai_availability.dart';
import '../model/ai_packing.dart';
import '../model/ai_packing_request.dart';
import '../model/pack_trip_job.dart';
import '../model/pack_trip_request.dart';
import '../model/trip_model.dart';
import '../model/trip_postcard.dart';
import '../model/trip_weather.dart';
import '../providers/ai_packing_run_provider.dart';
import '../view/widgets/ai/ai_packing_sheet.dart';
import 'ai_suitcase_adoption.dart';

/// Il tocco su "Prepara con AI" / "Rigenera": controlla che si possa, chiede
/// conferma se la valigia ha già capi (solo se non [isNew]), apre il foglio,
/// avvia il lavoro e apre la pagina d'attesa.
///
/// Ritorna le risposte del foglio se il lavoro è partito, `null` altrimenti
/// (lavoro già in corso, viaggio non adatto, conferma o foglio chiusi). Le
/// risposte non si scrivono sul viaggio qui: si salvano con la valigia
/// quando arriva. [beforeWait] gira dopo l'avvio e prima dell'attesa: serve a
/// chi vuole chiudere la propria pagina.
Future<AiPackingSetup?> startAiPacking(
  BuildContext context,
  WidgetRef ref, {
  required TripModel trip,
  required bool isNew,
  VoidCallback? beforeWait,
}) async {
  if (ref.read(aiPackingRunProvider) is AiRunRunning) {
    AppSnackBar.showInfo(context, 'trips.ai.busy'.tr());
    return null;
  }

  final houses =
      ref.read(houseNotifierProvider).valueOrNull ?? const <HouseModel>[];
  final availability = aiAvailabilityOf(
    trip,
    houses: houses,
    today: DateTime.now(),
  );
  final TripWeatherRequest plan;
  switch (availability) {
    case AiUnavailable(:final messageKey):
      AppSnackBar.showInfo(context, messageKey.tr());
      return null;
    case AiAvailable(plan: final available):
      plan = available;
  }

  if (!isNew && trip.items.isNotEmpty) {
    final replace = await DialogHelpers.showConfirmation(
      context: context,
      title: 'trips.pack.ai.replace_title'.tr(),
      message: 'trips.pack.ai.replace_message'.tr(),
      confirmLabel: 'trips.pack.ai.replace_confirm'.tr(),
      isDestructive: true,
    );
    if (!replace || !context.mounted) return null;
  }

  final setup = await showAiPackingSheet(context, trip: trip, plan: plan);
  final houseId = setup?.houseId;
  if (setup == null || houseId == null || !context.mounted) return null;

  final luggage = _luggageById(ref, setup.luggageId);
  final kits = await _kitsOf(ref, houseId);
  if (!context.mounted) return null;

  final names = [for (final stop in aiStopsOf(plan)) stop.name];
  final job = PackTripJob(
    body: packTripBody(
      plan: plan,
      setup: setup,
      houseId: houseId,
      language: context.locale.languageCode,
      luggage: luggage,
      transports: trip.transports,
      kits: kits,
    ),
    houseId: houseId,
    title: joinStopNames(names),
    nights: nightsBetween(trip.departureDateTime, trip.returnDateTime) ?? 0,
  );
  final started = ref
      .read(aiPackingRunProvider.notifier)
      .start(
        AiPackingRequest(
          trip: trip,
          isNew: isNew,
          setup: setup,
          job: job,
          luggage: luggage,
        ),
      );
  if (!started) {
    AppSnackBar.showInfo(context, 'trips.ai.busy'.tr());
    return null;
  }
  // [beforeWait] può chiudere la pagina che chiama: il router si prende prima.
  final router = GoRouter.of(context);
  beforeWait?.call();
  router.push('/ai-packing');
  return setup;
}

LuggageModel? _luggageById(WidgetRef ref, String? id) {
  if (id == null) return null;
  final luggages =
      ref.read(luggageNotifierProvider).valueOrNull ?? const <LuggageModel>[];
  return luggages.where((l) => l.id == id).firstOrNull;
}

/// I kit della casa. Se non si leggono la valigia si fa lo stesso, senza.
Future<List<KitModel>> _kitsOf(WidgetRef ref, String houseId) async {
  try {
    return await ref.read(kitNotifierProvider(houseId).future);
  } catch (_) {
    return const [];
  }
}

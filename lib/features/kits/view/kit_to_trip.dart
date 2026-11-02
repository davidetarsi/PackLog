import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/helpers/snack_bar_helper.dart';
import '../../items/providers/item_provider.dart';
import '../../trips/providers/trip_provider.dart';
import '../../trips/view/trip_picker_sheet.dart';
import '../helpers/kit_trip_plan.dart';
import '../model/kit_model.dart';

/// "Metti in valigia…": sceglie un viaggio e ci mette gli oggetti del kit,
/// con le copie del kit (il massimo, mai la somma) e senza superare quelle
/// della casa.
Future<void> putKitInTrip(
  BuildContext context,
  WidgetRef ref,
  KitModel kit,
) async {
  final picked = await TripPickerSheet.show(context);
  if (picked == null || !context.mounted) return;

  final notifier = ref.read(tripNotifierProvider.notifier);
  final trip =
      ref
          .read(tripNotifierProvider)
          .valueOrNull
          ?.firstWhere((t) => t.id == picked.id, orElse: () => picked) ??
      picked;
  final houseItems =
      ref.read(itemNotifierProvider(kit.houseId)).valueOrNull ?? const [];
  final plan = planKitForTrip(kit: kit, houseItems: houseItems, trip: trip);

  try {
    if (plan.raised.isEmpty) {
      await notifier.addItemsToTrip(trip.id, plan.toAdd);
    } else {
      await notifier.updateTrip(applyKitTripPlan(trip, plan));
    }
    if (context.mounted) {
      AppSnackBar.showSuccess(
        context,
        'items.add_to_trip_success'.tr(args: ['${plan.changes}', trip.name]),
      );
    }
  } catch (_) {
    if (context.mounted) {
      AppSnackBar.showError(context, 'errors.save_error'.tr());
    }
  }
}

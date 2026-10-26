import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/ds_empty_state.dart';
import '../../../shared/widgets/ds_error_state.dart';
import '../../../shared/widgets/ds_form_sheet.dart';
import '../../../shared/widgets/ds_settings.dart';
import '../../houses/providers/house_provider.dart';
import '../model/trip_model.dart';
import '../model/trip_postcard.dart';
import '../providers/trip_provider.dart';
import 'widgets/pack/pack_summary_line.dart';

/// Foglio per scegliere un viaggio non ancora concluso a cui aggiungere degli
/// oggetti selezionati da una casa. Ogni riga è il viaggio come nel riepilogo
/// della valigia: nome, date, notti e luoghi, e a destra i giorni alla partenza.
///
/// Mostra solo i viaggi con `!trip.isCompleted` (upcoming o active) —
/// un viaggio concluso non ha senso come destinazione per nuovi oggetti.
class TripPickerSheet extends ConsumerWidget {
  const TripPickerSheet({super.key});

  static Future<TripModel?> show(BuildContext context) =>
      showDsFormSheet<TripModel>(
        context,
        builder: (_) => const TripPickerSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final houses = ref.watch(houseNotifierProvider).valueOrNull ?? const [];
    final houseNames = {
      for (final house in houses) house.id: house.displayName,
    };

    return DsFormSheet(
      title: 'trips.trip_picker_sheet_title'.tr(),
      child: ref
          .watch(tripNotifierProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => DsErrorState(
              error: error,
              message: 'errors.load_failed'.tr(),
              onRetry: () => ref.invalidate(tripNotifierProvider),
            ),
            data: (allTrips) {
              final openTrips = allTrips.where((t) => !t.isCompleted).toList();
              if (openTrips.isEmpty) {
                return DsEmptyState(
                  icon: Icons.luggage_outlined,
                  title: 'trips.trip_picker_no_trips'.tr(),
                );
              }
              return DsSettingsGroup(
                children: [
                  for (final trip in openTrips)
                    _tripRow(context, trip, houseNames, cs),
                ],
              );
            },
          ),
    );
  }

  Widget _tripRow(
    BuildContext context,
    TripModel trip,
    Map<String, String> houseNames,
    ColorScheme cs,
  ) {
    final destination = tripDestinationName(
      trip,
      houseName: houseNames[trip.destinationHouseId],
    );
    return DsSettingsRow(
      key: Key('trip_picker_${trip.id}'),
      leading: Icon(Icons.luggage_outlined, color: cs.onSurfaceVariant),
      label: postcardTitle(trip, destination: destination),
      subtitle: tripSummaryDetails(
        context,
        trip,
        destination: destination,
        houseNames: houseNames,
      ),
      value: tripStampLabel(trip),
      onTap: () => Navigator.of(context).pop(trip),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/ds_text_button.dart';
import '../model/trip_date_range.dart';
import '../providers/date_range_selection_provider.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import 'widgets/trip_calendar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TripDateRangeScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Schermata full-screen per la selezione del range di date di un viaggio.
///
/// Usa [StickyCtaScaffold] + calendario verticale a scroll lazy (24 mesi).
/// La logica di selezione è delegata al [DateRangeSelectionNotifier] (Riverpod,
/// autoDispose). La UI è composta da dumb components senza logica interna.
///
/// Ritorna un [TripDateRange] via `Navigator.pop` quando l'utente conferma.
///
/// ```dart
/// final result = await Navigator.of(context).push<TripDateRange>(
///   MaterialPageRoute(
///     builder: (_) => TripDateRangeScreen(
///       initialDeparture: _departureDateTime,
///       initialReturn: _returnDateTime,
///     ),
///   ),
/// );
/// ```
class TripDateRangeScreen extends ConsumerWidget {
  final DateTime? initialDeparture;
  final DateTime? initialReturn;

  const TripDateRangeScreen({
    super.key,
    this.initialDeparture,
    this.initialReturn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = dateRangeSelectionNotifierProvider(
      initialDeparture: initialDeparture,
      initialReturn: initialReturn,
    );
    final state = ref.watch(provider);

    return StickyCtaScaffold(
      appBar: AppBar(
        title: Text('trips.select_dates'.tr()),
        actions: [
          if (!state.isEmpty)
            DsTextButton(
              onPressed: () => ref.read(provider.notifier).clear(),
              label: 'common.cancel'.tr(),
            ),
        ],
      ),
      body: TripCalendar(
        selection: state,
        initialMonth: initialDeparture,
        onDaySelected: (date) =>
            ref.read(provider.notifier).onDaySelected(date),
      ),
      bottomContent: UniversalActionBar(
        // "Conferma date" al plurale presuppone che le date siano due: con la
        // sola partenza la CTA torna al più generico "Conferma".
        primaryLabel: state.hasOnlyDeparture
            ? 'common.confirm'.tr()
            : 'trips.confirm_dates'.tr(),
        primaryIcon: Icons.check_rounded,
        // Obbligatoria è solo la partenza: il ritorno è facoltativo e il
        // modello sa già gestire "attivo dopo la partenza" quando manca.
        // Pretendere qui il range completo rimetterebbe il bottone spento che
        // la validazione ha appena tolto, un pannello più in là.
        onPrimaryPressed: (state.isComplete || state.hasOnlyDeparture)
            ? () => Navigator.of(context).pop(state)
            : null,
      ),
    );
  }
}

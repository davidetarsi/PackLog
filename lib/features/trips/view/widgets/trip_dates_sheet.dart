import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_button.dart';
import '../../../../shared/widgets/ds_sheet_header.dart';
import '../../model/trip_date_range.dart';
import '../../providers/date_range_selection_provider.dart';
import 'trip_calendar.dart';

/// Altezza del foglio delle date, in frazione dell'altezza dello schermo:
/// quasi a tutto schermo, con la testata ancora visibile sopra.
const double _kTripDatesSheetHeightFactor = 0.9;

/// Foglio per scegliere partenza e ritorno di un viaggio.
///
/// La selezione usa [DateRangeSelectionNotifier], come la schermata
/// [TripDateRangeScreen]. "Conferma date" è attivo solo con il range completo.
/// Restituisce il [TripDateRange] confermato, o `null` se il foglio si chiude.
Future<TripDateRange?> showTripRangeSheet(
  BuildContext context, {
  DateTime? initialDeparture,
  DateTime? initialReturn,
}) {
  return showModalBottomSheet<TripDateRange>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TripRangeSheet(
      initialDeparture: initialDeparture,
      initialReturn: initialReturn,
    ),
  );
}

/// Foglio per scegliere solo la fine di un viaggio, a partire da [start].
///
/// L'inizio è fisso: è mostrato come partenza della selezione e i giorni fino
/// a [start] compreso sono spenti. "Conferma" è attivo solo quando la fine è
/// scelta. Restituisce la fine, o `null` se il foglio si chiude.
Future<DateTime?> showTripEndSheet(
  BuildContext context, {
  required DateTime start,
  DateTime? initialEnd,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TripEndSheet(start: start, initialEnd: initialEnd),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _TripRangeSheet — intervallo, con il notifier della schermata
// ─────────────────────────────────────────────────────────────────────────────

class _TripRangeSheet extends ConsumerWidget {
  final DateTime? initialDeparture;
  final DateTime? initialReturn;

  const _TripRangeSheet({this.initialDeparture, this.initialReturn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = dateRangeSelectionNotifierProvider(
      initialDeparture: initialDeparture,
      initialReturn: initialReturn,
    );
    final state = ref.watch(provider);

    return _TripDatesSheet(
      selection: state,
      initialMonth: initialDeparture ?? initialReturn,
      onDaySelected: (date) => ref.read(provider.notifier).onDaySelected(date),
      confirmLabel: 'trips.confirm_dates'.tr(),
      onConfirm: state.isComplete
          ? () => Navigator.of(context).pop(state)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TripEndSheet — solo la fine, con stato locale
// ─────────────────────────────────────────────────────────────────────────────

/// Non usa il [DateRangeSelectionNotifier]: la sua regola 3 (un tocco prima
/// della partenza riscrive la partenza) qui non deve valere. Lo stato è solo
/// la fine scelta, e i tocchi fino alla partenza compresa sono ignorati.
class _TripEndSheet extends StatefulWidget {
  final DateTime start;
  final DateTime? initialEnd;

  const _TripEndSheet({required this.start, this.initialEnd});

  @override
  State<_TripEndSheet> createState() => _TripEndSheetState();
}

class _TripEndSheetState extends State<_TripEndSheet> {
  late final DateTime _start = _dateOnly(widget.start);
  late DateTime? _end = _initialEnd();

  /// La fine iniziale vale solo se è dopo l'inizio: altrimenti il foglio
  /// partirebbe da una selezione che non può esistere.
  DateTime? _initialEnd() {
    final initial = widget.initialEnd;
    if (initial == null) return null;
    final day = _dateOnly(initial);
    return day.isAfter(_start) ? day : null;
  }

  void _onDaySelected(DateTime date) {
    final tapped = _dateOnly(date);
    // Un giorno fino alla partenza compresa non fa nulla: l'inizio non è
    // modificabile da questo foglio.
    if (!tapped.isAfter(_start)) return;
    setState(() => _end = tapped);
  }

  @override
  Widget build(BuildContext context) {
    final end = _end;

    return _TripDatesSheet(
      selection: TripDateRange(departureDate: _start, returnDate: end),
      initialMonth: end ?? _start,
      firstSelectableDay: DateTime(_start.year, _start.month, _start.day + 1),
      onDaySelected: _onDaySelected,
      confirmLabel: 'common.confirm'.tr(),
      onConfirm: end == null ? null : () => Navigator.of(context).pop(end),
    );
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

// ─────────────────────────────────────────────────────────────────────────────
// _TripDatesSheet — guscio comune: testata, calendario, conferma
// ─────────────────────────────────────────────────────────────────────────────

class _TripDatesSheet extends StatelessWidget {
  final TripDateRange selection;
  final ValueChanged<DateTime> onDaySelected;
  final DateTime? initialMonth;
  final DateTime? firstSelectableDay;
  final String confirmLabel;

  /// `null` tiene spento il bottone di conferma.
  final VoidCallback? onConfirm;

  const _TripDatesSheet({
    required this.selection,
    required this.onDaySelected,
    required this.confirmLabel,
    required this.onConfirm,
    this.initialMonth,
    this.firstSelectableDay,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.sizeOf(context).height * _kTripDatesSheetHeightFactor,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.modalBorderRadius),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsSheetHeader(
            title: 'trips.new.when'.tr(),
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: TripCalendar(
              selection: selection,
              initialMonth: initialMonth,
              firstSelectableDay: firstSelectableDay,
              onDaySelected: onDaySelected,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.all(context.spacingMd),
              child: DsButton(
                label: confirmLabel,
                icon: Icons.check_rounded,
                onPressed: onConfirm,
                expand: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

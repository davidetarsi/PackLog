import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/trip_date_range.dart';
import '../providers/date_range_selection_provider.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/universal_action_bar.dart';

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
            TextButton(
              onPressed: () => ref.read(provider.notifier).clear(),
              child: Text(
                'common.cancel'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _CalendarScrollView(
        selection: state,
        initialDeparture: initialDeparture,
        onDaySelected: (date) =>
            ref.read(provider.notifier).onDaySelected(date),
      ),
      bottomContent: UniversalActionBar(
        primaryLabel: 'trips.confirm_dates'.tr(),
        primaryIcon: Icons.check_rounded,
        onPrimaryPressed: state.isComplete
            ? () => Navigator.of(context).pop(state)
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CalendarScrollView — lazy list di mesi con scroll iniziale al mese target
// ─────────────────────────────────────────────────────────────────────────────

class _CalendarScrollView extends StatefulWidget {
  final TripDateRange selection;

  /// Partenza originale del viaggio (usata per calcolare lo scroll iniziale).
  /// Se null (nuovo viaggio) lo scroll parte dal mese corrente.
  final DateTime? initialDeparture;
  final ValueChanged<DateTime> onDaySelected;

  const _CalendarScrollView({
    required this.selection,
    required this.onDaySelected,
    this.initialDeparture,
  });

  @override
  State<_CalendarScrollView> createState() => _CalendarScrollViewState();
}

class _CalendarScrollViewState extends State<_CalendarScrollView> {
  late final ScrollController _scrollController;
  late final DateTime _startMonth;
  late final int _itemCount;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    // Finestra di default: 12 mesi indietro
    final defaultStartMonth = DateTime(now.year, now.month - 12, 1);

    // Se la partenza è antecedente alla finestra di default, estendi
    final dep = widget.initialDeparture;
    final depMonth = dep != null ? DateTime(dep.year, dep.month, 1) : null;
    _startMonth = (depMonth != null && depMonth.isBefore(defaultStartMonth))
        ? depMonth
        : defaultStartMonth;

    // Fine: sempre 24 mesi dal mese corrente
    final endMonth = DateTime(now.year, now.month + 24, 1);
    _itemCount = _monthDiff(_startMonth, endMonth);

    // Mese target per lo scroll iniziale
    final targetMonth = depMonth ?? currentMonth;
    final targetIndex = _monthDiff(_startMonth, targetMonth);

    _scrollController = ScrollController(
      initialScrollOffset: _estimatedOffset(targetIndex),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Differenza in mesi tra due date (b - a), assunzione b >= a
  static int _monthDiff(DateTime a, DateTime b) =>
      (b.year - a.year) * 12 + (b.month - a.month);

  /// Stima l'offset in pixel fino all'inizio del mese all'indice [targetIndex].
  ///
  /// Usa le costanti base di AppSpacing (non responsive) — la precisione è
  /// sufficiente per uno scroll iniziale "vicino al target".
  double _estimatedOffset(int targetIndex) {
    // Padding top del ListView
    double offset = AppSpacing.md;
    for (int i = 0; i < targetIndex; i++) {
      final month = DateTime(_startMonth.year, _startMonth.month + i, 1);
      offset += _monthHeight(month);
    }
    return offset;
  }

  /// Altezza stimata di un mese basata sulla struttura di [_MonthView]:
  ///
  ///   header text (fontLg ≈ 28px con line-height) + paddingBottom(md=16)
  ///   + weekday row (~18px, fontXxs=12)
  ///   + spacer (xs=4)
  ///   + N rows × dayCellHeight(40) + (N-1) × rowSpacing(xs=4)
  ///   + bottom padding (xl=32)
  static double _monthHeight(DateTime month) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((month.weekday - 1 + daysInMonth) / 7).ceil();

    const double headerText = 28; // fontLg 20 × ~1.4 line-height
    const double headerBottomPadding = AppSpacing.md; // 16
    const double weekdayRow = 18; // fontXxs 12 × ~1.5 line-height
    const double spacerAfterWeekdays = AppSpacing.xs; // 4
    const double dayCellHeight = 40;
    const double rowSpacing =
        AppSpacing.xs; // 4, tra le righe (non dopo l'ultima)
    const double monthBottomPadding = AppSpacing.xl; // 32

    return headerText +
        headerBottomPadding +
        weekdayRow +
        spacerAfterWeekdays +
        rows * dayCellHeight +
        (rows - 1) * rowSpacing +
        monthBottomPadding;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        context.spacingMd,
        context.spacingMd,
        context.spacingXl,
      ),
      itemCount: _itemCount,
      itemBuilder: (_, index) {
        final month = DateTime(_startMonth.year, _startMonth.month + index, 1);
        return _MonthView(
          month: month,
          today: today,
          selection: widget.selection,
          onDayTap: widget.onDaySelected,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MonthView — header + griglia giorni di un singolo mese
// ─────────────────────────────────────────────────────────────────────────────

class _MonthView extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final TripDateRange selection;
  final ValueChanged<DateTime> onDayTap;

  const _MonthView({
    required this.month,
    required this.today,
    required this.selection,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Month/Year header ─────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(bottom: context.spacingMd),
            child: Text(
              DateFormat.yMMMM(locale).format(month),
              style: TextStyle(
                fontSize: context.fontSizeLg,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),

          // ── Weekday labels (Mon-first) ────────────────────────────────
          _WeekdayHeader(locale: locale),

          SizedBox(height: context.spacingXs),

          // ── Days grid ─────────────────────────────────────────────────
          _DaysGrid(
            month: month,
            today: today,
            selection: selection,
            onDayTap: onDayTap,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WeekdayHeader — riga etichette L M M G V S D
// ─────────────────────────────────────────────────────────────────────────────

class _WeekdayHeader extends StatelessWidget {
  final String locale;

  const _WeekdayHeader({required this.locale});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Genera le etichette dei giorni in locale usando una settimana nota
    // che inizia di lunedì (2 gennaio 2023 = lunedì)
    final monday = DateTime(2023, 1, 2);
    final labels = List.generate(
      7,
      (i) => DateFormat.E(
        locale,
      ).format(monday.add(Duration(days: i))).substring(0, 1).toUpperCase(),
    );

    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: context.fontSizeXxs,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DaysGrid — griglia settimane di un mese
// ─────────────────────────────────────────────────────────────────────────────

class _DaysGrid extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final TripDateRange selection;
  final ValueChanged<DateTime> onDayTap;

  const _DaysGrid({
    required this.month,
    required this.today,
    required this.selection,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    // Giorni nel mese
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Offset: quante celle vuote prima del giorno 1
    // (weekday: 1=lun, 7=dom → 0-indexed offset = weekday - 1)
    final offset = month.weekday - 1;

    final totalCells = offset + daysInMonth;
    final numRows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(numRows, (row) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: row < numRows - 1 ? context.spacingXs : 0,
          ),
          child: Row(
            children: List.generate(7, (col) {
              final dayIndex = row * 7 + col - offset;
              if (dayIndex < 0 || dayIndex >= daysInMonth) {
                return const Expanded(child: SizedBox.shrink());
              }
              final date = DateTime(month.year, month.month, dayIndex + 1);
              final isPast = date.isBefore(today);
              return Expanded(
                child: _DayCell(
                  date: date,
                  today: today,
                  selection: selection,
                  isPast: isPast,
                  isFirstOfRow: col == 0,
                  isLastOfRow: col == 6,
                  // I giorni passati rimangono selezionabili per permettere
                  // la modifica di viaggi già avvenuti.
                  onTap: () => onDayTap(date),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DayCell — singola cella giorno con evidenziazione range
// ─────────────────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime date;
  final DateTime today;
  final TripDateRange selection;
  final bool isPast;
  final bool isFirstOfRow;
  final bool isLastOfRow;
  final VoidCallback? onTap;

  const _DayCell({
    required this.date,
    required this.today,
    required this.selection,
    required this.isPast,
    required this.isFirstOfRow,
    required this.isLastOfRow,
    this.onTap,
  });

  bool get _isToday =>
      date.year == today.year &&
      date.month == today.month &&
      date.day == today.day;

  bool get _isDeparture =>
      selection.departureDate != null &&
      _isSameDay(date, selection.departureDate!);

  bool get _isReturn =>
      selection.returnDate != null && _isSameDay(date, selection.returnDate!);

  bool get _isInRange {
    final dep = selection.departureDate;
    final ret = selection.returnDate;
    if (dep == null || ret == null) return false;
    return date.isAfter(dep) && date.isBefore(ret);
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final isSelected = _isDeparture || _isReturn;
    final inRange = _isInRange;
    final showRangeBg = isSelected || inRange;

    // Il range strip si arrotonda solo agli estremi (o ai bordi di riga)
    final isRangeLeftRounded = _isDeparture || (inRange && isFirstOfRow);
    final isRangeRightRounded = _isReturn || (inRange && isLastOfRow);

    // Colore testo
    final textColor = isPast
        ? cs.onSurface.withValues(alpha: 0.38)
        : isSelected
        ? cs.onPrimary
        : inRange
        ? cs.onPrimaryContainer
        : cs.onSurface;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Range background strip ─────────────────────────────────
            if (showRangeBg)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.horizontal(
                      left: isRangeLeftRounded
                          ? const Radius.circular(AppConstants.pillBorderRadius)
                          : Radius.zero,
                      right: isRangeRightRounded
                          ? const Radius.circular(AppConstants.pillBorderRadius)
                          : Radius.zero,
                    ),
                  ),
                ),
              ),

            // ── Cerchio pieno per i giorni selezionati (start/end) ─────
            if (isSelected)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),

            // ── Anello "oggi" (solo se non selezionato) ────────────────
            if (_isToday && !isSelected)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: cs.primary, width: 1.5),
                  shape: BoxShape.circle,
                ),
              ),

            // ── Numero del giorno ──────────────────────────────────────
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: context.fontSizeXs,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

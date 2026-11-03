import 'ai_packing.dart';
import 'trip_model.dart';

/// Avanzamento della valigia in due fasi: prima si sistemano i posti
/// importanti, poi si spunta ciò che entra in valigia.
///
/// Un risultato senza posti (`slots == null`) conta solo gli oggetti del
/// viaggio, come prima dei posti.
class SuitcaseProgress {
  const SuitcaseProgress({
    required this.mine,
    required this.proposed,
    required this.importantOpen,
    required this.checked,
  });

  factory SuitcaseProgress.of(TripModel trip) {
    final slots = trip.aiResult?.slots ?? const <AiSlot>[];
    final open = slots.where((slot) => slot.isOpen);
    final usefulOpen = open.where((slot) => slot.level == AiSlotLevel.useful);
    return SuitcaseProgress(
      mine: trip.items.length,
      proposed: usefulOpen.length,
      importantOpen: open
          .where((slot) => slot.level == AiSlotLevel.important)
          .length,
      checked:
          trip.items.where((item) => item.isChecked).length +
          usefulOpen.where((slot) => slot.checked).length,
    );
  }

  /// Oggetti del viaggio.
  final int mine;

  /// Posti utili aperti.
  final int proposed;

  /// Posti importanti aperti, "da comprare" compresi.
  final int importantOpen;

  /// Oggetti spuntati più proposti spuntati.
  final int checked;

  /// Finché c'è un importante aperto si sta ancora sistemando.
  bool get sorting => importantOpen > 0;

  int get ready => mine + proposed;

  int get readyTotal => mine + proposed + importantOpen;

  int get packTotal => mine + proposed;

  bool get isEmpty => readyTotal == 0;
}

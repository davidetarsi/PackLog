import '../../../model/ai_packing.dart';

/// "×N" se restano più copie da riempire, altrimenti `null`. Con [always]
/// anche "×1" e "×0" (il riquadro aperto mostra sempre quante ne mancano).
String? slotCopiesLabel(AiSlot slot, {bool always = false}) =>
    always || slot.remaining > 1 ? '×${slot.remaining}' : null;

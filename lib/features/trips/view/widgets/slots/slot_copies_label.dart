import '../../../model/ai_packing.dart';

/// "×N" se restano più copie da riempire, altrimenti `null`.
String? slotCopiesLabel(AiSlot slot) =>
    slot.remaining > 1 ? '×${slot.remaining}' : null;

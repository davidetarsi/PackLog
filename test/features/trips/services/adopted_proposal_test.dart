import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/services/adopted_proposal.dart';

const _reason = AiReason(code: 'base', label: 'Base', sentence: 'Serve.');

AiPackingResult _result({
  List<AiPackedItem> proposal = const [],
  List<AiKitAdded> kitAdded = const [],
}) => AiPackingResult(
  generatedAt: DateTime(2026, 11, 8),
  houseId: 'h1',
  proposal: proposal,
  kitAdded: kitAdded,
);

void main() {
  group('adoptedQuantities', () {
    test('proposta e kit sullo stesso oggetto: il massimo, mai la somma', () {
      final result = _result(
        proposal: const [
          AiPackedItem(itemId: 'A', quantity: 1, reason: _reason),
        ],
        kitAdded: const [
          AiKitAdded(kitId: 'k1', itemId: 'A', copies: 2),
          AiKitAdded(kitId: 'k2', itemId: 'A', copies: 3),
        ],
      );
      expect(adoptedQuantities(result, available: const {'A': 5}), {'A': 3});
    });

    test('entro i pezzi in casa, almeno 1; senza quantità salvata, 1', () {
      final result = _result(
        proposal: const [
          AiPackedItem(itemId: 'A', quantity: 4, reason: _reason),
          AiPackedItem(itemId: 'B', quantity: 0, reason: _reason),
          AiPackedItem(itemId: 'C', quantity: 2, reason: _reason),
        ],
      );
      expect(
        adoptedQuantities(result, available: const {'A': 2, 'B': 3, 'C': null}),
        {'A': 2, 'B': 1, 'C': 1},
      );
    });

    test('un oggetto non più in casa si salta', () {
      final result = _result(
        proposal: const [
          AiPackedItem(itemId: 'A', quantity: 1, reason: _reason),
        ],
        kitAdded: const [AiKitAdded(kitId: 'k1', itemId: 'Z')],
      );
      expect(adoptedQuantities(result, available: const {'A': 1}), {'A': 1});
    });

    test('armadio non noto: niente tetto e niente oggetti saltati', () {
      final result = _result(
        proposal: const [
          AiPackedItem(itemId: 'A', quantity: 4, reason: _reason),
        ],
        kitAdded: const [AiKitAdded(kitId: 'k1', itemId: 'Z', copies: 2)],
      );
      expect(adoptedQuantities(result), {'A': 4, 'Z': 2});
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/suitcase_progress.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';

TripItem _item(int n, {bool checked = false}) => TripItem(
  id: 'i$n',
  name: 'Oggetto $n',
  category: ItemCategory.vestiti,
  quantity: 1,
  isChecked: checked,
);

AiSlot _slot(
  String id,
  AiSlotLevel level, {
  int remaining = 1,
  bool toBuy = false,
  bool checked = false,
  bool removed = false,
}) => AiSlot(
  id: id,
  type: id,
  category: ItemCategory.vestiti,
  level: level,
  name: id,
  copies: 1,
  remaining: remaining,
  addLabel: 'x',
  toBuy: toBuy,
  checked: checked,
  removed: removed,
);

TripModel _trip({
  List<TripItem> items = const [],
  List<AiSlot>? slots,
  bool withResult = true,
}) => TripModel(
  id: 't',
  name: 'Viaggio',
  items: items,
  aiResult: withResult
      ? AiPackingResult(
          generatedAt: DateTime.utc(2026, 11, 1),
          houseId: 'casa',
          slots: slots,
        )
      : null,
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1),
);

void main() {
  group('SuitcaseProgress', () {
    test('4 oggetti, 9 utili aperti, 5 importanti aperti: si sistema', () {
      final progress = SuitcaseProgress.of(
        _trip(
          items: [for (var i = 0; i < 4; i++) _item(i)],
          slots: [
            for (var i = 0; i < 9; i++) _slot('u$i', AiSlotLevel.useful),
            for (var i = 0; i < 5; i++)
              _slot('m$i', AiSlotLevel.important, toBuy: i == 0),
          ],
        ),
      );

      expect(progress.mine, 4);
      expect(progress.proposed, 9);
      expect(progress.importantOpen, 5);
      expect(progress.sorting, isTrue);
      expect(progress.ready, 13);
      expect(progress.readyTotal, 18);
      expect(progress.isEmpty, isFalse);
    });

    test('proposte da comprare e posti tolti non entrano nei conteggi', () {
      final progress = SuitcaseProgress.of(
        _trip(
          items: [for (var i = 0; i < 4; i++) _item(i)],
          slots: [
            for (var i = 0; i < 9; i++)
              _slot('u$i', AiSlotLevel.useful, toBuy: i < 2),
            _slot('ur', AiSlotLevel.useful, removed: true),
            for (var i = 0; i < 5; i++)
              _slot(
                'm$i',
                AiSlotLevel.important,
                toBuy: i == 0,
                removed: i == 1,
              ),
          ],
        ),
      );

      expect(progress.proposed, 7);
      expect(progress.importantOpen, 4);
      expect(progress.readyTotal, 15);
    });

    test('9 oggetti (4 spuntati), 2 utili aperti (1 spuntato): in valigia', () {
      final progress = SuitcaseProgress.of(
        _trip(
          items: [for (var i = 0; i < 9; i++) _item(i, checked: i < 4)],
          slots: [
            _slot('u1', AiSlotLevel.useful, checked: true),
            _slot('u2', AiSlotLevel.useful),
          ],
        ),
      );

      expect(progress.sorting, isFalse);
      expect(progress.checked, 5);
      expect(progress.packTotal, 11);
    });

    test('0 e 0: vuoto', () {
      final progress = SuitcaseProgress.of(_trip());
      expect(progress.isEmpty, isTrue);
      expect(progress.sorting, isFalse);
      expect(progress.checked, 0);
    });

    test('posti chiusi non contano', () {
      final progress = SuitcaseProgress.of(
        _trip(
          slots: [
            _slot('u1', AiSlotLevel.useful, remaining: 0, checked: true),
            _slot('m1', AiSlotLevel.important, remaining: 0),
          ],
        ),
      );
      expect(progress.proposed, 0);
      expect(progress.importantOpen, 0);
      expect(progress.checked, 0);
      expect(progress.isEmpty, isTrue);
    });

    test('risultato vecchio senza posti: solo conteggi degli oggetti', () {
      final progress = SuitcaseProgress.of(
        _trip(items: [_item(1, checked: true), _item(2)], slots: null),
      );
      expect(progress.mine, 2);
      expect(progress.proposed, 0);
      expect(progress.importantOpen, 0);
      expect(progress.checked, 1);
      expect(progress.sorting, isFalse);
      expect(progress.packTotal, 2);
    });

    test('viaggio senza aiResult: stesso comportamento', () {
      final progress = SuitcaseProgress.of(
        _trip(items: [_item(1)], withResult: false),
      );
      expect(progress.mine, 1);
      expect(progress.proposed, 0);
      expect(progress.importantOpen, 0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/kits/helpers/kit_trip_plan.dart';
import 'package:pack_log/features/kits/model/kit_model.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';

void main() {
  final now = DateTime(2026, 11, 3);

  ItemModel item(String id, {int? quantity}) => ItemModel(
    id: id,
    houseId: 'h1',
    name: id,
    category: ItemCategory.vestiti,
    quantity: quantity,
    createdAt: now,
    updatedAt: now,
  );

  KitModel kit(Map<String, int> copies) => KitModel(
    id: 'k1',
    houseId: 'h1',
    name: 'Sci',
    items: [
      for (final e in copies.entries)
        KitItem(id: 'r-${e.key}', kitId: 'k1', itemId: e.key, copies: e.value),
    ],
    createdAt: now,
    updatedAt: now,
  );

  final trip = TripModel(
    id: 't1',
    name: 'Viaggio',
    createdAt: now,
    updatedAt: now,
  );

  test('le copie stanno fra 1 e quelle in casa, con minimo 1', () {
    final plan = planKitForTrip(
      kit: kit({'a': 0, 'b': 9, 'c': 2}),
      houseItems: [item('a', quantity: 3), item('b', quantity: 0), item('c')],
      trip: trip,
    );

    expect(
      {for (final i in plan.toAdd) i.id: i.quantity},
      {'a': 1, 'b': 1, 'c': 1},
    );
  });
}

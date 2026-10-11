import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/trips/view/trip_info_form.dart';
import 'package:pack_log/shared/widgets/app_pill_tab.dart';

/// Nessuna casa: basta a far rispondere subito il ramo "Casa" del form,
/// senza database.
class _NoHouses extends HouseNotifier {
  @override
  Future<List<HouseModel>> build() async => const [];
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [houseNotifierProvider.overrideWith(_NoHouses.new)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TripInfoForm(
              onChanged:
                  ({
                    description,
                    departureDateTime,
                    returnDateTime,
                    destinationHouseId,
                    destinationLocation,
                    destinationName,
                    name,
                  }) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // La pill "Casa" è l'unica icona casa dentro il toggle di destinazione.
  final houseTogglePill = find.descendant(
    of: find.byType(AppPillTab<bool>),
    matching: find.byIcon(Icons.home_outlined),
  );

  testWidgets('con Altra località il testo invita a scegliere Casa', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(const Key('destination_hint_other')), findsOneWidget);
    expect(find.byKey(const Key('destination_hint_house')), findsNothing);
  });

  testWidgets('con Casa il testo spiega cosa succede agli oggetti', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(houseTogglePill);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('destination_hint_house')), findsOneWidget);
    expect(find.byKey(const Key('destination_hint_other')), findsNothing);
  });
}

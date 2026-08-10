import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/widgets/items_empty_state.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';

/// Il vuoto degli oggetti è lo stesso componente nella casa e nel form di
/// creazione viaggio: le due schermate erano divergenti (una senza azione,
/// l'altra con un testo cliccabile) ed è esattamente ciò che questo widget
/// impedisce di rifare.
void main() {
  Future<void> pumpEmptyState(WidgetTester tester, {String? houseId}) {
    return tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ItemsEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Nessun oggetto',
              houseId: houseId,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('con una casa nota offre un bottone, non un testo cliccabile', (
    tester,
  ) async {
    await pumpEmptyState(tester, houseId: 'house-1');

    expect(find.byType(DsButton), findsOneWidget);
  });

  testWidgets('senza casa non offre alcuna azione', (tester) async {
    // Non c'è una casa in cui scrivere l'oggetto: un bottone qui aprirebbe un
    // form che non sa dove salvare.
    await pumpEmptyState(tester);

    expect(find.byType(DsButton), findsNothing);
  });

  testWidgets('l icona ha lo stesso colore del testo', (tester) async {
    // In arancione competeva con la CTA, che nella schermata deve restare
    // l'unico elemento colorato.
    await pumpEmptyState(tester, houseId: 'house-1');

    final icon = tester.widget<Icon>(find.byIcon(Icons.inventory_2_outlined));
    final title = tester.widget<Text>(find.text('Nessun oggetto'));

    expect(icon.color, title.style!.color);
    expect(icon.color, isNot(AppTheme.dark.colorScheme.primary));
  });
}

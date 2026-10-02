import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_date_range.dart';
import 'package:pack_log/features/trips/view/trip_date_range_screen.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/universal_action_bar.dart';

/// Raccoglie il valore restituito dal `pop` della schermata.
class _Result {
  TripDateRange? value;
}

/// Il calendario è l'unico modo per esprimere le date di un viaggio: se la
/// conferma pretende il range completo, un viaggio con la sola partenza (che la
/// validazione considera valido) non è esprimibile dalla UI — il bottone spento
/// che la spec voleva eliminare si limiterebbe a spostarsi qui.
void main() {
  /// Monta la schermata dietro un push reale, così il `pop` della CTA
  /// restituisce davvero un valore da controllare.
  Future<_Result> pushScreen(
    WidgetTester tester, {
    DateTime? initialDeparture,
    DateTime? initialReturn,
  }) async {
    final result = _Result();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result.value = await Navigator.of(context)
                        .push<TripDateRange>(
                          MaterialPageRoute(
                            builder: (_) => TripDateRangeScreen(
                              initialDeparture: initialDeparture,
                              initialReturn: initialReturn,
                            ),
                          ),
                        );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  UniversalActionBar actionBar(WidgetTester tester) =>
      tester.widget<UniversalActionBar>(find.byType(UniversalActionBar));

  group('TripDateRangeScreen — conferma', () {
    testWidgets('senza alcuna data la conferma resta spenta', (tester) async {
      await pushScreen(tester);

      expect(actionBar(tester).onPrimaryPressed, isNull);
    });

    testWidgets('con la sola data di partenza la conferma è attiva', (
      tester,
    ) async {
      await pushScreen(tester, initialDeparture: DateTime(2026, 9, 12));

      expect(actionBar(tester).onPrimaryPressed, isNotNull);
    });

    testWidgets(
      'confermando con la sola partenza il range torna senza data di ritorno',
      (tester) async {
        // Il giro completo: il tasto indietro restituisce null e la selezione
        // va persa, quindi è la conferma a dover uscire con un range parziale.
        final result = await pushScreen(
          tester,
          initialDeparture: DateTime(2026, 9, 12),
        );

        // Le chiavi di traduzione restano tali senza EasyLocalization: con la
        // sola partenza l'etichetta è quella generica.
        await tester.tap(find.text('common.confirm'));
        await tester.pumpAndSettle();

        expect(result.value, isNotNull);
        expect(result.value!.departureDate, DateTime(2026, 9, 12));
        expect(result.value!.returnDate, isNull);
      },
    );

    testWidgets('con il range completo la conferma resta attiva', (
      tester,
    ) async {
      await pushScreen(
        tester,
        initialDeparture: DateTime(2026, 9, 12),
        initialReturn: DateTime(2026, 9, 15),
      );

      expect(actionBar(tester).onPrimaryPressed, isNotNull);
      expect(find.text('trips.confirm_dates'), findsOneWidget);
    });
  });
}

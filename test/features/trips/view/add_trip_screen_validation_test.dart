import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/trips/view/add_trip_screen.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/universal_action_bar.dart';

class MockHouseRepository extends Mock implements HouseRepository {}

/// La spec di design richiede esplicitamente: senza data di partenza la CTA
/// resta attiva (mai un bottone spento senza spiegazione) e produce uno
/// snackbar di errore che nomina il campo mancante. Prima di questo test
/// solo la funzione pura `tripFormError` era coperta — che `onPrimaryPressed`
/// non sia mai `null` e che lo snackbar parta davvero non era verificato da
/// nulla.
void main() {
  late MockHouseRepository houseRepo;

  setUp(() {
    houseRepo = MockHouseRepository();
    when(() => houseRepo.getAllHouses()).thenAnswer(
      (_) async => [
        HouseModel(
          id: 'house-1',
          name: 'Casa',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [houseRepositoryProvider.overrideWithValue(houseRepo)],
        child: MaterialApp(theme: AppTheme.light, home: const AddTripScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AddTripScreen — validazione', () {
    testWidgets(
      'senza data di partenza la CTA resta attiva e mostra un errore',
      (tester) async {
        await pumpScreen(tester);

        final actionBar = tester.widget<UniversalActionBar>(
          find.byType(UniversalActionBar),
        );
        expect(
          actionBar.onPrimaryPressed,
          isNotNull,
          reason:
              'un bottone spento senza spiegazione non fa distinguere '
              '"manca qualcosa" da "l\'app è rotta"',
        );

        // Senza EasyLocalization montata `.tr()` restituisce la chiave grezza:
        // è il testo reale del bottone in questo contesto di test, non un
        // placeholder — vedi _ctaLabel() in add_trip_screen.dart.
        await tester.tap(find.text('common.next'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  });
}

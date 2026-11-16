import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/view/add_edit_house_screen.dart';
import 'package:pack_log/features/items/view/item_sheet.dart';
import 'package:pack_log/features/luggages/view/add_edit_luggage_screen.dart';
import 'package:pack_log/features/promo/view/promo_code_sheet.dart';
import 'package:pack_log/features/spaces/view/add_edit_space_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/support/harness.dart';
import '../screenshots/support/seed.dart';

/// Regola: quello che l'utente sta scrivendo non si perde quando l'app va in
/// background e torna. Al ritorno parte il pull, che fa ricaricare le liste:
/// la schermata o il foglio aperto devono restare com'erano, testo compreso.
///
/// Ogni voce è un posto dell'app con un campo di testo. Per aggiungerne uno
/// basta una riga in [_places].
typedef _Open = Future<void> Function(ScreenshotApp app);

_Open _route(String location) => (app) async {
  await app.go('/');
  await app.push(location);
};

/// Un foglio aperto sopra [location], come fa l'app.
_Open _sheet(String location, void Function(BuildContext context) show) =>
    (app) async {
      await _route(location)(app);
      final context = app.router.routerDelegate.navigatorKey.currentContext!;
      show(context);
      await app.settle();
    };

final Map<String, _Open> _places = {
  'ricerca nella casa': (app) async {
    await _route('/houses/$kHomeId')(app);
    await app.tap(find.byKey(const Key('house_search')));
  },
  'kit nuovo': _route('/houses/$kHomeId/kits/new'),
  'nuovo viaggio': _route('/new-trip'),
  'modifica del viaggio': _route('/trips/$kUpcomingTripId/edit-info'),
  'aggiungi alla valigia': _route('/trips/$kUpcomingTripId/edit-items'),
  'foglio della casa': _sheet(
    '/',
    (c) => unawaited(showAddEditHouseSheet(c, houseId: kHomeId)),
  ),
  'foglio dello spazio': _sheet(
    '/houses/$kHomeId',
    (c) => unawaited(showAddEditSpaceSheet(c, houseId: kHomeId)),
  ),
  'foglio del bagaglio': _sheet(
    '/',
    (c) => unawaited(showAddEditLuggageSheet(c, luggageId: 'lug-cabina')),
  ),
  'scheda dell oggetto': _sheet(
    '/houses/$kHomeId',
    (c) => unawaited(showItemSheet(c, houseId: kHomeId, itemId: 'item-0')),
  ),
  'codice promo': _sheet(
    '/profile',
    (c) => unawaited(showPromoCodeSheet(c, redeemNow: false)),
  ),
};

/// Vero se il focus è dentro un campo di testo.
bool _isTyping() =>
    FocusManager.instance.primaryFocus?.context?.widget is EditableText ||
    (FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });

  for (final place in _places.entries) {
    testWidgets('${place.key}: il testo resta dopo background e pull', (
      tester,
    ) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await place.value(app);

      final field = find.byType(TextField).first;
      expect(field, findsOneWidget, reason: 'nessun campo di testo aperto');
      await app.enterText(field, 'Prova 42');
      final fieldsBefore = find.byType(TextField).evaluate().length;
      final hadFocus = _isTyping();

      // L'app va in background e torna; al ritorno il pull finisce.
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      app.container.read(syncTriggerProvider.notifier).increment();
      await tester.pump();
      expect(
        find.byType(TextField).evaluate(),
        hasLength(fieldsBefore),
        reason: 'durante il ricaricamento la pagina è stata sostituita',
      );
      await app.settle();

      final texts = [
        for (final e in find.byType(TextField).evaluate())
          (e.widget as TextField).controller?.text.toLowerCase(),
      ];
      expect(texts, contains('prova 42'), reason: 'il testo scritto è sparito');
      expect(texts, hasLength(fieldsBefore), reason: 'la pagina è cambiata');
      expect(_isTyping(), hadFocus, reason: 'il campo ha perso il focus');
      await app.finish();
    });
  }
}

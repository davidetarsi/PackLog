import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/widgets/tab_header.dart';

void main() {
  group('profileInitials', () {
    test('nome e cognome', () {
      expect(profileInitials('Davide Rossi', 'd@x.it'), 'DR');
    });
    test('tre parole: prima e ultima', () {
      expect(profileInitials('Anna Maria Bianchi', 'a@x.it'), 'AB');
    });
    test('un solo nome', () {
      expect(profileInitials('  davide ', 'd@x.it'), 'D');
    });
    test('iniziali fuori dal BMP (emoji) non spezzano la coppia surrogata', () {
      expect(profileInitials('😀 Luca', 'l@x.it'), '😀L');
      expect(profileInitials('Luca 😀', 'l@x.it'), 'L😀');
      expect(profileInitials(null, '😀@x.it'), '😀'.toUpperCase());
    });
    test('senza nome usa la email', () {
      expect(profileInitials(null, 'marco@x.it'), 'M');
      expect(profileInitials('', 'marco@x.it'), 'M');
    });
    test('niente di niente', () {
      expect(profileInitials(null, ''), '?');
    });
  });

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('mostra le iniziali e il pallino solo se richiesto', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        ProfileAvatar(initials: 'DR', showSyncDot: false, onTap: () => taps++),
      ),
    );
    expect(find.text('DR'), findsOneWidget);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);

    await tester.tap(find.byKey(const Key('profile_avatar')));
    expect(taps, 1);

    await tester.pumpWidget(
      wrap(ProfileAvatar(initials: 'DR', showSyncDot: true, onTap: () {})),
    );
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
  });
}

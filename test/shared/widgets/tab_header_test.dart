import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
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
    expect(find.byKey(const Key('profile_sync_dot')), findsNothing);

    await tester.tap(find.byKey(const Key('profile_avatar')));
    expect(taps, 1);

    await tester.pumpWidget(
      wrap(ProfileAvatar(initials: 'DR', showSyncDot: true, onTap: () {})),
    );
    expect(find.byKey(const Key('profile_sync_dot')), findsOneWidget);
  });

  testWidgets('l avatar ha il bordino arancio del tema', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ProfileAvatar(initials: 'DR', showSyncDot: true, onTap: () {}),
        ),
      ),
    );
    final cs = AppTheme.light.colorScheme;
    BoxDecoration decorationOf(String key) =>
        tester.widget<Container>(find.byKey(Key(key))).decoration!
            as BoxDecoration;

    final circle = decorationOf('profile_initials_circle');
    expect(circle.color, cs.primaryContainer);
    expect((circle.border! as Border).top.color, cs.primary);

    // Il pallino ha un anello del colore di fondo: non si incolla al bordo.
    final dot = decorationOf('profile_sync_dot');
    expect(dot.color, cs.primary);
    expect((dot.border! as Border).top.color, cs.surface);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:pack_log/shared/widgets/ds_empty_state.dart';
import 'package:pack_log/shared/widgets/ds_link_button.dart';
import 'package:pack_log/shared/widgets/refreshable_empty_state.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('CTA e link personalizzati, la CTA sopra il link', (
    tester,
  ) async {
    var cta = 0;
    var link = 0;
    await pump(
      tester,
      DsEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nessun oggetto',
        ctaLabel: 'Scansiona con AI',
        ctaIcon: Icons.auto_awesome,
        onCta: () => cta++,
        linkLabel: 'Scrivili a mano',
        onLink: () => link++,
      ),
    );
    expect(find.byType(DsButton), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byType(DsLinkButton), findsOneWidget);
    expect(
      tester.getCenter(find.text('Scansiona con AI')).dy,
      lessThan(tester.getCenter(find.text('Scrivili a mano')).dy),
    );
    await tester.tap(find.text('Scansiona con AI'));
    await tester.tap(find.text('Scrivili a mano'));
    expect((cta, link), (1, 1));
  });

  testWidgets('senza contenuti niente bottoni', (tester) async {
    await pump(
      tester,
      const DsEmptyState(icon: Icons.search_off, title: 'Niente'),
    );
    expect(find.byType(DsButton), findsNothing);
    expect(find.byType(DsLinkButton), findsNothing);
  });

  testWidgets('la versione con pull-to-refresh passa gli stessi contenuti', (
    tester,
  ) async {
    await pump(
      tester,
      RefreshableEmptyState(
        onRefresh: () async {},
        icon: Icons.inventory_2_outlined,
        title: 'Nessun oggetto',
        ctaLabel: 'Scansiona con AI',
        onCta: () {},
        linkLabel: 'Scrivili a mano',
        onLink: () {},
      ),
    );
    expect(find.byType(DsButton), findsOneWidget);
    expect(find.byType(DsLinkButton), findsOneWidget);
  });

  testWidgets('l icona resta neutra', (tester) async {
    await pump(
      tester,
      DsEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nessun oggetto',
        ctaLabel: 'Scansiona con AI',
        onCta: () {},
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.inventory_2_outlined));
    expect(icon.color, isNot(AppTheme.light.colorScheme.primary));
  });

  testWidgets('l icona ha lo stesso colore del testo', (tester) async {
    // Dal test del vecchio ItemsEmptyState: in arancione l'icona competeva
    // con la CTA, che deve restare l'unico elemento colorato.
    await pump(
      tester,
      DsEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nessun oggetto',
        ctaLabel: 'Scansiona con AI',
        onCta: () {},
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.inventory_2_outlined));
    final title = tester.widget<Text>(find.text('Nessun oggetto'));
    expect(icon.color, title.style!.color);
  });
}

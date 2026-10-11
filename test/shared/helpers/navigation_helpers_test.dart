import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pack_log/shared/helpers/navigation_helpers.dart';

GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const Text('home')),
    GoRoute(path: '/other', builder: (_, _) => const Text('other')),
    GoRoute(
      path: '/detail',
      builder: (_, _) => Builder(
        builder: (context) => TextButton(
          key: const Key('back'),
          onPressed: () => context.popOrGo('/'),
          child: const Text('detail'),
        ),
      ),
    ),
  ],
);

void main() {
  testWidgets('con uno stack sotto torna alla pagina precedente', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/other');
    await tester.pumpAndSettle();
    router.push('/detail');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();

    expect(find.text('other'), findsOneWidget);
    expect(find.text('home'), findsNothing);
  });

  testWidgets('senza stack sotto va al fallback invece di fallire', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/detail');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

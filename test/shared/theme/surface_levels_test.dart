import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/theme/surface_colors.dart';
import 'package:pack_log/shared/widgets/ds_field.dart';
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';
import 'package:pack_log/shared/widgets/ds_group_header.dart';
import 'package:pack_log/shared/widgets/ds_settings.dart';

/// Tre livelli di superficie: pagina, superficie 1 (card e fogli) e
/// superficie 2 (card dentro un foglio, campi). Ogni livello si stacca dal
/// precedente, in chiaro e in scuro.
void main() {
  Future<BuildContext> pumpWith(
    WidgetTester tester,
    ThemeData theme,
    Widget Function(BuildContext) child,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              captured = context;
              return child(context);
            },
          ),
        ),
      ),
    );
    return captured;
  }

  double luminance(Color c) => c.computeLuminance();

  for (final (name, theme) in [
    ('chiaro', AppTheme.light),
    ('scuro', AppTheme.dark),
  ]) {
    group('tema $name', () {
      testWidgets('i tre livelli sono tutti diversi', (tester) async {
        final context = await pumpWith(tester, theme, (_) => const SizedBox());
        final page = context.pageSurface;
        final raised = context.raisedSurface;
        final nested = context.nestedSurface;
        expect({page, raised, nested}, hasLength(3));
      });

      testWidgets('la pagina è il fondo del tema', (tester) async {
        final context = await pumpWith(tester, theme, (_) => const SizedBox());
        expect(context.pageSurface, theme.colorScheme.surface);
      });
    });
  }

  testWidgets('scuro: ogni livello è più chiaro del precedente', (
    tester,
  ) async {
    final context = await pumpWith(
      tester,
      AppTheme.dark,
      (_) => const SizedBox(),
    );
    expect(
      luminance(context.raisedSurface),
      greaterThan(luminance(context.pageSurface)),
    );
    expect(
      luminance(context.nestedSurface),
      greaterThan(luminance(context.raisedSurface)),
    );
  });

  testWidgets('chiaro: fogli e card bianchi su fondo grigio, card interne più '
      'scure del foglio', (tester) async {
    final context = await pumpWith(
      tester,
      AppTheme.light,
      (_) => const SizedBox(),
    );
    expect(context.raisedSurface, Colors.white);
    expect(
      luminance(context.pageSurface),
      lessThan(luminance(context.raisedSurface)),
    );
    expect(
      luminance(context.nestedSurface),
      lessThan(luminance(context.raisedSurface)),
    );
  });

  for (final (name, theme) in [
    ('chiaro', AppTheme.light),
    ('scuro', AppTheme.dark),
  ]) {
    group('componenti, tema $name', () {
      Color? groupColor(WidgetTester tester) => tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(DsSettingsGroup),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;

      Color? fieldFill(WidgetTester tester) => tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration
          .fillColor;

      testWidgets('fuori da un foglio card e campi sono superficie 1', (
        tester,
      ) async {
        final context = await pumpWith(
          tester,
          theme,
          (_) => const Column(
            children: [
              DsSettingsGroup(children: [Text('riga')]),
              DsTextField(),
            ],
          ),
        );
        expect(groupColor(tester), context.raisedSurface);
        expect(fieldFill(tester), context.raisedSurface);
      });

      testWidgets('l\'etichetta di un gruppo ha il fondo di ciò che la regge', (
        tester,
      ) async {
        Color? headerColor() => tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byType(DsGroupHeader),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color;

        final onPage = await pumpWith(
          tester,
          theme,
          (_) => const DsGroupHeader(label: 'Gruppo'),
        );
        expect(headerColor(), onPage.pageSurface);

        final inSheet = await pumpWith(
          tester,
          theme,
          (_) => const DsFormSheet(
            title: 'Foglio',
            child: DsGroupHeader(label: 'Gruppo'),
          ),
        );
        expect(headerColor(), inSheet.raisedSurface);
      });

      testWidgets('il foglio è superficie 1, card e campi dentro sono 2', (
        tester,
      ) async {
        final context = await pumpWith(
          tester,
          theme,
          (_) => const DsFormSheet(
            title: 'Foglio',
            child: Column(
              children: [
                DsSettingsGroup(children: [Text('riga')]),
                DsTextField(),
              ],
            ),
          ),
        );
        final frame =
            tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: find.byType(DsFormSheet),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(frame.color, context.raisedSurface);
        expect(frame.color, isNot(context.pageSurface));
        expect(groupColor(tester), context.nestedSurface);
        expect(fieldFill(tester), context.nestedSurface);
        expect(groupColor(tester), isNot(frame.color));
      });
    });
  }
}

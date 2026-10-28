import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_choice_group.dart';
import 'package:pack_log/shared/widgets/ds_choice_pill.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  /// Gruppo di prova: `onChanged` registra l'ultimo insieme emesso.
  Widget choiceGroup({
    required Set<String> selected,
    required void Function(Set<String>) onChanged,
    bool multiple = false,
    bool required = true,
    String? note,
    bool doubt = false,
    Widget? trailing,
  }) => DsChoiceGroup<String>(
    title: 'Colore',
    options: const ['Bianco', 'Nero', 'Blu'],
    labelOf: (s) => s,
    selected: selected,
    onChanged: onChanged,
    multiple: multiple,
    required: required,
    note: note,
    doubt: doubt,
    trailing: trailing,
  );

  testWidgets('mostra il titolo e una pillola per opzione', (tester) async {
    await pump(tester, choiceGroup(selected: const {'Blu'}, onChanged: (_) {}));
    expect(find.text('Colore'), findsOneWidget);
    expect(find.byType(DsChoicePill), findsNWidgets(3));
  });

  testWidgets('la pillola selezionata è quella dell’insieme', (tester) async {
    await pump(tester, choiceGroup(selected: const {'Blu'}, onChanged: (_) {}));
    final pills = tester
        .widgetList<DsChoicePill>(find.byType(DsChoicePill))
        .toList();
    expect(pills.map((p) => p.selected), [false, false, true]);
  });

  testWidgets('la nota sta sulla stessa riga del titolo', (tester) async {
    await pump(
      tester,
      choiceGroup(
        selected: const {'Blu'},
        onChanged: (_) {},
        note: 'anche più di uno',
      ),
    );
    final titleY = tester.getCenter(find.text('Colore')).dy;
    final noteY = tester.getCenter(find.text('anche più di uno')).dy;
    expect((titleY - noteY).abs(), lessThanOrEqualTo(4));
  });

  testWidgets('senza dubbio la nota non ha icona', (tester) async {
    await pump(
      tester,
      choiceGroup(
        selected: const {'Blu'},
        onChanged: (_) {},
        note: 'anche più di uno',
      ),
    );
    expect(find.byIcon(Icons.help_outline), findsNothing);
  });

  testWidgets('con dubbio mostra Icons.help_outline accanto alla nota', (
    tester,
  ) async {
    await pump(
      tester,
      choiceGroup(
        selected: const {'Blu'},
        onChanged: (_) {},
        note: 'da controllare',
        doubt: true,
      ),
    );
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.text('da controllare'), findsOneWidget);
  });

  testWidgets('con dubbio e senza nota mostra solo l’icona', (tester) async {
    await pump(
      tester,
      choiceGroup(selected: const {'Blu'}, onChanged: (_) {}, doubt: true),
    );
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.byType(Text), findsNWidgets(4)); // titolo + 3 pillole
  });

  testWidgets('il trailing finisce in coda alle pillole', (tester) async {
    await pump(
      tester,
      choiceGroup(
        selected: const {'Blu'},
        onChanged: (_) {},
        trailing: const Text('+ Altro colore'),
      ),
    );
    expect(find.text('+ Altro colore'), findsOneWidget);
  });

  testWidgets('onTouched arriva anche confermando la scelta attuale', (
    tester,
  ) async {
    var touched = 0;
    Set<String>? emitted;
    await pump(
      tester,
      DsChoiceGroup<String>(
        title: 'Pioggia',
        options: const ['Si bagna', 'Impermeabile'],
        labelOf: (s) => s,
        selected: const {'Si bagna'},
        onChanged: (s) => emitted = s,
        onTouched: () => touched++,
      ),
    );
    await tester.tap(find.text('Si bagna'));
    expect(touched, 1);
    expect(emitted, isNull);
  });

  testWidgets('una nota lunga si accorcia invece di sforare', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(
      tester,
      choiceGroup(
        selected: const {'Blu'},
        onChanged: (_) {},
        doubt: true,
        note: 'da controllare con molta attenzione prima di salvare',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  group('scelta singola obbligatoria', () {
    testWidgets('toccare la scelta attuale non emette nulla', (tester) async {
      Set<String>? out;
      await pump(
        tester,
        choiceGroup(selected: const {'Blu'}, onChanged: (s) => out = s),
      );
      await tester.tap(find.text('Blu'));
      expect(out, isNull);
    });

    testWidgets('toccare un’altra opzione la sostituisce', (tester) async {
      Set<String>? out;
      await pump(
        tester,
        choiceGroup(selected: const {'Blu'}, onChanged: (s) => out = s),
      );
      await tester.tap(find.text('Nero'));
      expect(out, {'Nero'});
    });
  });

  group('scelta singola facoltativa', () {
    testWidgets('toccare la scelta attuale la toglie', (tester) async {
      Set<String>? out;
      await pump(
        tester,
        choiceGroup(
          selected: const {'Blu'},
          required: false,
          onChanged: (s) => out = s,
        ),
      );
      await tester.tap(find.text('Blu'));
      expect(out, isEmpty);
    });

    testWidgets('toccare un’altra opzione la sostituisce', (tester) async {
      Set<String>? out;
      await pump(
        tester,
        choiceGroup(
          selected: const {'Blu'},
          required: false,
          onChanged: (s) => out = s,
        ),
      );
      await tester.tap(find.text('Bianco'));
      expect(out, {'Bianco'});
    });
  });

  group('scelta multipla', () {
    testWidgets('tocco aggiunge un’opzione non scelta', (tester) async {
      Set<String>? out;
      await pump(
        tester,
        choiceGroup(
          selected: const {'Blu'},
          multiple: true,
          onChanged: (s) => out = s,
        ),
      );
      await tester.tap(find.text('Nero'));
      expect(out, {'Blu', 'Nero'});
    });

    testWidgets('obbligatoria: non si può togliere l’ultima', (tester) async {
      Set<String>? out;
      await pump(
        tester,
        choiceGroup(
          selected: const {'Blu'},
          multiple: true,
          onChanged: (s) => out = s,
        ),
      );
      await tester.tap(find.text('Blu'));
      expect(out, isNull);
    });

    testWidgets('facoltativa: si può togliere l’ultima', (tester) async {
      Set<String>? out;
      await pump(
        tester,
        choiceGroup(
          selected: const {'Blu'},
          multiple: true,
          required: false,
          onChanged: (s) => out = s,
        ),
      );
      await tester.tap(find.text('Blu'));
      expect(out, isEmpty);
    });

    testWidgets('con più scelte togliere una lascia le altre', (tester) async {
      Set<String>? out;
      await pump(
        tester,
        choiceGroup(
          selected: const {'Blu', 'Nero'},
          multiple: true,
          onChanged: (s) => out = s,
        ),
      );
      await tester.tap(find.text('Blu'));
      expect(out, {'Nero'});
    });
  });
}

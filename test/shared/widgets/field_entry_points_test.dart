import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardia: i campi di testo passano da `DsTextField` (`ds_field.dart`) e le
/// ricerche da `DsSearchField` (`ds_search_field.dart`). Solo questi due file
/// e le eccezioni qui sotto possono chiamare `TextField(` o `TextFormField(`.
void main() {
  // Il `(?<!...)` evita `DsTextField(` e `DsSearchField(`, che sono i nostri.
  final rawField = RegExp(r'(?<![A-Za-z0-9_])Text(Form)?Field\(');

  const allowed = <String>{
    'lib/shared/widgets/ds_field.dart',
    'lib/shared/widgets/ds_search_field.dart',
    // La barra di scrittura del rapid fire, con il suo contenitore e il
    // bottone di invio.
    'lib/features/items/widgets/rapid_fire_input.dart',
  };
  const allowedDirs = <String>['lib/shared/dev/'];

  test('nessun TextField fuori dai campi del design system', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') ||
          path.endsWith('.g.dart') ||
          path.endsWith('.freezed.dart') ||
          allowed.contains(path) ||
          allowedDirs.any(path.startsWith)) {
        continue;
      }
      if (rawField.hasMatch(entity.readAsStringSync())) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'TextField( o TextFormField( fuori da DsTextField/DsSearchField in:\n'
          '${offenders.join('\n')}',
    );
  });
}

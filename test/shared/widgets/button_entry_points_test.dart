import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardia: i bottoni passano da `DsButton`, `DsTextButton` o `DsIconButton`.
/// Solo i due componenti di testo e icona e il contatore della quantità
/// possono chiamare i bottoni Material.
void main() {
  // Il `(?<!...)` evita `DsTextButton(` e `DsIconButton(`, che sono i nostri.
  final rawButton = RegExp(
    r'(?<![A-Za-z0-9_])(OutlinedButton|FilledButton|ElevatedButton|TextButton|IconButton)\b',
  );

  const allowed = <String>{
    'lib/shared/widgets/ds_text_button.dart',
    'lib/shared/widgets/ds_icon_button.dart',
    // Il contatore della quantità ha vincoli di misura suoi.
    'lib/shared/widgets/quantity_stepper.dart',
  };
  const allowedDirs = <String>['lib/shared/dev/'];

  test('nessun bottone Material fuori dai componenti', () {
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
      if (rawButton.hasMatch(entity.readAsStringSync())) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'bottone Material fuori da DsTextButton/DsIconButton/DsButton in:\n'
          '${offenders.join('\n')}',
    );
  });
}

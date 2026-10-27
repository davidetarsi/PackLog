import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardia: caselle, interruttori e snackbar passano dal design system.
/// `DsCheckbox` e `DsSwitch` per caselle e interruttori, `AppSnackBar` per gli
/// avvisi. Solo i file dei componenti chiamano `Checkbox`, `Switch` e
/// `SnackBar` direttamente.
void main() {
  // Il `(?<!...)` evita `DsCheckbox(`, `DsSwitch(` e `AppSnackBar(`, che sono
  // i nostri. `SnackBarAction(`, `CheckboxListTile(` e `SwitchListTile(`
  // non combaciano perché il `(` deve seguire subito il nome.
  final rawControl = RegExp(r'(?<![A-Za-z0-9_])(Checkbox|Switch|SnackBar)\(');

  const allowed = <String>{
    'lib/shared/widgets/ds_checkbox.dart',
    'lib/shared/helpers/snack_bar_helper.dart',
  };
  const allowedDirs = <String>['lib/shared/dev/'];

  test('nessun Checkbox, Switch o SnackBar Material fuori dai componenti', () {
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
      if (rawControl.hasMatch(entity.readAsStringSync())) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Checkbox, Switch o SnackBar Material fuori dal design system in:\n'
          '${offenders.join('\n')}',
    );
  });
}

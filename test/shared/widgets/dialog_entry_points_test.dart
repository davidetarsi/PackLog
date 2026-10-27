import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardia: ogni dialogo passa da `ds_dialog.dart`, che è l'unico file
/// autorizzato a chiamare `AlertDialog` o `showDialog`. Il resto del codice
/// usa `DsDialog` e `showDsDialog`.
void main() {
  const allowed = <String>{
    'lib/shared/widgets/ds_dialog.dart',
    // Fino al Task 6, che riscrive il menu come foglio.
    'lib/shared/widgets/entity_context_menu.dart',
  };
  const allowedDirs = <String>['lib/shared/dev/'];
  final rawShowDialog = RegExp(r'\bshowDialog\b');

  test('nessun AlertDialog o showDialog fuori da ds_dialog.dart', () {
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
      final source = entity.readAsStringSync();
      if (source.contains('AlertDialog(') || rawShowDialog.hasMatch(source)) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'AlertDialog o showDialog fuori da DsDialog/showDsDialog in:\n'
          '${offenders.join('\n')}',
    );
  });
}

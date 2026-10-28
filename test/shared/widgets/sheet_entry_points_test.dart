import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardia: ogni foglio dal basso passa da `ds_form_sheet.dart`, che è l'unico
/// file autorizzato a chiamare `showModalBottomSheet`.
void main() {
  test('nessun showModalBottomSheet fuori da ds_form_sheet.dart', () {
    const allowed = 'lib/shared/widgets/ds_form_sheet.dart';
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') ||
          path.endsWith('.g.dart') ||
          path.endsWith('.freezed.dart') ||
          path == allowed) {
        continue;
      }
      if (entity.readAsStringSync().contains('showModalBottomSheet')) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'showModalBottomSheet fuori da $allowed in:\n${offenders.join('\n')}',
    );
  });
}

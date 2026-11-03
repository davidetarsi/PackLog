import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/kits/model/kit_uses.dart';

import '../../../helpers/catalogo_di_prova.dart';

void main() {
  final catalog = catalogoDelRepo();

  test('Sci -> ski', () {
    expect(usesFromName('Sci', catalog).activities, ['ski']);
  });

  test('Settimana bianca -> ski', () {
    expect(usesFromName('Settimana bianca', catalog).activities, ['ski']);
  });

  test('Settimana bianchissima non dà ski', () {
    expect(
      usesFromName('Settimana bianchissima', catalog).activities,
      isNot(contains('ski')),
    );
  });

  test('Aereo -> plane tra i mezzi', () {
    final uses = usesFromName('Aereo', catalog);
    expect(uses.transports, ['plane']);
    expect(uses.activities, isEmpty);
  });

  test('maiuscole e accenti non contano', () {
    expect(usesFromName('CITTÀ', catalog).activities, ['city']);
  });

  test('una parola che inizia con un alias lungo vale', () {
    expect(usesFromName('Escursioni', catalog).activities, ['trekking']);
  });

  test('un alias corto non vale come prefisso', () {
    expect(usesFromName('Subacqueo', catalog).activities, isEmpty);
  });

  test('Cose varie -> vuoto', () {
    expect(usesFromName('Cose varie', catalog).isEmpty, isTrue);
  });

  test('le voci disattivate non si riconoscono', () {
    final spenta = catalogoConVoceDisattivata('activity', 'ski');
    expect(usesFromName('Sci', spenta).activities, isEmpty);
  });
}

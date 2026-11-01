import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/helpers/copies_parser.dart';

void main() {
  group('parseCopies', () {
    test('numero davanti', () {
      expect(parseCopies('2 t-shirt nere'), (name: 't-shirt nere', copies: 2));
    });

    test('numero dopo la virgola, con o senza spazio', () {
      expect(parseCopies('t-shirt nera, 2'), (name: 't-shirt nera', copies: 2));
      expect(parseCopies('t-shirt nera,2'), (name: 't-shirt nera', copies: 2));
    });

    test('se ci sono tutti e due vince quello davanti', () {
      expect(parseCopies('3 calzini, 5'), (name: 'calzini, 5', copies: 3));
    });

    test('solo da 2 a 99', () {
      expect(parseCopies('1 t-shirt'), isNull);
      expect(parseCopies('0 calzini'), isNull);
      expect(parseCopies('99 calzini'), (name: 'calzini', copies: 99));
      expect(parseCopies('calzini, 1'), isNull);
      expect(parseCopies('Cavo, 100'), isNull);
    });

    test('un numero che fa parte del nome non conta', () {
      expect(parseCopies('iPhone 15'), isNull);
      expect(parseCopies('2'), isNull);
      expect(parseCopies('2   '), isNull);
    });

    test('"2 in 1 caricatore" prende il 2 e lascia "in 1 caricatore"', () {
      expect(parseCopies('2 in 1 caricatore'), (
        name: 'in 1 caricatore',
        copies: 2,
      ));
    });

    test('niente "x2" e niente "n"', () {
      expect(parseCopies('x2 calzini'), isNull);
      expect(parseCopies('calzini x2'), isNull);
      expect(parseCopies('calzini 2x'), isNull);
    });

    test('spazi intorno ignorati', () {
      expect(parseCopies('  4   magliette  '), (name: 'magliette', copies: 4));
      expect(parseCopies('magliette , 4  '), (name: 'magliette', copies: 4));
    });
  });
}

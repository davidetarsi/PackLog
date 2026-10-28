import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/helpers/search_match.dart';

void main() {
  group('normalizeForSearch', () {
    test('toglie maiuscole e accenti', () {
      expect(normalizeForSearch('Perché ÀÈÌÒÙ àéîöü'), 'perche aeiou aeiou');
    });
  });

  group('matchesSearch', () {
    test('trova una parte del nome senza badare alle maiuscole', () {
      expect(matchesSearch('Calzini', 'CALZ'), isTrue);
      expect(matchesSearch('Calzoncini da corsa', 'da cor'), isTrue);
    });

    test('ignora gli accenti in entrambi i versi', () {
      expect(matchesSearch('Caffè', 'caffe'), isTrue);
      expect(matchesSearch('Caffe', 'caffè'), isTrue);
    });

    test('una ricerca vuota o di soli spazi trova tutto', () {
      expect(matchesSearch('Jeans blu', ''), isTrue);
      expect(matchesSearch('Jeans blu', '   '), isTrue);
    });

    test('non trova ciò che non c è', () {
      expect(matchesSearch('Jeans blu', 'calz'), isFalse);
    });
  });
}

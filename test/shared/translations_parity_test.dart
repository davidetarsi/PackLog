import 'package:flutter_test/flutter_test.dart';

import '../helpers/memory_asset_loader.dart';

Set<String> _keys(Map<String, dynamic> map, [String prefix = '']) => {
  for (final e in map.entries)
    if (e.value is Map<String, dynamic>)
      ..._keys(e.value as Map<String, dynamic>, '$prefix${e.key}.')
    else
      '$prefix${e.key}',
};

void main() {
  test('ogni chiave italiana ha la sua inglese, e viceversa', () {
    final all = readAppTranslations();
    final it = _keys(all['it_IT']!);
    final en = _keys(all['en_US']!);
    expect(it.difference(en), isEmpty, reason: 'mancano in en-US');
    expect(en.difference(it), isEmpty, reason: 'mancano in it-IT');
  });

  test('i testi del kit in valigia sono quelli concordati (it)', () {
    final kits =
        readAppTranslations()['it_IT']!['kits'] as Map<String, dynamic>;
    expect(kits['trip_pill'], 'Kit {}');
    expect(kits['trip_progress'], '{} su {} già in valigia');
    expect(kits['trip_missing'], 'Mancano {}');
    expect(kits['trip_add'], 'Aggiungili in valigia');
    expect(kits['trip_dismiss'], 'No, grazie');
    expect(
      kits['learn_question'],
      'La prossima volta lo aggiungo da solo per {}?',
    );
    expect(kits['learn_yes'], 'Sì');
    expect(kits['learn_no'], 'No');
  });
}

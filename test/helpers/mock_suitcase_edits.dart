import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/database/daos/suitcase_edits_dao.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/trips/model/suitcase_edit.dart';
import 'package:pack_log/features/trips/providers/suitcase_edits_provider.dart';

class MockSuitcaseEditsDao extends Mock implements SuitcaseEditsDao {}

class _NoItemRepository extends Mock implements ItemRepository {}

/// Un DAO che accetta ogni evento e non scrive.
MockSuitcaseEditsDao noopSuitcaseEditsDao() {
  registerFallbackValue(<SuitcaseEdit>[]);
  final fake = MockSuitcaseEditsDao();
  when(() => fake.enqueue(any())).thenAnswer((_) async {});
  return fake;
}

/// Override che manda la coda delle modifiche alla valigia in un finto DAO
/// che non scrive, e la lettura delle schede in un archivio senza oggetti:
/// i test di schermate e notifier che non guardano la coda non devono aprire
/// il database vero.
List<Override> noopSuitcaseEditsOverrides() {
  final fake = noopSuitcaseEditsDao();
  final items = _NoItemRepository();
  when(() => items.getItemById(any())).thenThrow(StateError('nessun oggetto'));
  return [
    suitcaseEditsDaoProvider.overrideWithValue(fake),
    itemRepositoryProvider.overrideWithValue(items),
  ];
}

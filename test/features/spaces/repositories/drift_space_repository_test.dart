import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/daos/spaces_dao.dart';
import 'package:pack_log/core/database/exceptions/database_exceptions.dart';
import 'package:pack_log/core/database/services/database_service.dart';
import 'package:pack_log/features/spaces/repositories/drift_space_repository.dart';

class _Database extends Mock implements AppDatabase {}

class _Dao extends Mock implements SpacesDao {}

void main() {
  late _Dao dao;
  late DriftSpaceRepository repository;
  setUp(() {
    dao = _Dao();
    repository = DriftSpaceRepository(
      dao,
      DatabaseService(_Database()),
      () => null,
    );
  });

  test('un errore leggendo la casa non diventa un elenco vuoto', () async {
    when(
      () => dao.getSpacesByHouse('h1'),
    ).thenThrow(StateError('DB non disponibile'));
    await expectLater(
      repository.getSpacesByHouseId('h1'),
      throwsA(isA<AppDatabaseException>()),
    );
  });

  test('una casa senza entità restituisce invece un elenco vuoto', () async {
    when(() => dao.getSpacesByHouse('h1')).thenAnswer((_) async => <Space>[]);
    expect(await repository.getSpacesByHouseId('h1'), isEmpty);
  });
}

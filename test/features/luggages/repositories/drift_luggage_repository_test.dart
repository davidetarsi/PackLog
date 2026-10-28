import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/daos/luggages_dao.dart';
import 'package:pack_log/core/database/exceptions/database_exceptions.dart';
import 'package:pack_log/core/database/services/database_service.dart';
import 'package:pack_log/features/luggages/repositories/drift_luggage_repository.dart';

class _Database extends Mock implements AppDatabase {}

class _Dao extends Mock implements LuggagesDao {}

void main() {
  late _Dao dao;
  late DriftLuggageRepository repository;
  setUp(() {
    dao = _Dao();
    repository = DriftLuggageRepository(
      dao,
      DatabaseService(_Database()),
      () => null,
    );
  });

  test('un errore leggendo la casa non diventa un elenco vuoto', () async {
    when(
      () => dao.getLuggagesByHouse('h1'),
    ).thenThrow(StateError('DB non disponibile'));
    await expectLater(
      repository.getLuggagesByHouseId('h1'),
      throwsA(isA<AppDatabaseException>()),
    );
  });

  test('una casa senza entità restituisce invece un elenco vuoto', () async {
    when(
      () => dao.getLuggagesByHouse('h1'),
    ).thenAnswer((_) async => <Luggage>[]);
    expect(await repository.getLuggagesByHouseId('h1'), isEmpty);
  });

  test('un errore nel selettore globale non diventa nessun bagaglio', () async {
    when(
      () => dao.getAllLuggages(),
    ).thenThrow(StateError('DB non disponibile'));
    await expectLater(
      repository.getAllLuggages(),
      throwsA(isA<AppDatabaseException>()),
    );
  });
}

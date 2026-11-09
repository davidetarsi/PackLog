import 'package:drift/drift.dart';

/// Coda locale delle modifiche dell'utente alla valigia proposta.
///
/// Non è sincronizzata come le altre tabelle: le righe aspettano di essere
/// inviate e poi si cancellano. Non c'è mai il nome scritto dall'utente: solo
/// la scheda (o tipo e livello di un posto) e il contesto del viaggio.
///
/// Si chiama `SuitcaseEditRow` per non coprire il modello `SuitcaseEdit`.
@DataClassName('SuitcaseEditRow')
class SuitcaseEdits extends Table {
  /// ID univoco dell'evento (UUID)
  TextColumn get id => text()();

  /// Il viaggio a cui appartiene la modifica (senza chiave esterna: l'evento
  /// sopravvive al viaggio cancellato).
  TextColumn get tripId => text()();

  /// SHA-256 di `<viaggio>:<oggetto>` (o `<viaggio>:slot:<posto>`).
  TextColumn get itemKey => text()();

  /// L'utente che ha fatto la modifica: l'invio lo manda al server, che
  /// rifiuta (RLS) le righe di un altro account.
  TextColumn get userId => text()();

  /// Quando l'utente ha fatto la modifica.
  DateTimeColumn get at => dateTime()();

  /// `SuitcaseEditAction.dbValue`
  TextColumn get action => text()();

  /// `SuitcaseEditOrigin.dbValue`
  TextColumn get origin => text()();

  IntColumn get copiesBefore => integer().nullable()();
  IntColumn get copiesAfter => integer().nullable()();

  /// Scheda dell'oggetto, JSON.
  TextColumn get cardJson => text().withDefault(const Constant('{}'))();

  /// Contesto del viaggio, JSON.
  TextColumn get contextJson => text().withDefault(const Constant('{}'))();

  TextColumn get generatorVersion => text().nullable()();

  /// `ConsentService.analyticsEnabled` nel momento dell'evento.
  BoolColumn get analysisAllowed => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

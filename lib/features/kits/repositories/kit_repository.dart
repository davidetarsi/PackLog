import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/errors/app_exception.dart';
import '../model/kit_model.dart';
import 'drift_kit_repository.dart';

part 'kit_repository.g.dart';

/// Massimo di kit per casa e di oggetti per kit (app e funzione).
const int kMaxKitsPerHouse = 50;
const int kMaxItemsPerKit = 50;

/// Lunghezza massima del nome di un kit (dopo il trim).
const int kMaxKitNameLength = 60;

/// Superato il limite di kit per casa o di oggetti per kit.
class KitLimitException extends AppException {
  const KitLimitException(this.limit);

  final int limit;

  @override
  String toString() => 'KitLimitException[$limit]';
}

@Riverpod(keepAlive: true)
KitRepository kitRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return DriftKitRepository(
    database.kitsDao,
    () => ref.read(currentUserIdProvider),
  );
}

/// Kit di una casa e delle loro righe.
abstract class KitRepository {
  Stream<List<KitModel>> watchKits(String houseId);

  /// Lancia [KitLimitException] se la casa ha già 50 kit e [ArgumentError] se
  /// il nome (tagliato) non ha da 1 a 60 caratteri.
  Future<KitModel> createKit({
    required String houseId,
    required String name,
    List<String> activities = const [],
    List<String> transports = const [],
  });

  /// Aggiorna nome, attività, mezzi e appreso; le righe non cambiano. Lancia
  /// `EntityNotFoundException` se il kit non esiste o è cancellato e
  /// [ArgumentError] se il nome non è valido.
  Future<void> updateKit(KitModel kit);
  Future<void> deleteKit(String id);

  /// Mette oggetti nel kit (id oggetto → copie); un oggetto già presente
  /// cambia solo le copie. Ignora gli oggetti non vivi o di un'altra casa.
  /// Lancia [KitLimitException] oltre 50 oggetti.
  Future<void> addItems(String kitId, Map<String, int> copiesByItemId);
  Future<void> removeItem(String kitId, String itemId);

  /// Un sì in valigia: somma 1 a ogni uso non già nel kit.
  Future<KitModel> recordYes(String kitId, List<String> uses);

  /// Il kit entra da solo per [use] (attività o mezzo).
  Future<void> learnUse(String kitId, String use);

  /// L'utente non vuole il collegamento: non si propone più.
  Future<void> refuseUse(String kitId, String use);
}

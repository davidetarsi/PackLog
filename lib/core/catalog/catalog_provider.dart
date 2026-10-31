import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog_store.dart';

/// La revisione di [CatalogStore]: cambia quando arriva un catalogo nuovo o una
/// lingua nuova. I widget con pillole ed etichette la osservano e si ricostruiscono.
final catalogRevisionProvider =
    NotifierProvider<CatalogRevisionNotifier, int>(
      CatalogRevisionNotifier.new,
    );

class CatalogRevisionNotifier extends Notifier<int> {
  @override
  int build() {
    void aggiorna() => state = CatalogStore.revision.value;
    CatalogStore.revision.addListener(aggiorna);
    ref.onDispose(() => CatalogStore.revision.removeListener(aggiorna));
    return CatalogStore.revision.value;
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/ds_button.dart';
import '../../../../shared/widgets/ds_empty_state.dart';
import '../../../../shared/widgets/ds_error_state.dart';
import '../../model/trip_model.dart';
import '../../providers/trip_provider.dart';

/// Cosa mostrare quando una schermata di modifica non ha (ancora) il viaggio.
///
/// Le due schermate di modifica copiano il viaggio in uno stato locale
/// modificabile: finché quella copia non esiste devono mostrare qualcosa, e i
/// casi sono tre, non uno. Prima era sempre uno spinner, che sui due casi
/// terminali — errore del provider, viaggio non trovato — girava all'infinito.
///
/// Restituisce `null` quando il viaggio c'è e la schermata vera può costruirsi.
Widget? tripEditPlaceholder({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required AsyncValue<List<TripModel>> tripsAsync,
  required bool isHydrated,
}) {
  if (isHydrated) return null;

  final body = switch (tripsAsync) {
    AsyncError(:final error) => DsErrorState(
      error: error,
      onRetry: () => ref.read(tripNotifierProvider.notifier).refresh(),
    ),
    AsyncData() => DsEmptyState(
      // Dato arrivato ma nessun viaggio con questo id: cancellato da un altro
      // dispositivo, o link vecchio. Riprovare non serve, tornare indietro sì.
      icon: Icons.luggage_outlined,
      title: 'common.not_found'.tr(),
      action: DsButton(
        label: 'common.back_to_list'.tr(),
        icon: Icons.arrow_back,
        variant: DsButtonVariant.secondary,
        onPressed: () => context.pop(),
      ),
    ),
    _ => const Center(child: CircularProgressIndicator()),
  };

  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: body,
  );
}

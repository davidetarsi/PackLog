import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../model/promo_redeem_result.dart';
import '../service/promo_code_service.dart';

part 'promo_code_provider.g.dart';

@Riverpod(keepAlive: true)
PromoCodeService promoCodeService(Ref ref) => PromoCodeService();

/// L'esito dell'ultimo codice attivato in automatico dopo il login.
///
/// `AuthNotifier` lo imposta, `MainShell` lo mostra in una snackbar e lo
/// azzera: chi attiva il codice non ha un `BuildContext`.
@Riverpod(keepAlive: true)
class PendingPromoOutcome extends _$PendingPromoOutcome {
  @override
  PromoRedeemResult? build() => null;

  void report(PromoRedeemResult result) => state = result;

  void clear() => state = null;
}

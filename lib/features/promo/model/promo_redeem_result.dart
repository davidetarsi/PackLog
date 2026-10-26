/// Esito dell'attivazione di un codice promo (RPC `redeem_promo_code`).
sealed class PromoRedeemResult {
  const PromoRedeemResult();
}

/// Codice attivato: [credits] usi AI in regalo fino a [expiresAt].
final class PromoRedeemed extends PromoRedeemResult {
  const PromoRedeemed({required this.credits, required this.expiresAt});

  final int credits;
  final DateTime expiresAt;
}

/// Codice rifiutato dal server, per un motivo che l'utente può capire.
final class PromoRejected extends PromoRedeemResult {
  const PromoRejected(this.reason);

  final PromoRejectReason reason;
}

/// La richiesta non è arrivata (rete, server): il codice si può riprovare.
final class PromoFailed extends PromoRedeemResult {
  const PromoFailed();
}

/// I codici d'errore della RPC, uno a uno.
enum PromoRejectReason {
  invalidCode,
  expired,
  exhausted,
  alreadyRedeemed,
  tooLate,
  tooManyAttempts;

  static PromoRejectReason fromCode(String? code) => switch (code) {
    'expired' => expired,
    'exhausted' => exhausted,
    'already_redeemed' => alreadyRedeemed,
    'too_late' => tooLate,
    'too_many_attempts' => tooManyAttempts,
    _ => invalidCode,
  };

  /// Chiave di traduzione del messaggio.
  String get messageKey => switch (this) {
    invalidCode => 'promo.error_invalid_code',
    expired => 'promo.error_expired',
    exhausted => 'promo.error_exhausted',
    alreadyRedeemed => 'promo.error_already_redeemed',
    tooLate => 'promo.error_too_late',
    tooManyAttempts => 'promo.error_too_many_attempts',
  };
}

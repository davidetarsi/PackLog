import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/features/profile/providers/gpt_usage_provider.dart';
import 'package:pack_log/features/promo/model/promo_redeem_result.dart';
import 'package:pack_log/features/promo/service/promo_code_service.dart';

void main() {
  group('PromoCodeService.parseResponse', () {
    test('codice attivato: crediti e scadenza', () {
      final result = PromoCodeService.parseResponse({
        'ok': true,
        'credits': 20,
        'expires_at': '2026-12-20T10:00:00+00:00',
      });
      expect(result, isA<PromoRedeemed>());
      final redeemed = result as PromoRedeemed;
      expect(redeemed.credits, 20);
      expect(redeemed.expiresAt.toUtc(), DateTime.utc(2026, 12, 20, 10));
    });

    test('ogni errore della RPC ha il suo motivo', () {
      const codes = {
        'invalid_code': PromoRejectReason.invalidCode,
        'expired': PromoRejectReason.expired,
        'exhausted': PromoRejectReason.exhausted,
        'already_redeemed': PromoRejectReason.alreadyRedeemed,
        'too_late': PromoRejectReason.tooLate,
        'too_many_attempts': PromoRejectReason.tooManyAttempts,
        'qualcosa_di_nuovo': PromoRejectReason.invalidCode,
      };
      codes.forEach((code, reason) {
        final result = PromoCodeService.parseResponse({
          'ok': false,
          'error': code,
        });
        expect((result as PromoRejected).reason, reason, reason: code);
      });
    });

    test('una risposta senza forma è un fallimento da riprovare', () {
      expect(PromoCodeService.parseResponse(null), isA<PromoFailed>());
      expect(
        PromoCodeService.parseResponse({'ok': true, 'credits': 'x'}),
        isA<PromoFailed>(),
      );
    });
  });

  test('il codice in attesa si salva normalizzato e si cancella', () async {
    SharedPreferences.setMockInitialValues({});
    final service = PromoCodeService(prefs: SharedPreferences.getInstance());
    expect(await service.redeemPending(), isNull);
    await service.savePending('  insta ');
    expect(await service.pendingCode(), 'INSTA');
    await service.clearPending();
    expect(await service.pendingCode(), isNull);
  });

  group('GptUsageModel', () {
    test('dalla RPC get_ai_usage', () {
      final usage = GptUsageModel.fromJson({
        'monthly_used': 30,
        'monthly_cap': 30,
        'resets_at': '2026-11-20T10:00:00+00:00',
        'bonus_available': 5,
        'bonus_expires_at': '2026-12-20T10:00:00+00:00',
        'promo_code': 'INSTA',
        'can_redeem_promo': false,
      });
      expect(usage.usageCount, 30);
      expect(usage.resetsAt!.toUtc(), DateTime.utc(2026, 11, 20, 10));
      expect(usage.bonusAvailable, 5);
      // La quota del mese è finita ma restano i crediti extra.
      expect(usage.isExhausted, isFalse);
    });

    test('esaurito solo senza quota e senza crediti extra', () {
      final usage = GptUsageModel.fromJson({
        'monthly_used': 30,
        'monthly_cap': 30,
        'resets_at': null,
        'bonus_available': 0,
        'bonus_expires_at': null,
        'can_redeem_promo': true,
      });
      expect(usage.isExhausted, isTrue);
      expect(usage.resetsAt, isNull);
      expect(usage.canRedeemPromo, isTrue);
    });
  });
}

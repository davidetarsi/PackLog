import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_provider.dart';

part 'gpt_usage_provider.g.dart';

/// Gli usi AI dell'utente (foto e valigia): la quota del mese più i crediti
/// extra dei codici promo, dalla RPC `get_ai_usage`.
class GptUsageModel {
  const GptUsageModel({
    required this.usageCount,
    required this.usageCap,
    this.resetsAt,
    this.bonusAvailable = 0,
    this.bonusExpiresAt,
    this.canRedeemPromo = false,
  });

  /// Usi della quota di questo mese.
  final int usageCount;
  final int usageCap;

  /// Quando la quota torna piena; null se questo mese non è ancora stata usata.
  final DateTime? resetsAt;

  /// Crediti extra ancora da usare, e la scadenza del primo che scade.
  final int bonusAvailable;
  final DateTime? bonusExpiresAt;

  /// Se l'utente può ancora inserire un codice promo.
  final bool canRedeemPromo;

  double get progress =>
      usageCap > 0 ? (usageCount / usageCap).clamp(0.0, 1.0) : 0.0;

  /// Niente più quota del mese né crediti extra.
  bool get isExhausted => usageCount >= usageCap && bonusAvailable <= 0;

  factory GptUsageModel.fromJson(Map<String, dynamic> json) => GptUsageModel(
    usageCount: (json['monthly_used'] as num?)?.toInt() ?? 0,
    usageCap: (json['monthly_cap'] as num?)?.toInt() ?? 30,
    resetsAt: _date(json['resets_at']),
    bonusAvailable: (json['bonus_available'] as num?)?.toInt() ?? 0,
    bonusExpiresAt: _date(json['bonus_expires_at']),
    canRedeemPromo: json['can_redeem_promo'] == true,
  );

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}

@Riverpod(keepAlive: true)
Future<GptUsageModel> gptUsage(Ref ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw Exception('Not authenticated');

  final data = await Supabase.instance.client.rpc('get_ai_usage');
  return GptUsageModel.fromJson(Map<String, dynamic>.from(data as Map));
}

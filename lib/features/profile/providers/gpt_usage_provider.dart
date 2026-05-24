import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_provider.dart';

part 'gpt_usage_provider.g.dart';

class GptUsageModel {
  const GptUsageModel({required this.monthlyCount, required this.monthlyCap});

  final int monthlyCount;
  final int monthlyCap;

  double get progress =>
      monthlyCap > 0 ? (monthlyCount / monthlyCap).clamp(0.0, 1.0) : 0.0;
}

@Riverpod(keepAlive: true)
Future<GptUsageModel> gptUsage(Ref ref) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) throw Exception('Not authenticated');

  final data = await Supabase.instance.client
      .from('users')
      .select('gpt_monthly_count, gpt_monthly_cap')
      .eq('id', userId)
      .single();

  return GptUsageModel(
    monthlyCount: (data['gpt_monthly_count'] as int?) ?? 0,
    monthlyCap: (data['gpt_monthly_cap'] as int?) ?? 0,
  );
}

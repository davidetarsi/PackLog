import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_provider.dart';

part 'gpt_usage_provider.g.dart';

class GptUsageModel {
  const GptUsageModel({required this.usageCount, required this.usageCap});

  final int usageCount;
  final int usageCap;

  double get progress =>
      usageCap > 0 ? (usageCount / usageCap).clamp(0.0, 1.0) : 0.0;

  bool get isExhausted => usageCount >= usageCap;
}

@Riverpod(keepAlive: true)
Future<GptUsageModel> gptUsage(Ref ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw Exception('Not authenticated');

  final data = await Supabase.instance.client
      .from('users')
      .select('gpt_usage_count, gpt_usage_cap')
      .eq('id', userId)
      .single();

  return GptUsageModel(
    usageCount: (data['gpt_usage_count'] as int?) ?? 0,
    usageCap: (data['gpt_usage_cap'] as int?) ?? 30,
  );
}

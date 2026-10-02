import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/monitoring/monitoring_service.dart';
import '../../../shared/config/app_config.dart';
import '../service/ai_clothing_analyzer_service.dart';

part 'ai_clothing_analyzer_service_provider.g.dart';

@Riverpod(keepAlive: true)
AiClothingAnalyzerService aiClothingAnalyzerService(Ref ref) {
  return AiClothingAnalyzerService(
    proxyUrl: '${AppConfig.supabaseUrl}/functions/v1/openai-proxy',
    anonKey: AppConfig.supabaseAnonKey,
    analytics: ref.watch(coreAnalyticsServiceProvider),
    monitoring: ref.watch(monitoringServiceProvider),
  );
}

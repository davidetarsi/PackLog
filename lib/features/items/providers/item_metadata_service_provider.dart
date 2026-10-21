import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/config/app_config.dart';
import '../services/item_metadata_service.dart';

part 'item_metadata_service_provider.g.dart';

@Riverpod(keepAlive: true)
ItemMetadataService itemMetadataService(Ref ref) => ItemMetadataService(
  url: '${AppConfig.supabaseUrl}/functions/v1/item-metadata',
  anonKey: AppConfig.supabaseAnonKey,
);

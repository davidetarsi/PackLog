import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../repositories/item_repository.dart';

part 'user_colors_provider.g.dart';

/// Colori di base già usati dai capi dell'utente. Si ricalcola quando
/// [ItemNotifier] salva o modifica un oggetto (vedi `ref.invalidate`).
@riverpod
Future<List<String>> userColors(Ref ref) =>
    ref.read(itemRepositoryProvider).getUsedColors();

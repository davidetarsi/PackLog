import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';

part 'last_export_path_provider.g.dart';

const String _lastExportPathKey = 'last_export_path';

/// Provider che gestisce il path dell'ultimo export di database.
/// 
/// Mostra:
/// - Il path reale dell'ultimo export salvato (se disponibile)
/// - Il path previsto per il prossimo export (se non c'è ancora un export)
@riverpod
class LastExportPath extends _$LastExportPath {
  @override
  Future<String> build() async {
    return await _loadLastExportPath();
  }

  /// Carica l'ultimo path salvato o genera il path previsto
  Future<String> _loadLastExportPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString(_lastExportPathKey);
      
      if (savedPath != null) {
        return savedPath;
      }
      
      // Path previsto se non c'è ancora un export
      return await _getDefaultExportPath();
    } catch (e) {
      return await _getDefaultExportPath();
    }
  }

  /// Genera il path previsto per il prossimo export
  Future<String> _getDefaultExportPath() async {
    final downloadsDir = await getDownloadsDirectory();
    final dirPath = downloadsDir?.path ?? 'Downloads';
    
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    final fileName = '${AppConstants.backupFilePrefix}-$day$month$year${AppConstants.databaseFileExtension}';
    
    return '$dirPath/$fileName';
  }

  /// Aggiorna il path con quello dell'ultimo export effettuato
  Future<void> updateLastExportPath(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastExportPathKey, path);
      state = AsyncValue.data(path);
    } catch (e) {
      // Se il salvataggio fallisce, aggiorna comunque lo state in memoria
      state = AsyncValue.data(path);
    }
  }
}

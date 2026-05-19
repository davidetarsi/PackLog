import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TombstoneConfigService {
  final SupabaseClient _supabase;

  TombstoneConfigService(this._supabase);

  static const _cacheKey = 'tombstone_retention_days';
  static const _defaultRetentionDays = 15;

  int? _inMemoryCache;

  Future<int> getRetentionDays() async {
    if (_inMemoryCache != null) return _inMemoryCache!;

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getInt(_cacheKey);

    if (cached != null) {
      _inMemoryCache = cached;
      _refreshFromRemote(prefs);
      return cached;
    }

    return _fetchAndCache(prefs);
  }

  Future<int> _fetchAndCache(SharedPreferences prefs) async {
    try {
      final response = await _supabase
          .from('app_config')
          .select('value')
          .eq('key', 'tombstone_retention_days')
          .maybeSingle();

      final days = (response != null)
          ? int.tryParse(response['value'] as String) ?? _defaultRetentionDays
          : _defaultRetentionDays;

      await prefs.setInt(_cacheKey, days);
      _inMemoryCache = days;
      return days;
    } catch (_) {
      return _defaultRetentionDays;
    }
  }

  void _refreshFromRemote(SharedPreferences prefs) {
    _fetchAndCache(prefs);
  }
}

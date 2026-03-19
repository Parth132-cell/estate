import 'package:shared_preferences/shared_preferences.dart';

abstract class FavoritesCache {
  Future<Set<String>> read(String userId);
  Future<void> write(String userId, Set<String> favorites);
}

class SharedPrefsFavoritesCache implements FavoritesCache {
  static const _prefix = 'favorites_cache_v1_';

  @override
  Future<Set<String>> read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList('$_prefix$userId') ?? const [];
    return values.toSet();
  }

  @override
  Future<void> write(String userId, Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_prefix$userId', favorites.toList()..sort());
  }
}

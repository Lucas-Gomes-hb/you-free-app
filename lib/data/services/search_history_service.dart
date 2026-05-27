import 'package:shared_preferences/shared_preferences.dart';

/// Persists a list of recent search queries for offline history/autocomplete.
class SearchHistoryService {
  static const _key = 'yf_search_history';
  static const _maxItems = 30;

  /// Inserts [query] at the top of history, deduplicating (case-insensitive).
  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final items = List<String>.from(prefs.getStringList(_key) ?? []);
    items.removeWhere((s) => s.toLowerCase() == q.toLowerCase());
    items.insert(0, q);
    await prefs.setStringList(_key, items.take(_maxItems).toList());
  }

  /// Returns up to 5 history entries that contain [prefix] (case-insensitive).
  /// If [prefix] is empty, returns the 5 most recent entries.
  Future<List<String>> getMatching(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_key) ?? [];
    final q = prefix.trim().toLowerCase();
    if (q.isEmpty) return items.take(5).toList();
    return items.where((s) => s.toLowerCase().contains(q)).take(5).toList();
  }

  Future<void> remove(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final items = List<String>.from(prefs.getStringList(_key) ?? []);
    items.removeWhere((s) => s == query);
    await prefs.setStringList(_key, items);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

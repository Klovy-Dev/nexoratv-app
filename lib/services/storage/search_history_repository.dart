import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryRepository {
  static const _key = 'search_history_v1';
  static const _max = 12;

  Future<List<String>> load() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_key) ?? const [];
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    final p = await SharedPreferences.getInstance();
    final list = (p.getStringList(_key) ?? [])
      ..removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    list.insert(0, q);
    if (list.length > _max) list.removeRange(_max, list.length);
    await p.setStringList(_key, list);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}

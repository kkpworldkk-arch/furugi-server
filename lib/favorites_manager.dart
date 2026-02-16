import 'package:shared_preferences/shared_preferences.dart';

class FavoritesManager {
  static const String _key = 'favIds';
  static Future<void> toggle(int id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> ids = prefs.getStringList(_key) ?? [];
    String sId = id.toString();
    if (ids.contains(sId)) ids.remove(sId); else ids.add(sId);
    await prefs.setStringList(_key, ids);
  }
  static Future<bool> isFav(int id) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).contains(id.toString());
  }
  static Future<List<int>> getIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).map((e) => int.parse(e)).toList();
  }
}
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';

class HistoryService {
  static const _key = 'recently_played';
  static const _maxItems = 50;

  Future<void> add(VideoModel video) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final items = raw.map((s) => VideoModel.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
    items.removeWhere((v) => v.id == video.id);
    items.insert(0, video);
    final trimmed = items.take(_maxItems).toList();
    await prefs.setStringList(_key, trimmed.map((v) => jsonEncode(v.toJson())).toList());
  }

  Future<List<VideoModel>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) => VideoModel.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }
}

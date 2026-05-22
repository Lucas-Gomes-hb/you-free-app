import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static const _key = 'video_progress_v1';
  static const _minSaveSeconds = 15;
  static const _minRemainingSeconds = 15;

  Future<void> save(String videoId, int positionSeconds, int durationSeconds) async {
    if (positionSeconds < _minSaveSeconds) {
      await _remove(videoId);
      return;
    }
    if (durationSeconds > 0 && durationSeconds - positionSeconds < _minRemainingSeconds) {
      await _remove(videoId);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final map = _getMap(prefs);
    map[videoId] = positionSeconds;
    if (map.length > 200) map.remove(map.keys.first);
    await prefs.setString(_key, jsonEncode(map));
  }

  Future<int?> get(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    return _getMap(prefs)[videoId] as int?;
  }

  Future<void> _remove(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _getMap(prefs);
    if (map.remove(videoId) != null) {
      await prefs.setString(_key, jsonEncode(map));
    }
  }

  Map<String, dynamic> _getMap(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }
}

import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class SettingsService {
  static const String _apiUrlKey = 'api_url';
  static const String _autoDownloadLimitKey = 'auto_download_limit';
  static const String _contentModeKey = 'content_mode';
  static const String defaultUrl = 'http://localhost:8000';
  static const int defaultAutoDownloadLimit = 250;
  static const ContentMode defaultContentMode = ContentMode.api;

  String _apiUrl = defaultUrl;
  int _autoDownloadLimit = defaultAutoDownloadLimit;
  ContentMode _contentMode = defaultContentMode;

  String get apiUrl => _apiUrl;
  int get autoDownloadLimit => _autoDownloadLimit;
  ContentMode get contentMode => _contentMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _apiUrl = prefs.getString(_apiUrlKey) ?? defaultUrl;
    _autoDownloadLimit =
        prefs.getInt(_autoDownloadLimitKey) ?? defaultAutoDownloadLimit;
    _contentMode = ContentMode.values.firstWhere(
      (m) => m.name == prefs.getString(_contentModeKey),
      orElse: () => defaultContentMode,
    );
  }

  Future<void> setApiUrl(String url) async {
    _apiUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlKey, url);
  }

  Future<void> setAutoDownloadLimit(int limit) async {
    _autoDownloadLimit = limit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoDownloadLimitKey, limit);
  }

  Future<void> setContentMode(ContentMode mode) async {
    _contentMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contentModeKey, mode.name);
  }
}

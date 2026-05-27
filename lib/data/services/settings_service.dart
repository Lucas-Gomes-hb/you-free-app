import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _apiUrlKey = 'api_url';
  static const String _autoDownloadLimitKey = 'auto_download_limit';
  static const String defaultUrl = 'http://100.125.151.88:8000';
  static const int defaultAutoDownloadLimit = 250;

  String _apiUrl = defaultUrl;
  int _autoDownloadLimit = defaultAutoDownloadLimit;

  String get apiUrl => _apiUrl;
  int get autoDownloadLimit => _autoDownloadLimit;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _apiUrl = prefs.getString(_apiUrlKey) ?? defaultUrl;
    _autoDownloadLimit =
        prefs.getInt(_autoDownloadLimitKey) ?? defaultAutoDownloadLimit;
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
}

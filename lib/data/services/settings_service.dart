import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _apiUrlKey = 'api_url';
  static const String defaultUrl = 'http://100.125.151.88:8000';

  String _apiUrl = defaultUrl;
  String get apiUrl => _apiUrl;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _apiUrl = prefs.getString(_apiUrlKey) ?? defaultUrl;
  }

  Future<void> setApiUrl(String url) async {
    _apiUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlKey, url);
  }
}

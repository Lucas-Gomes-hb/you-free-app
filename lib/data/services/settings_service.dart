import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../../app/app_mode.dart';

class SettingsService extends ChangeNotifier {
  SettingsService();

  static const String _apiUrlKey = 'api_url';
  static const String _autoDownloadLimitKey = 'auto_download_limit';
  static const String _contentModeKey = 'content_mode';
  static const String _appModeKey = 'app_mode';
  static const String defaultUrl = 'http://localhost:8000';
  static const int defaultAutoDownloadLimit = 250;
  static const ContentMode defaultContentMode = ContentMode.api;
  static const AppMode defaultAppMode = AppMode.music;

  String _apiUrl = defaultUrl;
  int _autoDownloadLimit = defaultAutoDownloadLimit;
  ContentMode _contentMode = defaultContentMode;
  AppMode _appMode = defaultAppMode;

  String get apiUrl => _apiUrl;
  int get autoDownloadLimit => _autoDownloadLimit;
  ContentMode get contentMode => _contentMode;

  /// Which experience the app is currently running as.
  AppMode get appMode => _appMode;

  /// The resolved per-mode behaviour, for widgets that need more than the flag.
  ModeProfile get profile => ModeProfile.of(_appMode);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _apiUrl = prefs.getString(_apiUrlKey) ?? defaultUrl;
    _autoDownloadLimit =
        prefs.getInt(_autoDownloadLimitKey) ?? defaultAutoDownloadLimit;
    _contentMode = ContentMode.values.firstWhere(
      (m) => m.name == prefs.getString(_contentModeKey),
      orElse: () => defaultContentMode,
    );
    _appMode = AppMode.values.firstWhere(
      (m) => m.name == prefs.getString(_appModeKey),
      orElse: () => defaultAppMode,
    );
    notifyListeners();
  }

  Future<void> setApiUrl(String url) async {
    _apiUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlKey, url);
    notifyListeners();
  }

  Future<void> setAutoDownloadLimit(int limit) async {
    _autoDownloadLimit = limit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoDownloadLimitKey, limit);
    notifyListeners();
  }

  Future<void> setContentMode(ContentMode mode) async {
    _contentMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contentModeKey, mode.name);
    notifyListeners();
  }

  /// Switching modes is a structural change, so listeners are always notified —
  /// the navigation shell rebuilds against the new profile.
  Future<void> setAppMode(AppMode mode) async {
    if (_appMode == mode) return;
    _appMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appModeKey, mode.name);
    notifyListeners();
  }
}

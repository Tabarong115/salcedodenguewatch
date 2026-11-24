import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  Locale _currentLocale = const Locale('en');
  bool _isDarkMode = false;
  bool _isLoadingData = false;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _settings;

  Locale get currentLocale => _currentLocale;
  bool get isDarkMode => _isDarkMode;
  bool get isLoadingData => _isLoadingData;
  Map<String, dynamic>? get dashboardData => _dashboardData;
  Map<String, dynamic>? get settings => _settings;

  AppState() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final languageCode = prefs.getString('language_code') ?? 'en';
    _currentLocale = Locale(languageCode);

    _isDarkMode = prefs.getBool('dark_mode') ?? false;

    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    _currentLocale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoadingData = loading;
    notifyListeners();
  }

  void setDashboardData(Map<String, dynamic> data) {
    _dashboardData = data;
    notifyListeners();
  }

  void setSettings(Map<String, dynamic> settingsData) {
    _settings = settingsData;
    notifyListeners();
  }

  String getSetting(String key, String defaultValue) {
    return _settings?[key] ?? defaultValue;
  }
}

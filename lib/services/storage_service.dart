import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';

class StorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- AUTH ---
  static const String _authKey = 'auth_token';
  static Future<void> saveAuthToken(String token) async {
    await _prefs.setString(_authKey, token);
  }
  static String? loadAuthToken() {
    return _prefs.getString(_authKey);
  }
  static Future<void> clearAuth() async {
    await _prefs.remove(_authKey);
  }

  // --- EXISTING DATA ---
  static const String _notesKey = 'notes_data';
  static Future<void> saveNotes(List<Note> notes) async {
    final String data = jsonEncode(notes.map((n) => n.toJson()).toList());
    await _prefs.setString(_notesKey, data);
  }
  static List<Note> loadNotes() {
    final String? data = _prefs.getString(_notesKey);
    if (data == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => Note.fromJson(json)).toList();
    } catch (e) { return []; }
  }

  static const String _foldersKey = 'folders_data';
  static Future<void> saveFolders(List<String> folders) async {
    await _prefs.setStringList(_foldersKey, folders);
  }
  static List<String> loadFolders() {
    return _prefs.getStringList(_foldersKey) ?? [];
  }

  static const String _userKey = 'user_data';
  static Future<void> saveUser(User user) async {
    final String data = jsonEncode(user.toJson());
    await _prefs.setString(_userKey, data);
  }
  static User? loadUser() {
    final String? data = _prefs.getString(_userKey);
    if (data == null) return null;
    try { return User.fromJson(jsonDecode(data)); } catch (e) { return null; }
  }

  static const String _tasksKey = 'tasks_data';
  static Future<void> saveTasks(List<Task> tasks) async {
    final String data = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await _prefs.setString(_tasksKey, data);
  }
  static List<Task> loadTasks() {
    final String? data = _prefs.getString(_tasksKey);
    if (data == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => Task.fromJson(json)).toList();
    } catch (e) { return []; }
  }

  static const String _moneyKey = 'money_data';
  static Future<void> saveTransactions(List<Map<String, dynamic>> txs) async {
    final String data = jsonEncode(txs);
    await _prefs.setString(_moneyKey, data);
  }
  static List<Map<String, dynamic>> loadTransactions() {
    final String? data = _prefs.getString(_moneyKey);
    if (data == null) return [];
    try { return List<Map<String, dynamic>>.from(jsonDecode(data)); } catch (e) { return []; }
  }

  static const String _moneySettingsKey = 'money_settings';
  static Future<void> saveMoneySettings(Map<String, dynamic> settings) async {
    final String data = jsonEncode(settings);
    await _prefs.setString(_moneySettingsKey, data);
  }
  static Map<String, dynamic> loadMoneySettings() {
    final String? data = _prefs.getString(_moneySettingsKey);
    if (data == null) return {};
    try { return jsonDecode(data); } catch (e) { return {}; }
  }

  static const String _moneyInitKey = 'money_has_initialized';
  static Future<void> setMoneyInitialized(bool val) async {
    await _prefs.setBool(_moneyInitKey, val);
  }
  static bool hasMoneyInitialized() {
    return _prefs.getBool(_moneyInitKey) ?? false;
  }

  // --- CURRENCY ---
  static const String _selectedCurrencyKey = 'selected_currency';
  static Future<void> saveSelectedCurrency(String currency) async {
    await _prefs.setString(_selectedCurrencyKey, currency.toUpperCase());
  }
  static String loadSelectedCurrency() {
    return _prefs.getString(_selectedCurrencyKey) ?? 'USD';
  }

  // --- ROAM & PULSE ---
  static const String _roamKey = 'roam_trips';
  static Future<void> saveTrips(List<Map<String, dynamic>> trips) async {
    await _prefs.setString(_roamKey, jsonEncode(trips));
  }
  static List<Map<String, dynamic>> loadTrips() {
    final String? data = _prefs.getString(_roamKey);
    if (data == null) return [];
    try { return List<Map<String, dynamic>>.from(jsonDecode(data)); } catch (e) { return []; }
  }

  static const String _pulseKey = 'pulse_data';
  static Future<void> saveHealthData(Map<String, dynamic> data) async {
    await _prefs.setString(_pulseKey, jsonEncode(data));
  }
  static Map<String, dynamic> loadHealthData() {
    final String? data = _prefs.getString(_pulseKey);
    if (data == null) return {};
    try { return jsonDecode(data); } catch (e) { return {}; }
  }

  static const String _chatKey = 'chat_history';

  static Future<void> saveChatHistory(List<Map<String, dynamic>> messages) async {
    final String data = jsonEncode(messages);
    await _prefs.setString(_chatKey, data);
  }

  static List<Map<String, dynamic>> loadChatHistory() {
    final String? data = _prefs.getString(_chatKey);
    if (data == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    } catch (e) {
      return [];
    }
  }

  // --- FOLDER WIDGETS ---
  static const String _folderWidgetsKey = 'folder_widgets_config';
  static Future<void> saveFolderWidgets(Map<String, List<String>> config) async {
    final String data = jsonEncode(config);
    await _prefs.setString(_folderWidgetsKey, data);
  }
  static Map<String, List<String>> loadFolderWidgets() {
    final String? data = _prefs.getString(_folderWidgetsKey);
    if (data == null) return {};
    try {
      Map<String, dynamic> raw = jsonDecode(data);
      return raw.map((k, v) => MapEntry(k, List<String>.from(v)));
    } catch (e) {
      return {};
    }
  }

  // --- DASHBOARD FILTERS ---
  static const String _dashboardFiltersKey = 'dashboard_filters';
  static Future<void> saveDashboardFilters(List<String> filters) async {
    await _prefs.setStringList(_dashboardFiltersKey, filters);
  }
  static List<String> loadDashboardFilters() {
    return _prefs.getStringList(_dashboardFiltersKey) ?? ['All'];
  }

  // --- DASHBOARD WIDGET ORDER ---
  static const String _dashboardOrderKey = 'dashboard_widget_order';
  static Future<void> saveDashboardWidgetOrder(List<String> order) async {
    await _prefs.setStringList(_dashboardOrderKey, order);
  }
  static List<String> loadDashboardWidgetOrder() {
    return _prefs.getStringList(_dashboardOrderKey) ?? [];
  }

  // --- GLASS OPACITY & FONT ---
  static const String _glassOpacityKey = 'glass_opacity_pref';
  static Future<void> saveGlassOpacity(double opacity) async {
    await _prefs.setDouble(_glassOpacityKey, opacity);
  }
  static double loadGlassOpacity() {
    return _prefs.getDouble(_glassOpacityKey) ?? 0.15;
  }

  static const String _fontFamilyKey = 'font_family_pref';
  static Future<void> saveFontFamily(String font) async {
    await _prefs.setString(_fontFamilyKey, font);
  }
  static String loadFontFamily() {
    return _prefs.getString(_fontFamilyKey) ?? 'Default';
  }

  // --- SAVINGS GOALS ---
  static const String _savingsGoalsKey = 'savings_goals_data';
  static Future<void> saveSavingsGoals(List<Map<String, dynamic>> goals) async {
    await _prefs.setString(_savingsGoalsKey, jsonEncode(goals));
  }
  static List<Map<String, dynamic>> loadSavingsGoals() {
    final String? data = _prefs.getString(_savingsGoalsKey);
    if (data == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    } catch (e) {
      return [];
    }
  }

  // --- SLEEP & ENERGY LOGS ---
  static const String _sleepLogsKey = 'sleep_energy_logs';
  static Future<void> saveSleepEnergyLogs(List<Map<String, dynamic>> logs) async {
    await _prefs.setString(_sleepLogsKey, jsonEncode(logs));
  }
  static List<Map<String, dynamic>> loadSleepEnergyLogs() {
    final String? data = _prefs.getString(_sleepLogsKey);
    if (data == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    } catch (e) {
      return [];
    }
  }

  // --- RESET / DELETE ALL ---
  static Future<void> clearAllData() async {
    await _prefs.clear();
  }
}
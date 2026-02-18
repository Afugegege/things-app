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
}
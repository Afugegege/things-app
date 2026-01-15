import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; 
import '../models/user_model.dart';
import '../services/storage_service.dart';

class UserProvider extends ChangeNotifier {
  User _user = User(
    id: 'user_001',
    name: 'Traveler',
    email: 'traveler@lifeos.app',
    aiMemory: ["I love pizza", "My goal is to be organized"], 
    preferences: {
      'isDarkMode': true, // Default to Dark Mode
      'notifications': true,
      'sounds': true,
      'bio_auth': false,
    },
    isPro: true,
  );

  // ... [Keep existing Dock/App logic] ...
  List<String> _dockItems = ['notes', 'tasks', 'ai', 'calendar', 'profile'];
  
  final Map<String, dynamic> _availableApps = {
    'notes': {'label': 'Brain', 'icon': CupertinoIcons.doc_text_fill},
    'tasks': {'label': 'Focus', 'icon': CupertinoIcons.checkmark_alt_circle_fill},
    'ai': {'label': 'AI', 'icon': CupertinoIcons.sparkles},
    'calendar': {'label': 'Plan', 'icon': CupertinoIcons.calendar},
    'profile': {'label': 'You', 'icon': CupertinoIcons.person_fill},
    'wallet': {'label': 'Wallet', 'icon': CupertinoIcons.money_dollar},
    'roam': {'label': 'Roam', 'icon': CupertinoIcons.map},
    'pulse': {'label': 'Pulse', 'icon': CupertinoIcons.heart},
  };

  final Map<String, bool> _appVisibility = {
    'Wallet': true, 'Roam': false, 'Focus': true, 'Brain': true, 'Pulse': false,
  };
  final Map<String, bool> _folderVisibility = {};

  UserProvider() {
    _loadUser();
  }

  User get user => _user;
  List<String> get dockItems => _dockItems;
  Map<String, dynamic> get availableApps => _availableApps;
  Map<String, bool> get appVisibility => _appVisibility;

  // [NEW] Theme Getter
  bool get isDarkMode => _user.preferences['isDarkMode'] ?? true;
  // [DEPRECATED] kept for compatibility if needed, but redirects to bool
  String get currentTheme => isDarkMode ? 'Dark' : 'Light';

  // [NEW] Theme Toggle Action
  void toggleTheme(bool isDark) {
    final newPrefs = Map<String, dynamic>.from(_user.preferences);
    newPrefs['isDarkMode'] = isDark;
    updatePreferences(newPrefs);
  }

  // ... [Keep existing Actions: reorderDock, addToDock, updateName, etc.] ...
  void reorderDock(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _dockItems.removeAt(oldIndex);
    _dockItems.insert(newIndex, item);
    notifyListeners();
  }

  void addToDock(String appId) {
    if (!_dockItems.contains(appId)) {
      if (_dockItems.length >= 5) _dockItems.removeLast();
      _dockItems.add(appId);
      notifyListeners();
    }
  }

  void removeFromDock(String appId) {
    if (_dockItems.length > 2) {
      _dockItems.remove(appId);
      notifyListeners();
    }
  }

  void updateName(String newName) {
    _user = _user.copyWith(name: newName);
    _save();
  }

  void updatePreferences(Map<String, dynamic> newPrefs) {
    _user = _user.copyWith(preferences: newPrefs);
    _save();
  }

  void addMemory(String fact) {
    final updatedMemories = List<String>.from(_user.aiMemory)..add(fact);
    _user = _user.copyWith(aiMemory: updatedMemories);
    _save();
  }

  void removeMemory(String fact) {
    final updatedMemories = List<String>.from(_user.aiMemory)..remove(fact);
    _user = _user.copyWith(aiMemory: updatedMemories);
    _save();
  }

  void toggleAppVisibility(String appName) {
    if (_appVisibility.containsKey(appName)) {
      _appVisibility[appName] = !(_appVisibility[appName] ?? false);
      notifyListeners();
    }
  }

  bool isFolderVisible(String folderName) {
    if (!_folderVisibility.containsKey(folderName)) {
      _folderVisibility[folderName] = true;
    }
    return _folderVisibility[folderName]!;
  }

  void toggleFolderVisibility(String folderName) {
    _folderVisibility[folderName] = !isFolderVisible(folderName);
    notifyListeners();
  }

  void _loadUser() {
    final savedUser = StorageService.loadUser();
    if (savedUser != null) {
      _user = savedUser;
      notifyListeners();
    }
  }

  void _save() {
    StorageService.saveUser(_user);
    notifyListeners();
  }

  int get currentStreak => 0; 
}
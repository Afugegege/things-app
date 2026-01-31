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
      'isDarkMode': true,
      'accentColor': 0xFFFFFFFF, 
      'notifications': true,
    },
    isPro: true,
    dockItems: ['dashboard', 'notes', 'tasks', 'ai', 'profile'],
  );

  // --- NAVIGATION STATE (CRITICAL FIX) ---
  // This allows the Drawer and Dock to switch screens without pushing new routes
  String _currentView = 'dashboard'; 
  String get currentView => _currentView;

  void changeView(String viewId) {
    _currentView = viewId;
    notifyListeners();
  }

  // --- DOCK DATA ---
  // List<String> _dockItems = ['notes', 'tasks', 'ai', 'calendar', 'profile']; // REMOVED: Managed by User model now
  final Map<String, dynamic> _availableApps = {
    'dashboard': {'label': 'Home', 'icon': CupertinoIcons.square_grid_2x2_fill}, 
    'notes': {'label': 'Brain', 'icon': CupertinoIcons.doc_text_fill},
    'tasks': {'label': 'Focus', 'icon': CupertinoIcons.checkmark_alt_circle_fill},
    'ai': {'label': 'AI', 'icon': CupertinoIcons.sparkles},
    'calendar': {'label': 'Plan', 'icon': CupertinoIcons.calendar},
    'profile': {'label': 'You', 'icon': CupertinoIcons.person_fill},
    'wallet': {'label': 'Wallet', 'icon': CupertinoIcons.money_dollar},
    'roam': {'label': 'Roam', 'icon': CupertinoIcons.map},
    'pulse': {'label': 'Pulse', 'icon': CupertinoIcons.heart},
    'flashcards': {'label': 'Flashcards', 'icon': CupertinoIcons.bolt_horizontal_circle_fill},
    'bucket': {'label': 'Bucket List', 'icon': CupertinoIcons.star_circle_fill},
  };
  
  final Map<String, bool> _folderVisibility = {};

  UserProvider() {
    _loadUser();
  }

  // --- GETTERS ---
  User get user => _user;
  List<String> get dockItems => _user.dockItems;
  Map<String, dynamic> get availableApps => _availableApps;
  
  Map<String, bool> get appVisibility {
    final Map<String, dynamic> stored = _user.preferences['appVisibility'] ?? {};
    // Merge with defaults to ensure new keys exist
    return {
      'Wallet': stored['Wallet'] ?? true,
      'Roam': stored['Roam'] ?? false, 
      'Focus': stored['Focus'] ?? true,
      'Brain': stored['Brain'] ?? true,
      'Flashcards': stored['Flashcards'] ?? true, // Default to true
      'Bucket': stored['Bucket'] ?? true,         // Default to true
      'Events': stored['Events'] ?? true,
    };
  }

  // Theme & Streak Getters (RESTORED)
  bool get isDarkMode => _user.preferences['isDarkMode'] ?? true;
  Color get accentColor {
    int? colorVal = _user.preferences['accentColor'];
    return colorVal != null ? Color(colorVal) : Colors.blueAccent;
  }
  int get currentStreak => 5; 

  // --- ACTIONS ---

  void toggleTheme(bool isDark) {
    final newPrefs = Map<String, dynamic>.from(_user.preferences);
    newPrefs['isDarkMode'] = isDark;
    _user = _user.copyWith(preferences: newPrefs);
    _save();
  }

  void updateAccentColor(Color color) {
    final newPrefs = Map<String, dynamic>.from(_user.preferences);
    newPrefs['accentColor'] = color.value;
    _user = _user.copyWith(preferences: newPrefs);
    _save();
  }

  void addMemory(String fact) {
    final updated = List<String>.from(_user.aiMemory)..add(fact);
    _user = _user.copyWith(aiMemory: updated);
    _save();
    notifyListeners();
  }

  void removeMemory(String fact) {
    final updated = List<String>.from(_user.aiMemory)..remove(fact);
    _user = _user.copyWith(aiMemory: updated);
    _save();
    notifyListeners();
  }

  void updateMemory(String oldFact, String newFact) {
    final updated = List<String>.from(_user.aiMemory);
    final index = updated.indexOf(oldFact);
    if (index != -1) {
      updated[index] = newFact;
      _user = _user.copyWith(aiMemory: updated);
      _save();
      notifyListeners();
    }
  }

  void updateCustomPersona(String persona) {
    _user = _user.copyWith(customPersona: persona);
    _save();
    notifyListeners();
  }

  void reorderDock(int old, int newIdx) {
    if (newIdx > old) newIdx -= 1;
    final items = List<String>.from(_user.dockItems);
    final item = items.removeAt(old);
    items.insert(newIdx, item);
    _user = _user.copyWith(dockItems: items);
    _save();
    notifyListeners();
  }
  
  void addToDock(String id) {
    final items = List<String>.from(_user.dockItems);
    if (!items.contains(id)) {
      if (items.length >= 5) items.removeLast();
      items.add(id);
      _user = _user.copyWith(dockItems: items);
      _save();
      notifyListeners();
    }
  }
  
  void removeFromDock(String id) {
    final items = List<String>.from(_user.dockItems);
    if (items.length > 2) {
      items.remove(id);
      _user = _user.copyWith(dockItems: items);
      _save();
      notifyListeners();
    }
  }

  void toggleAppVisibility(String key) {
    final current = Map<String, bool>.from(appVisibility);
    current[key] = !(current[key] ?? true);
    
    final newPrefs = Map<String, dynamic>.from(_user.preferences);
    newPrefs['appVisibility'] = current;
    
    _user = _user.copyWith(preferences: newPrefs);
    _save();
    notifyListeners();
  }

  bool isFolderVisible(String folder) => _folderVisibility[folder] ?? true;
  
  void _loadUser() {
    final saved = StorageService.loadUser();
    if (saved != null) {
      _user = saved;
      notifyListeners();
    }
  }

  void _save() {
    StorageService.saveUser(_user);
    notifyListeners();
  }
}
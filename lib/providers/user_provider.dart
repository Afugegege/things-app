import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; 
import '../models/user_model.dart';
import '../services/storage_service.dart';

class UserProvider extends ChangeNotifier {
  User _user = User(
    id: 'user_001',
    name: 'Traveler',
    email: 'traveler@things.app',
    aiMemory: ["I love pizza", "My goal is to be organized"], 
    preferences: {
      'isDarkMode': false,
      'accentColor': 0xFF000000, 
      'notifications': true,
    },
    isPro: true,
    dockItems: ['dashboard', 'notes', 'tasks', 'ai', 'profile'],
  );

  UserProvider() {
    loadUser();
  }

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
    'notes': {'label': 'Notes', 'icon': CupertinoIcons.doc_text_fill},
    'tasks': {'label': 'Tasks', 'icon': CupertinoIcons.checkmark_alt_circle_fill},
    'ai': {'label': 'AI', 'icon': CupertinoIcons.sparkles},
    'calendar': {'label': 'Calendar', 'icon': CupertinoIcons.calendar},
    'profile': {'label': 'You', 'icon': CupertinoIcons.person_fill},
    'wallet': {'label': 'Wallet', 'icon': CupertinoIcons.money_dollar},

  };
  
  final Map<String, bool> _folderVisibility = {};

  // --- GETTERS ---
  User get user => _user;
  List<String> get dockItems => _user.dockItems;
  Map<String, dynamic> get availableApps => _availableApps;
  
  Map<String, bool> get appVisibility {
    final Map<String, dynamic> stored = _user.preferences['appVisibility'] ?? {};
    // Merge with defaults to ensure new keys exist
    return {
      'Wallet': stored['Wallet'] ?? true,

      'Focus': stored['Focus'] ?? true,
      'Brain': stored['Brain'] ?? true,
      'Events': stored['Events'] ?? true,
    };
  }

  bool get isDarkMode => _user.preferences['isDarkMode'] ?? false;
  bool get isGrid => _user.preferences['isGrid'] ?? true;

  static const List<Map<String, dynamic>> presetAccentColors = [
    {
      'name': 'Monochrome',
      'color': Colors.transparent,
      'isMono': true,
    },
    {
      'name': 'Electric Blue',
      'color': Color(0xFF3B82F6),
      'isMono': false,
    },
    {
      'name': 'Emerald Green',
      'color': Color(0xFF10B981),
      'isMono': false,
    },
    {
      'name': 'Sunset Violet',
      'color': Color(0xFF8B5CF6),
      'isMono': false,
    },
    {
      'name': 'Coral Orange',
      'color': Color(0xFFF97316),
      'isMono': false,
    },
    {
      'name': 'Rose Pink',
      'color': Color(0xFFF43F5E),
      'isMono': false,
    },
    {
      'name': 'Ocean Cyan',
      'color': Color(0xFF06B6D4),
      'isMono': false,
    },
    {
      'name': 'Golden Amber',
      'color': Color(0xFFF59E0B),
      'isMono': false,
    },
  ];

  bool get isMonoAccent {
    int? colorVal = _user.preferences['accentColor'];
    return colorVal == null || colorVal == 0 || colorVal == 0xFFFFFFFF || colorVal == 0xFF000000;
  }

  Color get accentColor {
    if (isMonoAccent) {
      return isDarkMode ? Colors.white : Colors.black;
    }
    return Color(_user.preferences['accentColor'] as int);
  }

  double get glassOpacity => (_user.preferences['glassOpacity'] as num?)?.toDouble() ?? StorageService.loadGlassOpacity();
  String get fontFamily => (_user.preferences['fontFamily'] as String?) ?? StorageService.loadFontFamily();
  int get currentStreak => 5; 

  // --- ACTIONS ---

  void toggleTheme(bool isDark) {
    final newPrefs = Map<String, dynamic>.from(_user.preferences);
    newPrefs['isDarkMode'] = isDark;
    _user = _user.copyWith(preferences: newPrefs);
    _save();
  }

  void updateAccentColor(Color color, {bool isMono = false}) {
    final newPrefs = Map<String, dynamic>.from(_user.preferences);
    if (isMono || color == Colors.transparent || color.value == 0 || color == Colors.white || color == Colors.black) {
      newPrefs['accentColor'] = 0;
    } else {
      newPrefs['accentColor'] = color.value;
    }
    _user = _user.copyWith(preferences: newPrefs);
    _save();
  }

  void updateGlassOpacity(double opacity) {
    final newPrefs = Map<String, dynamic>.from(_user.preferences);
    newPrefs['glassOpacity'] = opacity;
    _user = _user.copyWith(preferences: newPrefs);
    StorageService.saveGlassOpacity(opacity);
    _save();
  }

  void updateFontFamily(String font) {
    final newPrefs = Map<String, dynamic>.from(_user.preferences);
    newPrefs['fontFamily'] = font;
    _user = _user.copyWith(preferences: newPrefs);
    StorageService.saveFontFamily(font);
    _save();
  }

  void setGrid(bool value) {
    final newPrefs = Map<String, dynamic>.from(_user.preferences);
    newPrefs['isGrid'] = value;
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
      if (items.length >= 6) items.removeLast();
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
  
  void loadUser() {
    final saved = StorageService.loadUser();
    if (saved != null) {
      _user = saved;
    } else {
      _user = User(
        id: 'user_001',
        name: 'Traveler',
        email: 'traveler@things.app',
        aiMemory: [],
        preferences: {'isDarkMode': false, 'accentColor': 0xFF000000, 'notifications': true},
        isPro: true,
        dockItems: const ['dashboard', 'notes', 'tasks', 'ai', 'profile'],
      );
    }
    notifyListeners();
  }

  void _save() {
    StorageService.saveUser(_user);
    notifyListeners();
  }
}
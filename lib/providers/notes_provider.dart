import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../services/storage_service.dart'; 

class NotesProvider extends ChangeNotifier {
  List<String> _folders = ['All', 'General', 'Personal', 'Work', 'Ideas', 'Travel'];
  String _selectedFolder = 'All';
  List<Note> _notes = [];

  NotesProvider() {
    _loadData();
  }

  void _loadData() {
    final savedNotes = StorageService.loadNotes();
    if (savedNotes.isNotEmpty) {
      _notes = savedNotes;
    }
    // Load folders
    final savedFolders = StorageService.loadFolders();
    if (savedFolders.isNotEmpty) {
      for (var f in savedFolders) {
        if (!_folders.contains(f)) _folders.add(f);
      }
    }
    
    // Ensure folders from notes exist (legacy support)
    for (var note in _notes) {
      if (!_folders.contains(note.folder)) {
        _folders.add(note.folder);
      }
      }

    
    // Load Folder Widgets
    _folderWidgets = StorageService.loadFolderWidgets();
    
    notifyListeners();
  }

  String get selectedFolder => _selectedFolder;
  List<String> get folders => _folders;

  List<Note> get notes {
    List<Note> filteredNotes = _notes;
    if (_selectedFolder != 'All') {
      filteredNotes = _notes.where((n) => n.folder == _selectedFolder).toList();
    }
    filteredNotes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return filteredNotes;
  }

  // --- WIDGET WIDTH TOGGLE ---

  void toggleNoteWidth(String id) {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(
        isFullWidth: !(_notes[index].isFullWidth),
      );
      StorageService.saveNotes(_notes); // Persistence
      notifyListeners();
    }
  }

  // --- MERGE FEATURE ---
  void _save() => StorageService.saveNotes(_notes);
  void mergeNotes(List<String> ids) {
    final notesToMerge = _notes.where((n) => ids.contains(n.id)).toList();
    if (notesToMerge.length < 2) return;

    notesToMerge.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    String mergedTitle = notesToMerge.map((n) => n.title).join(" + ");
    List<dynamic> mergedOps = [];
    
    for (var i = 0; i < notesToMerge.length; i++) {
      final note = notesToMerge[i];
      try {
        List<dynamic> ops = jsonDecode(note.content);
        mergedOps.addAll(ops);
      } catch (e) {
        mergedOps.add({"insert": "${note.content}\n"});
      }

      if (i < notesToMerge.length - 1) {
        mergedOps.add({
          "insert": "\n\n——— Merged (${note.title}) ———\n\n", 
          "attributes": {"bold": true, "color": "#cccccc"}
        });
      }
    }

    final newNote = Note(
      id: const Uuid().v4(),
      title: mergedTitle,
      content: jsonEncode(mergedOps),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folder: notesToMerge.first.folder,
      themeId: notesToMerge.first.themeId,
      backgroundColor: notesToMerge.first.backgroundColor,
      isPinned: false,
    );

    _notes.removeWhere((n) => ids.contains(n.id));
    _notes.insert(0, newNote);
    
    StorageService.saveNotes(_notes);
    notifyListeners();
  }

  // --- FOLDER MANAGEMENT ---

  void addFolder(String folder) {
    if (!_folders.contains(folder)) {
      _folders.add(folder);
      StorageService.saveFolders(_folders);
      // Init empty widgets
      _folderWidgets[folder] = []; 
      StorageService.saveFolderWidgets(_folderWidgets);
      notifyListeners();
    }
  }

  void deleteFolder(String folder) {
    if (folder == 'All' || folder == 'General') return;
    _folders.remove(folder);
    _notes = _notes.map((n) {
      if (n.folder == folder) return n.copyWith(folder: 'General');
      return n;
    }).toList();
    if (_selectedFolder == folder) _selectedFolder = 'All';
    StorageService.saveNotes(_notes);
    StorageService.saveFolders(_folders);
    notifyListeners();
  }

  // --- NOTE ACTIONS ---

  void selectFolder(String f) { _selectedFolder = f; notifyListeners(); }
  
  void addNote(Note n) { 
    _notes.insert(0, n); 
    StorageService.saveNotes(_notes); 
    notifyListeners(); 
  }
  
  void updateNote(Note n) { 
    final i = _notes.indexWhere((x) => x.id == n.id); 
    if (i != -1) { 
      _notes[i] = n; 
      StorageService.saveNotes(_notes); 
      notifyListeners(); 
    } 
  }
  
  void deleteNotes(String id) { 
    _notes.removeWhere((n) => n.id == id); 
    StorageService.saveNotes(_notes); 
    notifyListeners(); 
  }

  void batchMoveNotes(List<String> ids, String newFolder) {
    bool changed = false;
    for (var i = 0; i < _notes.length; i++) {
       if (ids.contains(_notes[i].id)) {
           _notes[i] = _notes[i].copyWith(folder: newFolder);
           changed = true;
       }
    }
    if (changed) {
      StorageService.saveNotes(_notes);
      notifyListeners();
    }
  }

  // --- FOLDER WIDGETS CONFIG ---
  
  Map<String, List<String>> _folderWidgets = {};
  
  List<String> getWidgetsForFolder(String folder) {
    if (folder == 'All') {
       // 'All' shows everything by default (controlled by main filtering)
       return ['Calendar','Tasks','Money','Roam','Flashcards','Bucket']; 
    }
    return _folderWidgets[folder] ?? []; // Default to empty if not configured
  }

  void toggleFolderWidget(String folder, String widgetId) {
    if (folder == 'All') return;
    
    List<String> current = List.from(_folderWidgets[folder] ?? []);
    if (current.contains(widgetId)) {
      current.remove(widgetId);
    } else {
      current.add(widgetId);
    }
    _folderWidgets[folder] = current;
    StorageService.saveFolderWidgets(_folderWidgets);
    notifyListeners();
  }

  // --- EXISTING METHODS ---
  
  void togglePin(String id) {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(isPinned: !_notes[index].isPinned);
      StorageService.saveNotes(_notes);
      notifyListeners();
    }
  }
}
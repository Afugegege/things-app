import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../services/storage_service.dart'; 

class NotesProvider extends ChangeNotifier {
  List<String> _folders = ['Uncategorised', 'Personal', 'Work', 'Ideas', 'Travel'];
  String _selectedFolder = 'All';
  List<Note> _notes = [];

  NotesProvider() {
    _loadData();
  }

  void _loadData() {
    final savedNotes = StorageService.loadNotes();
    if (savedNotes.isNotEmpty) {
      _notes = savedNotes;
    } else {
      // Sample Data Injection
      _notes = [
        Note(
          id: const Uuid().v4(),
          title: "Japan Trip",
          content: "[[date:2026-04-15]]", 
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          folder: "Travel",
        ),
        Note(
          id: const Uuid().v4(),
          title: "Grocery List",
          content: "- [ ] Almond Milk\n- [ ] Avocados\n- [x] Coffee Beans",
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          updatedAt: DateTime.now(),
          folder: "Personal",
        ),
      ];
      StorageService.saveNotes(_notes);
    }
    notifyListeners();
  }

  String get selectedFolder => _selectedFolder;
  List<String> get folders => _folders;

  List<Note> get notes {
    List<Note> filteredNotes = _notes;
    if (_selectedFolder != 'All') {
      filteredNotes = _notes.where((n) => n.folder == _selectedFolder).toList();
    }
    // Sort: Pinned first, then Newest
    filteredNotes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return filteredNotes;
  }

  // --- ACTIONS (FIXED: Added missing methods) ---

  void togglePin(String id) {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(isPinned: !_notes[index].isPinned);
      StorageService.saveNotes(_notes);
      notifyListeners();
    }
  }

  void deleteNotes(List<String> ids) {
    _notes.removeWhere((n) => ids.contains(n.id));
    StorageService.saveNotes(_notes);
    notifyListeners();
  }

  void mergeNotes(List<String> ids) {
    if (ids.length < 2) return;

    final notesToMerge = _notes.where((n) => ids.contains(n.id)).toList();
    // Sort by creation time to keep logic flow
    notesToMerge.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final mergedTitle = notesToMerge.map((n) => n.title).join(" + ");
    final mergedContent = notesToMerge.map((n) => n.plainTextContent).join("\n\n---\n\n");

    final newNote = Note(
      id: const Uuid().v4(),
      title: mergedTitle,
      content: mergedContent,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folder: notesToMerge.first.folder,
    );

    addNote(newNote);
    deleteNotes(ids); // Remove originals
  }

  void selectFolder(String f) { _selectedFolder = f; notifyListeners(); }
  void addNote(Note n) { _notes.insert(0, n); StorageService.saveNotes(_notes); notifyListeners(); }
  void updateNote(Note n) { final i = _notes.indexWhere((x) => x.id == n.id); if (i != -1) { _notes[i] = n; StorageService.saveNotes(_notes); notifyListeners(); } }
  void deleteNote(String id) { _notes.removeWhere((n) => n.id == id); StorageService.saveNotes(_notes); notifyListeners(); }
  void createFolder(String f) { if (!_folders.contains(f)) { _folders.add(f); notifyListeners(); } }
}
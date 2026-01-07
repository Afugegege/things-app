import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';

class TasksProvider extends ChangeNotifier {
  List<Task> _tasks = [
    Task(
      id: const Uuid().v4(), 
      title: 'Finish UI Design for Dashboard', 
      isDone: false, 
      createdAt: DateTime.now(), 
      priority: 2,
      isPinned: true, 
    ),
    Task(
      id: const Uuid().v4(), 
      title: 'Call Mom', 
      isDone: false, 
      createdAt: DateTime.now(), 
      priority: 1 
    ),
  ];

  // Getters
  List<Task> get tasks {
    final active = _tasks.where((t) => !t.isDone).toList();
    final done = _tasks.where((t) => t.isDone).toList();
    
    final combined = [...active, ...done];

    // Sort: Pinned first, then by Priority, then by Creation Date
    combined.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      // If pin status is same, sort by priority (High to Low)
      if (b.priority != a.priority) return b.priority.compareTo(a.priority);
      // Finally sort by date (Newest first)
      return b.createdAt.compareTo(a.createdAt);
    });

    return combined;
  }

  // --- ACTIONS ---

  void addTask(Task task) {
    _tasks.insert(0, task); 
    notifyListeners();
  }

  void toggleTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final current = _tasks[index];
      _tasks[index] = current.copyWith(isDone: !current.isDone);
      notifyListeners();
    }
  }

  void updateTask(Task updatedTask) {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // [FIX] Restored Missing Method
  void reorderTasks(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    // Note: Since the list is auto-sorted by IsPinned/Priority, 
    // manual reordering might be overridden on the next refresh.
    // We perform the move on the internal list to support basic drag-and-drop feeling.
    if (oldIndex < _tasks.length) {
      final task = _tasks.removeAt(oldIndex);
      _tasks.insert(newIndex.clamp(0, _tasks.length), task);
      notifyListeners();
    }
  }

  void togglePin(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final t = _tasks[index];
      _tasks[index] = t.copyWith(isPinned: !t.isPinned);
      notifyListeners();
    }
  }
}
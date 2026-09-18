import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/storage_service.dart';
import '../data/sample_data.dart';

class TasksProvider extends ChangeNotifier {
  List<Task> _tasks = [];

  List<Task> get tasks => _tasks;

  TasksProvider() {
    loadTasks();
  }

  void loadTasks() {
    final loaded = StorageService.loadTasks();
    _tasks = loaded;

    // Sort: Not Done first, then by priority (descending)
    _tasks.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      if (a.priority != b.priority) return b.priority.compareTo(a.priority);
      return 0; // Maintain order otherwise
    });
    notifyListeners();
  }

  void addTask(Task task) {
    _tasks.insert(0, task);
    _save();
  }

  void toggleTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final task = _tasks[index];
      _tasks[index] = task.copyWith(isDone: !task.isDone);
      
      // Auto-sort disabled to allow "undo" in Dashboard
      // _tasks.sort((a, b) {
      //   if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      //   if (a.priority != b.priority) return b.priority.compareTo(a.priority);
      //   return 0; 
      // });
      
      _save();
    }
  }

  void updateTask(Task task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      _save();
    }
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    _save();
  }

  void restoreTask(Task task, {int? index}) {
    if (index != null && index >= 0 && index <= _tasks.length) {
      _tasks.insert(index, task);
    } else {
      _tasks.insert(0, task);
    }
    _save();
  }

  void reorderTasks(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _tasks.removeAt(oldIndex);
    _tasks.insert(newIndex, item);
    _save();
  }

  void _save() {
    StorageService.saveTasks(_tasks);
    notifyListeners();
  }
}
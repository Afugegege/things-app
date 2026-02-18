import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/storage_service.dart';
import '../data/sample_data.dart';

class TasksProvider extends ChangeNotifier {
  List<Task> _tasks = [];

  List<Task> get tasks => _tasks;

  TasksProvider() {
    _loadTasks();
  }

  void _loadTasks() {
    final loaded = StorageService.loadTasks();
    if (loaded.isNotEmpty) {
      _tasks = loaded;
    } else {
      // Load Sample Data
      _tasks = SampleData.getSampleTasks();
      StorageService.saveTasks(_tasks); // Persist sample data
    }

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
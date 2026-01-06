import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';

class TasksProvider extends ChangeNotifier {
  // --- REAL SAMPLE TASKS ---
  List<Task> _tasks = [
    Task(
      id: const Uuid().v4(), 
      title: 'Finish UI Design for Dashboard', 
      isDone: false, 
      createdAt: DateTime.now(), 
      priority: 2 // High Priority (Red)
    ),
    Task(
      id: const Uuid().v4(), 
      title: 'Call Mom', 
      isDone: false, 
      createdAt: DateTime.now(), 
      priority: 1 // Medium Priority (Orange)
    ),
    Task(
      id: const Uuid().v4(), 
      title: 'Book dentist appointment', 
      isDone: false, 
      createdAt: DateTime.now(), 
      priority: 0 // Low Priority (Black/Grey)
    ),
    Task(
      id: const Uuid().v4(), 
      title: 'Review quarterly goals', 
      isDone: true, 
      createdAt: DateTime.now().subtract(const Duration(days: 1)), 
      priority: 1 
    ),
  ];

  List<Task> get tasks {
    final active = _tasks.where((t) => !t.isDone).toList();
    final done = _tasks.where((t) => t.isDone).toList();
    return [...active, ...done];
  }

  // ... (Keep existing methods: addTask, toggleTask, etc.)
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

  void reorderTasks(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final task = tasks.removeAt(oldIndex); 
    _tasks.removeWhere((t) => t.id == task.id);
    _tasks.insert(newIndex, task);
    notifyListeners();
  }
}
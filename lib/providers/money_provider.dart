import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class MoneyProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _transactions = [
    {'id': const Uuid().v4(), 'title': 'Uber Ride', 'amount': -24.50, 'date': DateTime.now().toString(), 'category': 'Transport'},
    {'id': const Uuid().v4(), 'title': 'Freelance Project', 'amount': 450.0, 'date': DateTime.now().subtract(const Duration(hours: 4)).toString(), 'category': 'Income'},
    {'id': const Uuid().v4(), 'title': 'Grocery Run', 'amount': -86.20, 'date': DateTime.now().subtract(const Duration(days: 1)).toString(), 'category': 'Food'},
    {'id': const Uuid().v4(), 'title': 'Netflix Sub', 'amount': -15.00, 'date': DateTime.now().subtract(const Duration(days: 2)).toString(), 'category': 'Entertainment'},
    {'id': const Uuid().v4(), 'title': 'Gym Membership', 'amount': -45.00, 'date': DateTime.now().subtract(const Duration(days: 3)).toString(), 'category': 'Health'},
  ];

  // [NEW] Dynamic Category List
  final List<String> _categories = ['Food', 'Transport', 'Shopping', 'Entertainment', 'Health', 'Other'];

  final Map<String, double> _budgets = {
    'Food': 300.0,
    'Transport': 150.0,
    'Entertainment': 100.0,
    'Shopping': 200.0,
  };

  List<Map<String, dynamic>> get transactions => _transactions;
  List<String> get categories => _categories; // Getter for UI
  Map<String, double> get budgets => _budgets;

  double get balance {
    return 2450.0 + _transactions.fold(0.0, (sum, item) => sum + (item['amount'] as double));
  }

  double get totalIncome {
    return _transactions.where((t) => (t['amount'] as double) > 0).fold(0.0, (sum, t) => sum + (t['amount'] as double));
  }

  double get totalExpense {
    return _transactions.where((t) => (t['amount'] as double) < 0).fold(0.0, (sum, t) => sum + (t['amount'] as double));
  }

  Map<String, double> get spendingByCategory {
    final Map<String, double> data = {};
    for (var t in _transactions) {
      if ((t['amount'] as double) < 0) {
        final cat = t['category'] ?? 'Other';
        data[cat] = (data[cat] ?? 0.0) + (t['amount'] as double).abs();
      }
    }
    return data;
  }

  double getSpentForCategory(String category) {
    return spendingByCategory[category] ?? 0.0;
  }

  // --- ACTIONS ---

  // [NEW] Add Custom Category
  void addCategory(String category) {
    if (!_categories.contains(category)) {
      _categories.add(category);
      notifyListeners();
    }
  }

  void addTransaction(String title, double amount, String category, {DateTime? date}) {
    _transactions.insert(0, {
      'id': const Uuid().v4(),
      'title': title,
      'amount': amount,
      'date': (date ?? DateTime.now()).toString(),
      'category': category,
    });
    notifyListeners();
  }

  void editTransaction(String id, String title, double amount, String category) {
    final index = _transactions.indexWhere((t) => t['id'] == id);
    if (index != -1) {
      _transactions[index] = {
        ..._transactions[index],
        'title': title,
        'amount': amount,
        'category': category,
      };
      notifyListeners();
    }
  }

  void removeTransactionById(String id) {
    _transactions.removeWhere((t) => t['id'] == id);
    notifyListeners();
  }

  void removeTransaction(int index) {
    _transactions.removeAt(index);
    notifyListeners();
  }
}
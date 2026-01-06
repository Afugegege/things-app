import 'package:flutter/material.dart';

class MoneyProvider extends ChangeNotifier {
  // --- REAL SAMPLE TRANSACTIONS ---
  final List<Map<String, dynamic>> _transactions = [
    {'title': 'Uber Ride', 'amount': -24.50, 'date': DateTime.now().toString()},
    {'title': 'Freelance Project', 'amount': 450.0, 'date': DateTime.now().subtract(const Duration(hours: 4)).toString()},
    {'title': 'Grocery Run', 'amount': -86.20, 'date': DateTime.now().subtract(const Duration(days: 1)).toString()},
    {'title': 'Netflix Sub', 'amount': -15.00, 'date': DateTime.now().subtract(const Duration(days: 2)).toString()},
  ];

  List<Map<String, dynamic>> get transactions => _transactions;

  double get balance {
    return 2450.0 + _transactions.fold(0.0, (sum, item) => sum + (item['amount'] as double));
  }

  // ... (Keep existing methods)
  void addTransaction(String title, double amount) {
    _transactions.insert(0, {
      'title': title,
      'amount': amount,
      'date': DateTime.now().toString(),
    });
    notifyListeners();
  }

  void removeTransaction(int index) {
    _transactions.removeAt(index);
    notifyListeners();
  }
}
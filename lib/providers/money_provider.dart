import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';

class MoneyProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _transactions = [];

  // [NEW] Dynamic Category List
  final List<String> _categories = ['Food', 'Transport', 'Shopping', 'Entertainment', 'Health', 'Other'];

  // [NEW] Savings State
  double _totalSavings = 0.0;
  bool _isSavingsVisible = true;
  
  // [NEW] Goals & Budgets
  List<Map<String, dynamic>> _savingsGoals = []; 
  // Structure: {id, title, targetAmount, currentAmount, deadline, color}

  Map<String, double> _budgets = {
    'Food': 300.0,
    'Transport': 150.0,
    'Entertainment': 100.0,
    'Shopping': 200.0,
    'Health': 100.0,
  };

  // [NEW] Accounts (Savings Module)
  List<Map<String, dynamic>> _accounts = [
    {'id': '1', 'name': 'Bank', 'type': 'Bank', 'balance': 0.0},
    {'id': '2', 'name': 'E-Wallet', 'type': 'Wallet', 'balance': 0.0},
    {'id': '3', 'name': 'Cash', 'type': 'Cash', 'balance': 0.0},
    {'id': '4', 'name': 'Investment', 'type': 'Invest', 'balance': 0.0},
  ];

  MoneyProvider() {
    _loadData();
  }

  void _loadData() {
    final loaded = StorageService.loadTransactions();
    if (loaded.isNotEmpty) {
      _transactions = loaded;
    } 
    
    // Load Settings
    final settings = StorageService.loadMoneySettings();
    if (settings.isNotEmpty) {
      _totalSavings = (settings['totalSavings'] as num?)?.toDouble() ?? 0.0;
      _isSavingsVisible = settings['isSavingsVisible'] ?? true;
      if (settings['budgets'] != null) {
        _budgets = Map<String, double>.from(settings['budgets']);
      }
      if (settings['goals'] != null) {
        _savingsGoals = List<Map<String, dynamic>>.from(settings['goals']);
      }
      if (settings['accounts'] != null) {
        _accounts = List<Map<String, dynamic>>.from(settings['accounts']);
      }
    }
    
    notifyListeners();
  }

  List<Map<String, dynamic>> get transactions => _transactions;
  List<String> get categories => _categories; 
  Map<String, double> get budgets => _budgets;
  List<Map<String, dynamic>> get savingsGoals => _savingsGoals;
  List<Map<String, dynamic>> get accounts => _accounts; // Getter for accounts
  
  double get totalSavings => _totalSavings;
  bool get isSavingsVisible => _isSavingsVisible;

  // --- ACCOUNTS ACTIONS ---
  void addAccount(String name, String type, double balance) {
    _accounts.add({
      'id': const Uuid().v4(),
      'name': name,
      'type': type,
      'balance': balance,
    });
    _saveSettings();
  }

  void updateAccount(String id, String name, double balance) {
    final index = _accounts.indexWhere((a) => a['id'] == id);
    if (index != -1) {
      _accounts[index]['name'] = name;
      _accounts[index]['balance'] = balance;
      _saveSettings();
    }
  }

  void removeAccount(String id) {
    _accounts.removeWhere((a) => a['id'] == id);
    _saveSettings();
  }
  
  // --- SPEND SUMMARY LOGIC ---
  Map<String, double> getSpendSummary(String period) { // period: 'Daily', 'Weekly', 'Monthly'
    Map<String, double> summary = {};
    DateTime now = DateTime.now();
    
    // Helper to normalize date (strip time)
    DateTime normalize(DateTime d) => DateTime(d.year, d.month, d.day);
    
    for (var t in _transactions) {
      if ((t['amount'] as double) >= 0) continue; // Skip income
      
      DateTime date = DateTime.parse(t['date']);
      double amount = (t['amount'] as double).abs();
      String key = "";
      
      if (period == 'Daily') {
        // Last 7 Days
        if (now.difference(date).inDays <= 7) {
           key = "${date.day}/${date.month}"; // e.g., "12/10"
        }
      } else if (period == 'Weekly') {
        // Simple approximation: Group by Week Number of current year? 
        // Or just "This Week", "Last Week". Let's do simple Date Ranges.
        // Actually, user wants summary. Let's return mapped values.
        if (now.difference(date).inDays <= 28) {
           int weekDiff = (now.difference(date).inDays / 7).floor();
           if (weekDiff == 0) key = "This Week";
           else if (weekDiff == 1) key = "Last Week";
           else key = "$weekDiff Weeks Ago";
        }
      } else if (period == 'Monthly') {
        // Last 6 Months
        if (now.difference(date).inDays <= 180) {
           const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
           key = "${months[date.month-1]}";
        }
      }
      
      if (key.isNotEmpty) {
        summary[key] = (summary[key] ?? 0.0) + amount;
      }
    }
    
    // Sort Keys? (Ideally passed as sorted list, but map keys might be unordered. 
    // The UI handles sorting or we return a LinkedHashMap. For now, basic map.)
    return summary;
  }

  // --- ANALYSIS GETTERS ---
  
  double getDailyBudget(String category) {
    if (!_budgets.containsKey(category)) return 0.0;
    
    final budget = _budgets[category]!;
    final spent = getSpentForCategory(category);
    final now = DateTime.now();
    
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final remainingDays = daysInMonth - now.day + 1; // Including today
    
    double remainingBudget = budget - spent;
    if (remainingBudget <= 0) return 0.0;
    
    return remainingBudget / remainingDays;
  }
  
  String getSmartAdvice() {
    // 1. Check Overspending
    String badCat = '';
    double maxOver = 0.0;
    
    _budgets.forEach((cat, limit) {
      double spent = getSpentForCategory(cat);
      if (spent > limit * 0.9) { // 90% used
        if ((spent / limit) > maxOver) {
          maxOver = spent / limit;
          badCat = cat;
        }
      }
    });
    
    if (badCat.isNotEmpty) {
      return "Slow down on $badCat! You've used ${(maxOver * 100).toStringAsFixed(0)}% of your budget.";
    }
    
    // 2. Check Savings Goal
    if (_savingsGoals.isNotEmpty) {
      final goal = _savingsGoals.first;
      double needed = (goal['targetAmount'] as double) - (goal['currentAmount'] as double);
      if (needed > 0) {
        return "You're close to your '${goal['title']}' goal! Save \$${needed.toStringAsFixed(0)} more.";
      }
    }
    
    return "You're doing great! Spending is within limits.";
  }

  double get balance {
    // If the user has set up Accounts (Assets), that is the source of truth for Balance.
    double accountsTotal = _accounts.fold(0.0, (sum, a) => sum + (a['balance'] as double));
    
    if (accountsTotal > 0 || _accounts.any((a) => (a['balance'] as double) != 0)) {
       // We have active accounts. 
       // NOTE: In a real app, transactions should be linked to accounts. 
       // For this simple version, we assume 'Accounts' represent the CURRENT state as manually updated by user,
       // OR we can say Balance = Accounts + Unlinked Transactions? 
       // Let's stick to: If Accounts exist, Balance is their sum. User updates Accounts manually for now
       // to match the "Save my bank, e-walllet" request which implies snapshotting.
       return accountsTotal;
    }

    // Fallback to Legacy: Base Savings + Cash Flow
    final netCashFlow = _transactions.fold(0.0, (sum, item) => sum + (item['amount'] as double));
    return _totalSavings + netCashFlow;
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

  void updateSavings(double amount) {
    // Function deprecated in favor of Accounts, but kept for legacy setting
    _totalSavings = amount;
    _saveSettings();
  }

  void toggleSavingsVisibility() {
    _isSavingsVisible = !_isSavingsVisible;
    _saveSettings();
  }

  // [NEW] Add Custom Category
  void addCategory(String category) {
    if (!_categories.contains(category)) {
      _categories.add(category);
      notifyListeners();
    }
  }

  void addTransaction(String title, double amount, String category, {DateTime? date}) {
    // When adding transaction, we might want to update an account?
    // For simplicity, we just track transactions for history/stats, 
    // but we can ask user "Which account?". For now, let's keep them separate 
    // unless user explicitly links them. The prompt didn't ask for linking yet.
    // Just "summarize my transaction".
    _transactions.insert(0, {
      'id': const Uuid().v4(),
      'title': title,
      'amount': amount,
      'date': (date ?? DateTime.now()).toString(),
      'category': category,
    });
    
    // OPTIONAL: Automatically adjust "Cash" or "Bank" if we wanted.
    // Let's keep it manual for now as per "save my bank... settings"
    
    _save();
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
      _save();
    }
  }

  void removeTransactionById(String id) {
    _transactions.removeWhere((t) => t['id'] == id);
    _save();
  }

  void removeTransaction(int index) {
    _transactions.removeAt(index);
    _save();
  }

  void _save() {
    StorageService.saveTransactions(_transactions);
    notifyListeners();
  }
  
  void addSavingsGoal(String title, double target, DateTime deadline) {
    _savingsGoals.add({
      'id': const Uuid().v4(),
      'title': title,
      'targetAmount': target,
      'currentAmount': 0.0,
      'deadline': deadline.toIso8601String(),
    });
    _saveSettings();
  }
  
  void updateBudget(String category, double amount) {
    _budgets[category] = amount;
    _saveSettings();
  }

  void _saveSettings() {
    StorageService.saveMoneySettings({
      'totalSavings': _totalSavings,
      'isSavingsVisible': _isSavingsVisible,
      'budgets': _budgets,
      'goals': _savingsGoals,
      'accounts': _accounts // Persist accounts
    });
    notifyListeners();
  }
}
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../data/sample_data.dart';
import '../models/currency_model.dart';

class MoneyProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _transactions = [];
  String _currentCurrency = 'USD';

  // [NEW] Dynamic Category List
  final List<String> _categories = [
    'Food',
    'Transport',
    'Shopping',
    'Entertainment',
    'Health',
    'Other'
  ];

  // [NEW] Savings State
  double _totalSavings = 0.0;
  bool _isSavingsVisible = true;

  // [NEW] Goals & Budgets
  List<Map<String, dynamic>> _savingsGoals = [];
  // Structure: {id, title, targetAmount, currentAmount, deadline, color}

  // [NEW] Spending Groups
  List<Map<String, dynamic>> _groups = [];
  // Structure: {id, name, icon, createdAt}

  Map<String, double> _budgets = {
    'Food': 300.0,
    'Transport': 150.0,
    'Entertainment': 100.0,
    'Shopping': 200.0,
    'Health': 100.0,
  };
  Map<String, Map<String, double>> _budgetsByCurrency = {};

  // [NEW] Accounts (Savings Module)
  List<Map<String, dynamic>> _accounts = [
    {'id': '1', 'name': 'Bank', 'type': 'Bank', 'balance': 0.0},
    {'id': '2', 'name': 'E-Wallet', 'type': 'Wallet', 'balance': 0.0},
    {'id': '3', 'name': 'Cash', 'type': 'Cash', 'balance': 0.0},
    {'id': '4', 'name': 'Investment', 'type': 'Invest', 'balance': 0.0},
  ];

  MoneyProvider() {
    loadData();
  }

  void loadData() {
    _currentCurrency = StorageService.loadSelectedCurrency();
    final bool hasInit = StorageService.hasMoneyInitialized();
    final loaded = StorageService.loadTransactions();

    if (hasInit) {
      _transactions = loaded;
      final settings = StorageService.loadMoneySettings();
      _totalSavings = (settings['totalSavings'] as num?)?.toDouble() ?? 0.0;
      _isSavingsVisible = settings['isSavingsVisible'] ?? true;
      if (settings['budgetsByCurrency'] != null) {
        try {
          final rawMap = settings['budgetsByCurrency'] as Map<String, dynamic>;
          _budgetsByCurrency = rawMap.map((k, v) =>
              MapEntry(k, Map<String, double>.from(v as Map)));
        } catch (_) {}
      }
      if (settings['budgets'] != null) {
        _budgetsByCurrency.putIfAbsent(
            'USD', () => Map<String, double>.from(settings['budgets']));
      }
      _savingsGoals = settings['goals'] != null
          ? List<Map<String, dynamic>>.from(settings['goals'])
          : [];
      _accounts = settings['accounts'] != null
          ? List<Map<String, dynamic>>.from(settings['accounts'])
          : [];
      _groups = settings['groups'] != null
          ? List<Map<String, dynamic>>.from(settings['groups'])
          : [];
      _budgets = _budgetsByCurrency[_currentCurrency] ?? {};
    } else {
      // First-time launch seed
      if (loaded.isNotEmpty) {
        _transactions = loaded;
      } else {
        _transactions = SampleData.getSampleTransactions();
        StorageService.saveTransactions(_transactions);
      }

      final settings = StorageService.loadMoneySettings();
      if (settings.isNotEmpty) {
        _totalSavings = (settings['totalSavings'] as num?)?.toDouble() ?? 0.0;
        _isSavingsVisible = settings['isSavingsVisible'] ?? true;
        if (settings['budgetsByCurrency'] != null) {
          try {
            final rawMap = settings['budgetsByCurrency'] as Map<String, dynamic>;
            _budgetsByCurrency = rawMap.map((k, v) =>
                MapEntry(k, Map<String, double>.from(v as Map)));
          } catch (_) {}
        }
        if (settings['budgets'] != null) {
          _budgetsByCurrency.putIfAbsent(
              'USD', () => Map<String, double>.from(settings['budgets']));
        }
        if (settings['goals'] != null) {
          _savingsGoals = List<Map<String, dynamic>>.from(settings['goals']);
        }
        if (settings['accounts'] != null) {
          _accounts = List<Map<String, dynamic>>.from(settings['accounts']);
        }
        if (settings['groups'] != null) {
          _groups = List<Map<String, dynamic>>.from(settings['groups']);
        }
      } else {
        final sample = SampleData.getSampleMoneySettings();
        _totalSavings = sample['totalSavings'];
        _isSavingsVisible = sample['isSavingsVisible'];
        final defaultBudgets = Map<String, double>.from(sample['budgets']);
        _budgetsByCurrency['USD'] = defaultBudgets;
        _savingsGoals = List<Map<String, dynamic>>.from(sample['goals']);
        _accounts = List<Map<String, dynamic>>.from(sample['accounts']);
        if (sample['groups'] != null) {
          _groups = List<Map<String, dynamic>>.from(sample['groups']);
        }
        StorageService.saveMoneySettings(sample);
      }
      _budgets = _budgetsByCurrency[_currentCurrency] ?? {};
      StorageService.setMoneyInitialized(true);
    }
    notifyListeners();
  }

  String get currentCurrency => _currentCurrency;
  AppCurrency get currency => AppCurrency.fromCode(_currentCurrency);
  String get currentCurrencySymbol => AppCurrency.getSymbol(_currentCurrency);

  void setCurrency(String newCurrency) {
    final upper = newCurrency.trim().toUpperCase();
    if (_currentCurrency == upper) return;
    _currentCurrency = upper;
    StorageService.saveSelectedCurrency(upper);

    if (_budgetsByCurrency.containsKey(upper)) {
      _budgets = _budgetsByCurrency[upper]!;
    } else {
      _budgets = Map<String, double>.from(SampleData.getSampleMoneySettings()['budgets']);
      _budgetsByCurrency[upper] = _budgets;
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> get allTransactions => _transactions;
  List<Map<String, dynamic>> get transactions =>
      _transactions.where((t) => (t['currency'] ?? 'USD') == _currentCurrency).toList();
  List<String> get categories => _categories;
  Map<String, double> get budgets => _budgets;
  List<Map<String, dynamic>> get savingsGoals => _savingsGoals;
  List<Map<String, dynamic>> get accounts => _accounts; // Getter for accounts
  List<Map<String, dynamic>> get groups => _groups;

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

  // --- GROUPS ACTIONS ---
  void addGroup(String name, String icon) {
    _groups.add({
      'id': const Uuid().v4(),
      'name': name,
      'icon': icon,
      'createdAt': DateTime.now().toIso8601String(),
    });
    _saveSettings();
  }

  void updateGroup(String id, String name, String icon) {
    final index = _groups.indexWhere((g) => g['id'] == id);
    if (index != -1) {
      _groups[index]['name'] = name;
      _groups[index]['icon'] = icon;
      _saveSettings();
    }
  }

  void removeGroup(String id) {
    // Remove group and unlink transactions
    _groups.removeWhere((g) => g['id'] == id);
    for (var t in _transactions) {
      if (t['groupId'] == id) {
        t['groupId'] = null;
        t['excludeFromExpenses'] = false;
      }
    }
    _save();
    _saveSettings();
  }

  // --- GROUP HELPERS ---
  List<Map<String, dynamic>> getTransactionsForGroup(String groupId) {
    return transactions.where((t) => t['groupId'] == groupId).toList();
  }

  double getGroupTotal(String groupId) {
    return getTransactionsForGroup(groupId)
        .where((t) => (t['amount'] as double) < 0)
        .fold(0.0, (sum, t) => sum + (t['amount'] as double).abs());
  }

  double getGroupPersonalTotal(String groupId) {
    return getTransactionsForGroup(groupId)
        .where((t) => (t['amount'] as double) < 0 && t['excludeFromExpenses'] != true)
        .fold(0.0, (sum, t) => sum + (t['amount'] as double).abs());
  }

  int getGroupTransactionCount(String groupId) {
    return getTransactionsForGroup(groupId).length;
  }

  String? getGroupName(String? groupId) {
    if (groupId == null) return null;
    final idx = _groups.indexWhere((g) => g['id'] == groupId);
    if (idx == -1) return null;
    return _groups[idx]['name'];
  }

  String? getGroupIcon(String? groupId) {
    if (groupId == null) return null;
    final idx = _groups.indexWhere((g) => g['id'] == groupId);
    if (idx == -1) return null;
    return _groups[idx]['icon'];
  }

  void toggleExcludeFromExpenses(String transactionId) {
    final index = _transactions.indexWhere((t) => t['id'] == transactionId);
    if (index != -1) {
      final current = _transactions[index]['excludeFromExpenses'] == true;
      _transactions[index] = {
        ..._transactions[index],
        'excludeFromExpenses': !current,
      };
      _save();
    }
  }

  // --- SPEND SUMMARY LOGIC ---
  Map<String, double> getSpendSummary(String period) {
    // period: 'Daily', 'Weekly', 'Monthly'
    Map<String, double> summary = {};
    DateTime now = DateTime.now();
    for (var t in transactions) {
      if ((t['amount'] as double) >= 0) continue; // Skip income
      if (t['excludeFromExpenses'] == true) continue; // Skip excluded

      DateTime date = DateTime.parse(t['date']);
      double amount = (t['amount'] as double).abs();
      String key = "";

      if (period == 'Daily') {
        // Last 7 Days
        if (now.difference(date).inDays <= 7) {
          key = "${date.day}/${date.month}"; // e.g., "12/10"
        }
      } else if (period == 'Weekly') {
        if (now.difference(date).inDays <= 28) {
          int weekDiff = (now.difference(date).inDays / 7).floor();
          if (weekDiff == 0) {
            key = "This Week";
          } else if (weekDiff == 1) {
            key = "Last Week";
          } else {
            key = "$weekDiff Weeks Ago";
          }
        }
      } else if (period == 'Monthly') {
        // Last 6 Months
        if (now.difference(date).inDays <= 180) {
          const months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec'
          ];
          key = months[date.month - 1];
        }
      }

      if (key.isNotEmpty) {
        summary[key] = (summary[key] ?? 0.0) + amount;
      }
    }

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
      if (spent > limit * 0.9) {
        // 90% used
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
      double needed =
          (goal['targetAmount'] as double) - (goal['currentAmount'] as double);
      if (needed > 0) {
        return "You're close to your '${goal['title']}' goal! Save $currentCurrencySymbol${needed.toStringAsFixed(0)} more.";
      }
    }

    return "You're doing great! Spending is within limits.";
  }

  double get balance {
    // Accounts for current currency if tagged, or if accounts exist
    final currentAccounts =
        _accounts.where((a) => (a['currency'] ?? 'USD') == _currentCurrency);
    double accountsTotal =
        currentAccounts.fold(0.0, (sum, a) => sum + (a['balance'] as double));

    if (currentAccounts.isNotEmpty &&
        (accountsTotal > 0 || currentAccounts.any((a) => (a['balance'] as double) != 0))) {
      return accountsTotal;
    }

    // Cash Flow from active transactions in current currency (Income minus Expenses)
    final netCashFlow = transactions
        .where((t) => t['isFuture'] != true && t['excludeFromExpenses'] != true)
        .fold(0.0, (sum, item) => sum + (item['amount'] as double));
    return netCashFlow;
  }

  // Positive sum of all spending in current currency
  double get totalSpendingAmount {
    return transactions
        .where((t) =>
            (t['amount'] as double) < 0 &&
            !(t['isFuture'] == true) &&
            t['excludeFromExpenses'] != true)
        .fold(0.0, (sum, t) => sum + (t['amount'] as double).abs());
  }

  // Positive sum of spending recorded for today
  double get todaySpendingAmount => getSpendingForTimeframe('Today');

  // Positive sum of spending recorded for this week (from Monday to now)
  double get weekSpendingAmount => getSpendingForTimeframe('Week');

  // Positive sum of spending recorded for this month
  double get monthSpendingAmount => getSpendingForTimeframe('Month');

  // Helper to get spending for a given timeframe: 'Today', 'Week', 'Month', 'All'
  double getSpendingForTimeframe(String timeframe) {
    return getTransactionsForTimeframe(timeframe)
        .fold(0.0, (sum, t) => sum + (t['amount'] as double).abs());
  }

  // Filter expense transactions for a given timeframe
  List<Map<String, dynamic>> getTransactionsForTimeframe(String timeframe) {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    return transactions.where((t) {
      if ((t['amount'] as double) >= 0) return false;
      if (t['isFuture'] == true) return false;
      if (t['excludeFromExpenses'] == true) return false;
      if (t['date'] == null) return false;
      final date = t['date'] is DateTime
          ? t['date'] as DateTime
          : DateTime.tryParse(t['date'].toString());
      if (date == null) return false;

      switch (timeframe) {
        case 'Today':
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        case 'Week':
          return date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
              date.isBefore(now.add(const Duration(days: 1)));
        case 'Month':
          return date.year == now.year && date.month == now.month;
        case 'All':
        default:
          return true;
      }
    }).toList();
  }

  // Category breakdown for a given timeframe
  Map<String, double> getCategorySpendingForTimeframe(String timeframe) {
    final Map<String, double> data = {};
    for (var t in getTransactionsForTimeframe(timeframe)) {
      final cat = t['category']?.toString() ?? 'Other';
      data[cat] = (data[cat] ?? 0.0) + (t['amount'] as double).abs();
    }
    return data;
  }

  // Check whether any positive income transaction exists
  bool get hasIncomeRecorded {
    return transactions.any((t) =>
        (t['amount'] as double) > 0 && !(t['isFuture'] == true));
  }

  double get totalIncome {
    // Only include past/present transactions in current currency
    return transactions
        .where((t) => (t['amount'] as double) > 0 && !(t['isFuture'] == true))
        .fold(0.0, (sum, t) => sum + (t['amount'] as double));
  }

  double get totalExpense {
    // Only include past/present transactions, exclude 'excludeFromExpenses'
    return transactions
        .where((t) =>
            (t['amount'] as double) < 0 &&
            !(t['isFuture'] == true) &&
            t['excludeFromExpenses'] != true)
        .fold(0.0, (sum, t) => sum + (t['amount'] as double));
  }

  // [NEW] Future Payments
  List<Map<String, dynamic>> get futureTransactions {
    return transactions.where((t) {
      return t['isFuture'] == true;
    }).toList();
  }

  // [NEW] Get Active Transactions (Completed)
  List<Map<String, dynamic>> get activeTransactions {
    return transactions.where((t) => t['isFuture'] != true).toList();
  }

  Map<String, double> get spendingByCategory {
    final Map<String, double> data = {};
    for (var t in transactions) {
      if ((t['amount'] as double) < 0 && t['excludeFromExpenses'] != true) {
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

  void addTransaction(String title, double amount, String category,
      {DateTime? date,
      bool isFuture = false,
      String? linkedNoteId,
      String? groupId,
      bool excludeFromExpenses = false,
      String? currency}) {
    _transactions.insert(0, {
      'id': const Uuid().v4(),
      'title': title,
      'amount': amount,
      'currency': (currency ?? _currentCurrency).toUpperCase(),
      'date':
          (date ?? DateTime.now()).toString(), // Transaction Date (User Set)
      'addedDate':
          DateTime.now().toString(), // Actual Creation Date (System Set)
      'category': category,
      'isFuture': isFuture,
      'linkedNoteId': linkedNoteId,
      'groupId': groupId,
      'excludeFromExpenses': excludeFromExpenses,
    });

    _save();
  }

  void editTransaction(String id, String title, double amount, String category,
      {DateTime? date,
      bool? isFuture,
      String? linkedNoteId,
      String? groupId,
      bool? excludeFromExpenses,
      String? currency}) {
    final index = _transactions.indexWhere((t) => t['id'] == id);
    if (index != -1) {
      _transactions[index] = {
        ..._transactions[index],
        'title': title,
        'amount': amount,
        'category': category,
        if (currency != null) 'currency': currency.toUpperCase(),
        if (date != null) 'date': date.toString(),
        if (isFuture != null) 'isFuture': isFuture,
        'linkedNoteId': linkedNoteId,
        'groupId': groupId,
        if (excludeFromExpenses != null)
          'excludeFromExpenses': excludeFromExpenses,
      };
      _save();
    }
  }

  void markAsPaid(String id) {
    final index = _transactions.indexWhere((t) => t['id'] == id);
    if (index != -1) {
      _transactions[index] = {
        ..._transactions[index],
        'isFuture': false,
      };
      _save();
    }
  }

  void togglePin(String id) {
    final index = _transactions.indexWhere((t) => t['id'] == id);
    if (index != -1) {
      final currentPin = _transactions[index]['isPinned'] == true;
      _transactions[index] = {
        ..._transactions[index],
        'isPinned': !currentPin,
      };
      _save();
    }
  }

  void removeTransactionById(String id) {
    _transactions.removeWhere((t) => t['id'] == id);
    _save();
  }

  void removeTransactions(Iterable<String> ids) {
    final idSet = ids.toSet();
    _transactions.removeWhere((t) => idSet.contains(t['id']));
    _save();
  }

  void restoreTransaction(Map<String, dynamic> tx, {int? index}) {
    if (index != null && index >= 0 && index <= _transactions.length) {
      _transactions.insert(index, Map<String, dynamic>.from(tx));
    } else {
      _transactions.insert(0, Map<String, dynamic>.from(tx));
    }
    _save();
  }

  void restoreTransactions(List<Map<String, dynamic>> txs) {
    for (var tx in txs) {
      if (!_transactions.any((t) => t['id'] == tx['id'])) {
        _transactions.insert(0, Map<String, dynamic>.from(tx));
      }
    }
    _save();
  }

  void batchUpdateCategory(Iterable<String> ids, String newCategory) {
    final idSet = ids.toSet();
    for (int i = 0; i < _transactions.length; i++) {
      if (idSet.contains(_transactions[i]['id'])) {
        _transactions[i] = {
          ..._transactions[i],
          'category': newCategory,
        };
      }
    }
    _save();
  }

  int batchUpdateDatesYear(int oldYear, int newYear) {
    int updatedCount = 0;
    for (int i = 0; i < _transactions.length; i++) {
      final dateStr = _transactions[i]['date']?.toString();
      if (dateStr != null) {
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null && parsed.year == oldYear) {
          final updatedDate = DateTime(
            newYear,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
          );
          _transactions[i] = {
            ..._transactions[i],
            'date': updatedDate.toString(),
          };
          updatedCount++;
        }
      }
    }
    if (updatedCount > 0) {
      _save();
    }
    return updatedCount;
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

  void addGoalDeposit(String goalId, double amount) {
    final idx = _savingsGoals.indexWhere((g) => g['id'] == goalId);
    if (idx != -1) {
      double current = (_savingsGoals[idx]['currentAmount'] as num?)?.toDouble() ?? 0.0;
      _savingsGoals[idx]['currentAmount'] = current + amount;
      _saveSettings();
    }
  }

  void deleteSavingsGoal(String goalId) {
    _savingsGoals.removeWhere((g) => g['id'] == goalId);
    _saveSettings();
  }

  void updateBudget(String category, double amount) {
    _budgets[category] = amount;
    _budgetsByCurrency[_currentCurrency] = Map<String, double>.from(_budgets);
    _saveSettings();
  }

  void removeBudget(String category) {
    _budgets.remove(category);
    _budgetsByCurrency[_currentCurrency] = Map<String, double>.from(_budgets);
    _saveSettings();
  }

  void _saveSettings() {
    StorageService.saveMoneySettings({
      'totalSavings': _totalSavings,
      'isSavingsVisible': _isSavingsVisible,
      'budgets': _budgets,
      'budgetsByCurrency': _budgetsByCurrency,
      'goals': _savingsGoals,
      'accounts': _accounts, // Persist accounts
      'groups': _groups, // Persist spending groups
    });
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _transactions = [];
    _totalSavings = 0.0;
    _isSavingsVisible = true;
    _savingsGoals = [];
    _accounts = [];
    _groups = [];
    _budgets = {};
    _budgetsByCurrency = {};
    await StorageService.saveTransactions([]);
    await StorageService.saveMoneySettings({
      'totalSavings': 0.0,
      'isSavingsVisible': true,
      'budgets': {},
      'budgetsByCurrency': {},
      'goals': [],
      'accounts': [],
      'groups': [],
    });
    await StorageService.setMoneyInitialized(true);
    notifyListeners();
  }
}

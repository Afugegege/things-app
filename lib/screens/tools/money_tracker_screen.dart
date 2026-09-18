import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/money_provider.dart';

class MoneyTrackerScreen extends StatefulWidget {
  const MoneyTrackerScreen({super.key});

  @override
  State<MoneyTrackerScreen> createState() => _MoneyTrackerScreenState();
}

class _MoneyTrackerScreenState extends State<MoneyTrackerScreen> {
  int _selectedIndex = 0; // 0 = Ledger, 1 = Accounts, 2 = Overview, 3 = Groups
  String _summaryPeriod = 'Daily'; // [NEW] For Overview filtering

  // Group detail view state
  String? _viewingGroupId;

  Future<void> _exportCSV() async {
    final provider = Provider.of<MoneyProvider>(context, listen: false);
    final txs = provider.transactions;

    // 1. Create CSV String
    StringBuffer csv = StringBuffer();
    csv.writeln("Date,Title,Category,Amount"); // Header

    for (var t in txs) {
      String date = t['date'].toString().split('.')[0];
      String title = (t['title'] ?? '').replaceAll(',', ' '); // sanitize
      String cat = t['category'] ?? 'General';
      String amt = t['amount'].toString();
      csv.writeln("$date,$title,$cat,$amt");
    }

    try {
      // WEB SAFE EXPORT
      final XFile file = XFile.fromData(utf8.encode(csv.toString()),
          mimeType: 'text/csv', name: 'transactions_export.csv');

      await Share.shareXFiles([file], text: 'My Finance Transactions');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error exporting: $e"), backgroundColor: Colors.red));
    }
  }

  void _addTransaction(BuildContext context, bool isExpense) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController amountCtrl = TextEditingController();

    // Default categories matching your Wallet Screen
    String selectedCategory = isExpense ? 'Food' : 'Income';
    final List<String> expenseCategories = [
      'Food',
      'Transport',
      'Shopping',
      'Entertainment',
      'Health',
      'Other'
    ];

    // Group selection
    final moneyProvider = Provider.of<MoneyProvider>(context, listen: false);
    String? selectedGroupId;
    bool excludeFromExpenses = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: Text(isExpense ? "Add Expense" : "Add Income",
              style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        hintText: "Title",
                        hintStyle: TextStyle(color: Colors.white38))),
                TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        hintText: "Amount",
                        hintStyle: TextStyle(color: Colors.white38))),
                const SizedBox(height: 20),

                // Only show category dropdown for expenses
                if (isExpense) ...[
                  const Text("Category",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 5),
                  DropdownButton<String>(
                    value: selectedCategory,
                    dropdownColor: const Color(0xFF2C2C2E),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white),
                    underline: Container(height: 1, color: Colors.white24),
                    items: expenseCategories.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() => selectedCategory = newValue!);
                    },
                  ),
                ],

                // Group selector
                if (isExpense && moneyProvider.groups.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  const Text("Group (optional)",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 5),
                  DropdownButton<String?>(
                    value: selectedGroupId,
                    dropdownColor: const Color(0xFF2C2C2E),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white),
                    underline: Container(height: 1, color: Colors.white24),
                    hint: const Text("None",
                        style: TextStyle(color: Colors.white38)),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text("None",
                            style: TextStyle(color: Colors.white54)),
                      ),
                      ...moneyProvider.groups.map((g) {
                        return DropdownMenuItem<String?>(
                          value: g['id'],
                          child: Text(
                              "${g['icon'] ?? ''} ${g['name']}"),
                        );
                      }),
                    ],
                    onChanged: (v) {
                      setState(() => selectedGroupId = v);
                    },
                  ),
                ],

                // Exclude from expenses toggle
                if (isExpense) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () =>
                        setState(() => excludeFromExpenses = !excludeFromExpenses),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: excludeFromExpenses
                            ? Colors.amber.withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: excludeFromExpenses
                              ? Colors.amber.withOpacity(0.4)
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            excludeFromExpenses
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: excludeFromExpenses
                                ? Colors.amber
                                : Colors.white38,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Not my expense",
                                  style: TextStyle(
                                    color: excludeFromExpenses
                                        ? Colors.amber
                                        : Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const Text(
                                  "Company, friend, or someone else paid",
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty && amountCtrl.text.isNotEmpty) {
                    final provider =
                        Provider.of<MoneyProvider>(context, listen: false);
                    double val = double.tryParse(amountCtrl.text) ?? 0.0;

                    // [FIX] Now passing the 3rd argument (category)
                    provider.addTransaction(titleCtrl.text,
                        isExpense ? -val : val, selectedCategory,
                        groupId: selectedGroupId,
                        excludeFromExpenses: excludeFromExpenses);

                    Navigator.pop(ctx);
                  }
                },
                child: const Text("Add", style: TextStyle(color: Colors.amber)))
          ],
        ),
      ),
    );
  }



  IconData _getGroupIconData(String? iconName) {
    switch (iconName) {
      case 'trip':
      case 'travel':
      case 'vacation':
        return CupertinoIcons.airplane;
      case 'business':
      case 'work':
      case 'office':
        return CupertinoIcons.briefcase;
      case 'home':
      case 'house':
        return CupertinoIcons.house;
      case 'car':
      case 'auto':
        return CupertinoIcons.car_detailed;
      case 'cart':
      case 'shop':
        return CupertinoIcons.cart;
      case 'food':
      case 'dining':
        return Icons.restaurant_outlined;
      case 'event':
      case 'party':
        return CupertinoIcons.ticket;
      case 'health':
      case 'fitness':
        return CupertinoIcons.heart;
      case 'game':
      case 'play':
        return CupertinoIcons.game_controller;
      case 'study':
      case 'education':
        return CupertinoIcons.book;
      case 'tech':
      case 'device':
        return CupertinoIcons.device_laptop;
      default:
        return CupertinoIcons.folder;
    }
  }

  // --- CREATE GROUP DIALOG ---
  void _createGroupDialog(BuildContext context) {
    TextEditingController nameCtrl = TextEditingController();

    final List<Map<String, dynamic>> quickIcons = [
      {'id': 'trip', 'icon': CupertinoIcons.airplane},
      {'id': 'business', 'icon': CupertinoIcons.briefcase},
      {'id': 'home', 'icon': CupertinoIcons.house},
      {'id': 'car', 'icon': CupertinoIcons.car_detailed},
      {'id': 'cart', 'icon': CupertinoIcons.cart},
      {'id': 'food', 'icon': Icons.restaurant_outlined},
      {'id': 'event', 'icon': CupertinoIcons.ticket},
      {'id': 'health', 'icon': CupertinoIcons.heart},
      {'id': 'game', 'icon': CupertinoIcons.game_controller},
      {'id': 'study', 'icon': CupertinoIcons.book},
      {'id': 'tech', 'icon': CupertinoIcons.device_laptop},
      {'id': 'folder', 'icon': CupertinoIcons.folder},
    ];
    String selectedIcon = 'trip';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text("New Spending Group",
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    "Group transactions together for trips, projects, events, etc.",
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 15),
                TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        hintText: "Group Name (e.g. Japan Trip)",
                        hintStyle: TextStyle(color: Colors.white38))),
                const SizedBox(height: 15),
                const Text("Pick an icon",
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quickIcons.map((item) {
                    final isSelected = selectedIcon == item['id'];
                    return GestureDetector(
                      onTap: () => setState(() => selectedIcon = item['id']),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.amber.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: Colors.amber, width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Icon(
                            item['icon'] as IconData,
                            size: 20,
                            color: isSelected ? Colors.amber : Colors.white70,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel",
                    style: TextStyle(color: Colors.white54))),
            TextButton(
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty) {
                    Provider.of<MoneyProvider>(context, listen: false)
                        .addGroup(nameCtrl.text, selectedIcon);
                    Navigator.pop(ctx);
                  }
                },
                child:
                    const Text("Create", style: TextStyle(color: Colors.amber)))
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moneyProvider = Provider.of<MoneyProvider>(context);

    // SCREEN 1: LEDGER
    Widget buildLedger() {
      final balance = moneyProvider.balance;
      final transactions = moneyProvider.transactions;
      return Column(
        children: [
          // 1. HEADLINE BALANCE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.1)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text("Total Balance",
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => moneyProvider.toggleSavingsVisibility(),
                          child: Icon(
                              moneyProvider.isSavingsVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white38,
                              size: 16),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      moneyProvider.isSavingsVisible
                          ? "\$${balance.toStringAsFixed(2)}"
                          : "****",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                // MINI SPEND/EARN
                if (moneyProvider.isSavingsVisible)
                  Row(
                    children: [
                      _miniStat(moneyProvider.totalIncome, Colors.greenAccent,
                          Icons.arrow_upward),
                      const SizedBox(width: 15),
                      _miniStat(moneyProvider.totalExpense.abs(),
                          Colors.redAccent, Icons.arrow_downward),
                    ],
                  )
              ],
            ),
          ),

          // 2. ACTION BUTTONS (COMPACT)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2C2E),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () => _addTransaction(context, true),
                    icon: const Icon(Icons.remove,
                        size: 16, color: Colors.redAccent),
                    label: const Text("Expense",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2C2E),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () => _addTransaction(context, false),
                    icon: const Icon(Icons.add,
                        size: 16, color: Colors.greenAccent),
                    label: const Text("Income",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),

          // 3. TRANSACTION LIST
          Expanded(
            child: transactions.isEmpty
                ? const Center(
                    child: Text("No transactions yet.",
                        style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: transactions.length,
                    itemBuilder: (ctx, i) {
                      final tx = transactions[i];
                      final isNeg = (tx['amount'] as double) < 0;
                      final isExcluded = tx['excludeFromExpenses'] == true;
                      final groupName =
                          moneyProvider.getGroupName(tx['groupId']);
                      final groupIcon =
                          moneyProvider.getGroupIcon(tx['groupId']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2E),
                            borderRadius: BorderRadius.circular(16),
                            border: isExcluded
                                ? Border.all(
                                    color: Colors.amber.withOpacity(0.3))
                                : null),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: isExcluded
                                    ? Colors.amber.withOpacity(0.1)
                                    : (isNeg ? Colors.red : Colors.green)
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12)),
                            child: isExcluded
                                ? const Icon(Icons.person_off,
                                    color: Colors.amber, size: 20)
                                : Icon(
                                    isNeg
                                        ? Icons.shopping_bag_outlined
                                        : Icons.attach_money,
                                    color: isNeg
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
                                    size: 20),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(tx['title'],
                                    style: TextStyle(
                                        color: isExcluded
                                            ? Colors.white54
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        decoration: isExcluded
                                            ? TextDecoration.lineThrough
                                            : null)),
                              ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              Text(tx['category'] ?? 'General',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 12)),
                              if (groupName != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_getGroupIconData(groupIcon),
                                          size: 10, color: Colors.white54),
                                      const SizedBox(width: 4),
                                      Text(
                                        groupName,
                                        style: const TextStyle(
                                            color: Colors.white54, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (isExcluded) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "excluded",
                                    style: TextStyle(
                                        color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: Text(
                            "${isNeg ? '' : '+'}\$${tx['amount'].abs().toStringAsFixed(2)}",
                            style: TextStyle(
                                color: isExcluded
                                    ? Colors.white38
                                    : isNeg
                                        ? Colors.white
                                        : Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                decoration: isExcluded
                                    ? TextDecoration.lineThrough
                                    : null),
                          ),
                        ),
                      );
                    }),
          ),
        ],
      );
    }

    // SCREEN 3: ASSETS / ACCOUNTS (Savings Module)
    Widget buildAccounts() {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("MY ASSETS",
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.amber),
                onPressed: () => _addAccountDialog(context),
              )
            ],
          ),
          const SizedBox(height: 15),
          ...moneyProvider.accounts.map((acc) {
            final Color textColor = acc['type'] == 'Bank'
                ? Colors.blueAccent
                : acc['type'] == 'Wallet'
                    ? Colors.orangeAccent
                    : acc['type'] == 'Invest'
                        ? Colors.purpleAccent
                        : Colors.greenAccent;
            return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05))),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: textColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16)),
                      child: Icon(
                        acc['type'] == 'Bank'
                            ? Icons.account_balance
                            : acc['type'] == 'Wallet'
                                ? Icons.account_balance_wallet
                                : acc['type'] == 'Invest'
                                    ? Icons.trending_up
                                    : Icons.money,
                        color: textColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(acc['name'],
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text(acc['type'],
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _updateAccountDialog(context, acc),
                      child: Text(
                          "\$${(acc['balance'] as double).toStringAsFixed(2)}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
          }),
          if (moneyProvider.accounts.isEmpty)
            const Center(
                child: Text("Add your savings accounts here.",
                    style: TextStyle(color: Colors.white38))),
        ],
      );
    }

    // SCREEN 2: OVERVIEW (Formerly Insights) WITH SUMMARY
    Widget buildOverview() {
      final summary = moneyProvider.getSpendSummary(_summaryPeriod);

      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. SPEND SUMMARY CHART
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Spending Summary",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    DropdownButton<String>(
                        value: _summaryPeriod,
                        dropdownColor: const Color(0xFF3C3C3E),
                        underline: Container(),
                        style: const TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold),
                        items: ['Daily', 'Weekly', 'Monthly']
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _summaryPeriod = v!))
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 150,
                  child: summary.isEmpty
                      ? const Center(
                          child: Text("No data for this period",
                              style: TextStyle(color: Colors.white38)))
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: summary.entries.map((e) {
                            // Simple Bar Logic
                            double max =
                                summary.values.reduce((a, b) => a > b ? a : b);
                            double h = (e.value / max) * 100;
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: 30,
                                  height: h + 10,
                                  decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                const SizedBox(height: 5),
                                Text(e.key,
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 10))
                              ],
                            );
                          }).toList(),
                        ),
                )
              ],
            ),
          ),

          const SizedBox(height: 25),

          // SMART ADVICE CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text("AI Insight",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  moneyProvider.getSmartAdvice(),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),
          const Text("DAILY BUDGETS",
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 15),

          // CATEGORY LIST GRID
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15),
            itemCount: moneyProvider.budgets.length,
            itemBuilder: (ctx, i) {
              String cat = moneyProvider.budgets.keys.elementAt(i);
              double budget = moneyProvider.budgets[cat]!;
              double daily = moneyProvider.getDailyBudget(cat);
              double spent = moneyProvider.getSpentForCategory(cat);
              double progress = (spent / budget).clamp(0.0, 1.0);

              return GestureDetector(
                onTap: () => _editBudgetDialog(context, cat, budget),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(cat,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => moneyProvider.removeBudget(cat),
                                child: const Icon(CupertinoIcons.xmark_circle,
                                    size: 16, color: Colors.white54),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.edit,
                                  size: 14, color: Colors.white24),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("\$${daily.toStringAsFixed(0)} / day",
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white10,
                              color: progress > 0.9
                                  ? Colors.red
                                  : Colors.white),
                          const SizedBox(height: 5),
                          Text("${(progress * 100).toStringAsFixed(0)}% Used",
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10)),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 25),

          // GOALS SECTION
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("SAVINGS TARGETS",
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              IconButton(
                  icon:
                      const Icon(Icons.add_circle, color: Colors.purpleAccent),
                  onPressed: () => _addGoalDialog(context))
            ],
          ),

          if (moneyProvider.savingsGoals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text("No savings goals yet. Add one!",
                  style: TextStyle(
                      color: Colors.white38, fontStyle: FontStyle.italic)),
            ),

          ...moneyProvider.savingsGoals.map((g) => Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.purpleAccent.withOpacity(0.3))),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.purpleAccent.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.flag, color: Colors.purpleAccent),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g['title'],
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 5),
                        Text("Target: \$${g['targetAmount']}",
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    const Spacer(),
                    Text("by ${g['deadline'].toString().split(' ')[0]}",
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ))
        ],
      );
    }

    // SCREEN 4: GROUPS
    Widget buildGroups() {
      // If viewing a specific group, show the detail view
      if (_viewingGroupId != null) {
        return _buildGroupDetail(moneyProvider, _viewingGroupId!);
      }

      final groups = moneyProvider.groups;

      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("SPENDING GROUPS",
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.amber),
                onPressed: () => _createGroupDialog(context),
              )
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Organize spending by trips, projects, or events. Toggle expenses as not yours to exclude from totals.",
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 20),

          if (groups.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Icon(Icons.folder_outlined,
                        size: 56, color: Colors.white.withOpacity(0.15)),
                    const SizedBox(height: 16),
                    const Text("No groups yet",
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text("Tap + to create your first spending group",
                        style: TextStyle(color: Colors.white24, fontSize: 12)),
                  ],
                ),
              ),
            ),

          ...groups.map((group) {
            final groupId = group['id'] as String;
            final txCount = moneyProvider.getGroupTransactionCount(groupId);
            final total = moneyProvider.getGroupTotal(groupId);
            final personal = moneyProvider.getGroupPersonalTotal(groupId);
            final excluded = total - personal;

            return GestureDetector(
              onTap: () => setState(() => _viewingGroupId = groupId),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Icon(
                              _getGroupIconData(group['icon']),
                              size: 24,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(group['name'],
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17)),
                              const SizedBox(height: 3),
                              Text(
                                  "$txCount transaction${txCount == 1 ? '' : 's'}",
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Colors.white24, size: 22),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Spend breakdown bar
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Total",
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 10)),
                                Text("\$${total.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ],
                            ),
                          ),
                          Container(
                              width: 1,
                              height: 30,
                              color: Colors.white.withOpacity(0.1)),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("My expense",
                                      style: TextStyle(
                                          color: Colors.white38, fontSize: 10)),
                                  Text("\$${personal.toStringAsFixed(0)}",
                                      style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                          if (excluded > 0) ...[
                            Container(
                                width: 1,
                                height: 30,
                                color: Colors.white.withOpacity(0.1)),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Excluded",
                                        style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 10)),
                                    Text("\$${excluded.toStringAsFixed(0)}",
                                        style: const TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: _viewingGroupId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _viewingGroupId = null),
              )
            : null,
        title: Text(
            _viewingGroupId != null
                ? moneyProvider.getGroupName(_viewingGroupId) ?? "Group"
                : _selectedIndex == 0
                    ? "Ledger"
                    : _selectedIndex == 1
                        ? "Assets"
                        : _selectedIndex == 2
                            ? "Overview"
                            : "Groups",
            style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _exportCSV,
            tooltip: "Export CSV",
          )
        ],
      ),
      body: _selectedIndex == 0
          ? buildLedger()
          : _selectedIndex == 1
              ? buildAccounts()
              : _selectedIndex == 2
                  ? buildOverview()
                  : buildGroups(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() {
          _selectedIndex = i;
          if (i != 3) _viewingGroupId = null; // Reset group detail when switching tabs
        }),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1C1C1E),
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.white38,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "Ledger"),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: "Assets"),
          BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart), label: "Overview"),
          BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined), label: "Groups"),
        ],
      ),
    );
  }

  // --- GROUP DETAIL VIEW ---
  Widget _buildGroupDetail(MoneyProvider provider, String groupId) {
    final transactions = provider.getTransactionsForGroup(groupId);
    final total = provider.getGroupTotal(groupId);
    final personal = provider.getGroupPersonalTotal(groupId);
    final excluded = total - personal;
    final group = provider.groups.firstWhere((g) => g['id'] == groupId,
        orElse: () => {'name': 'Unknown', 'icon': 'folder'});

    return Column(
      children: [
        // Group summary header
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.amber.withOpacity(0.15),
                Colors.orange.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amber.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(
                _getGroupIconData(group['icon']),
                size: 40,
                color: Colors.amber,
              ),
              const SizedBox(height: 10),
              Text(
                group['name'],
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _groupStatColumn("Total", total, Colors.white),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.15)),
                  _groupStatColumn("My Expense", personal, Colors.redAccent),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.15)),
                  _groupStatColumn("Excluded", excluded, Colors.amber),
                ],
              ),
            ],
          ),
        ),

        // Add transaction to group button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C2C2E),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _addTransactionToGroup(context, groupId),
              icon: const Icon(Icons.add, size: 18, color: Colors.amber),
              label: const Text("Add Expense to Group",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Transaction list with exclude toggles
        Expanded(
          child: transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long,
                          size: 48, color: Colors.white.withOpacity(0.12)),
                      const SizedBox(height: 12),
                      const Text("No transactions in this group",
                          style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: transactions.length,
                  itemBuilder: (ctx, i) {
                    final tx = transactions[i];
                    final isNeg = (tx['amount'] as double) < 0;
                    final isExcluded = tx['excludeFromExpenses'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(16),
                        border: isExcluded
                            ? Border.all(color: Colors.amber.withOpacity(0.3))
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Left: transaction info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx['title'],
                                    style: TextStyle(
                                      color: isExcluded
                                          ? Colors.white54
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      decoration: isExcluded
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        tx['category'] ?? 'General',
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "\$${(tx['amount'] as double).abs().toStringAsFixed(2)}",
                                        style: TextStyle(
                                          color: isExcluded
                                              ? Colors.white38
                                              : Colors.white70,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          decoration: isExcluded
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Right: exclude toggle button
                            GestureDetector(
                              onTap: () =>
                                  provider.toggleExcludeFromExpenses(tx['id']),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isExcluded
                                      ? Colors.amber.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isExcluded
                                        ? Colors.amber.withOpacity(0.5)
                                        : Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isExcluded
                                          ? Icons.person_off
                                          : Icons.person,
                                      size: 16,
                                      color: isExcluded
                                          ? Colors.amber
                                          : Colors.white38,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isExcluded ? "Not mine" : "My expense",
                                      style: TextStyle(
                                        color: isExcluded
                                            ? Colors.amber
                                            : Colors.white54,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Delete group button at bottom
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1C1C1E),
                  title: const Text("Delete Group?",
                      style: TextStyle(color: Colors.white)),
                  content: const Text(
                      "Transactions will be unlinked but not deleted.",
                      style: TextStyle(color: Colors.white54)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel",
                            style: TextStyle(color: Colors.white54))),
                    TextButton(
                        onPressed: () {
                          provider.removeGroup(groupId);
                          Navigator.pop(ctx);
                          setState(() => _viewingGroupId = null);
                        },
                        child: const Text("Delete",
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            label:
                const Text("Delete Group", style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }

  Widget _groupStatColumn(String label, double value, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 4),
        Text("\$${value.toStringAsFixed(0)}",
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }

  // Quick add transaction directly to a group
  void _addTransactionToGroup(BuildContext context, String groupId) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController amountCtrl = TextEditingController();
    String selectedCategory = 'Food';
    bool excludeFromExpenses = false;

    final List<String> expenseCategories = [
      'Food', 'Transport', 'Shopping', 'Entertainment', 'Health', 'Other'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text("Add Group Expense",
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        hintText: "Title",
                        hintStyle: TextStyle(color: Colors.white38))),
                TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        hintText: "Amount",
                        hintStyle: TextStyle(color: Colors.white38))),
                const SizedBox(height: 15),
                const Text("Category",
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 5),
                DropdownButton<String>(
                  value: selectedCategory,
                  dropdownColor: const Color(0xFF2C2C2E),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white),
                  underline: Container(height: 1, color: Colors.white24),
                  items: expenseCategories.map((String value) {
                    return DropdownMenuItem<String>(
                        value: value, child: Text(value));
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() => selectedCategory = newValue!);
                  },
                ),
                const SizedBox(height: 12),
                // Exclude toggle
                GestureDetector(
                  onTap: () =>
                      setState(() => excludeFromExpenses = !excludeFromExpenses),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: excludeFromExpenses
                          ? Colors.amber.withOpacity(0.15)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: excludeFromExpenses
                            ? Colors.amber.withOpacity(0.4)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          excludeFromExpenses
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: excludeFromExpenses
                              ? Colors.amber
                              : Colors.white38,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Not my expense",
                                style: TextStyle(
                                  color: excludeFromExpenses
                                      ? Colors.amber
                                      : Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const Text(
                                "Company, friend, or someone else paid",
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel",
                    style: TextStyle(color: Colors.white54))),
            TextButton(
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty && amountCtrl.text.isNotEmpty) {
                    double val = double.tryParse(amountCtrl.text) ?? 0.0;
                    Provider.of<MoneyProvider>(context, listen: false)
                        .addTransaction(
                      titleCtrl.text,
                      -val,
                      selectedCategory,
                      groupId: groupId,
                      excludeFromExpenses: excludeFromExpenses,
                    );
                    Navigator.pop(ctx);
                  }
                },
                child:
                    const Text("Add", style: TextStyle(color: Colors.amber))),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(double val, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        Text("\$${val.toStringAsFixed(0)}",
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12))
      ],
    );
  }

  void _addGoalDialog(BuildContext context) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController targetCtrl = TextEditingController();

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              title: const Text("New Savings Goal",
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          hintText: "Goal Name (e.g. Trip)",
                          hintStyle: TextStyle(color: Colors.white38))),
                  TextField(
                      controller: targetCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          hintText: "Target Amount",
                          hintStyle: TextStyle(color: Colors.white38))),
                  const SizedBox(height: 10),
                  const Text("Deadline: End of Year (Auto)",
                      style: TextStyle(color: Colors.white38, fontSize: 10))
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      if (titleCtrl.text.isNotEmpty &&
                          targetCtrl.text.isNotEmpty) {
                        Provider.of<MoneyProvider>(context, listen: false)
                            .addSavingsGoal(
                                titleCtrl.text,
                                double.tryParse(targetCtrl.text) ?? 0.0,
                                DateTime(DateTime.now().year, 12,
                                    31) // Default to End of Year
                                );
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text("Add",
                        style: TextStyle(color: Colors.purpleAccent)))
              ],
            ));
  }

  // --- ACCOUNT DIALOGS ---

  void _addAccountDialog(BuildContext context) {
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController balCtrl = TextEditingController();
    String type = 'Bank';

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                  backgroundColor: const Color(0xFF1C1C1E),
                  title: const Text("Add Asset Account",
                      style: TextStyle(color: Colors.white)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                          controller: nameCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                              hintText: "Account Name (e.g. Chase)",
                              hintStyle: TextStyle(color: Colors.white38))),
                      const SizedBox(height: 10),
                      TextField(
                          controller: balCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                              hintText: "Current Balance",
                              hintStyle: TextStyle(color: Colors.white38))),
                      const SizedBox(height: 15),
                      DropdownButton<String>(
                          value: type,
                          dropdownColor: const Color(0xFF2C2C2E),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white),
                          items: ['Bank', 'Wallet', 'Cash', 'Invest']
                              .map((t) =>
                                  DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setState(() => type = v!))
                    ],
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel")),
                    TextButton(
                        onPressed: () {
                          if (nameCtrl.text.isNotEmpty) {
                            Provider.of<MoneyProvider>(context, listen: false)
                                .addAccount(nameCtrl.text, type,
                                    double.tryParse(balCtrl.text) ?? 0.0);
                            Navigator.pop(ctx);
                          }
                        },
                        child: const Text("Add",
                            style: TextStyle(color: Colors.amber)))
                  ],
                )));
  }

  void _updateAccountDialog(BuildContext context, Map<String, dynamic> acc) {
    TextEditingController nameCtrl = TextEditingController(text: acc['name']);
    TextEditingController balCtrl =
        TextEditingController(text: (acc['balance'] as double).toString());

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              title: Text("Edit ${acc['name']}",
                  style: const TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Name")),
                  TextField(
                      controller: balCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Balance")),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      Provider.of<MoneyProvider>(context, listen: false)
                          .removeAccount(acc['id']);
                      Navigator.pop(ctx);
                    },
                    child: const Text("Delete",
                        style: TextStyle(color: Colors.red))),
                TextButton(
                    onPressed: () {
                      Provider.of<MoneyProvider>(context, listen: false)
                          .updateAccount(acc['id'], nameCtrl.text,
                              double.tryParse(balCtrl.text) ?? 0.0);
                      Navigator.pop(ctx);
                    },
                    child: const Text("Save",
                        style: TextStyle(color: Colors.amber)))
              ],
            ));
  }

  void _editBudgetDialog(
      BuildContext context, String category, double currentLimit) {
    TextEditingController limitCtrl =
        TextEditingController(text: currentLimit.toString());

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              title: Text("Budget for $category",
                  style: const TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      "Set your monthly spending limit for this category.",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 15),
                  TextField(
                      controller: limitCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          hintText: "Monthly Limit",
                          hintStyle: TextStyle(color: Colors.white38),
                          prefixText: "\$ ",
                          prefixStyle: TextStyle(color: Colors.white))),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel",
                        style: TextStyle(color: Colors.white54))),
                TextButton(
                    onPressed: () {
                      double val =
                          double.tryParse(limitCtrl.text) ?? currentLimit;
                      Provider.of<MoneyProvider>(context, listen: false)
                          .updateBudget(category, val);
                      Navigator.pop(ctx);
                    },
                    child: const Text("Save",
                        style: TextStyle(color: Colors.amber)))
              ],
            ));
  }
}

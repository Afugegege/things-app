import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/money_provider.dart';

class MoneyTrackerScreen extends StatefulWidget {
  const MoneyTrackerScreen({super.key});

  @override
  State<MoneyTrackerScreen> createState() => _MoneyTrackerScreenState();
}

class _MoneyTrackerScreenState extends State<MoneyTrackerScreen> {

  void _addTransaction(BuildContext context, bool isExpense) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController amountCtrl = TextEditingController();
    
    // Default categories matching your Wallet Screen
    String selectedCategory = isExpense ? 'Food' : 'Income';
    final List<String> expenseCategories = ['Food', 'Transport', 'Shopping', 'Entertainment', 'Health', 'Other'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: Text(isExpense ? "Add Expense" : "Add Income", style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleCtrl, 
                style: const TextStyle(color: Colors.white), 
                decoration: const InputDecoration(hintText: "Title", hintStyle: TextStyle(color: Colors.white38))
              ),
              TextField(
                controller: amountCtrl, 
                keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                style: const TextStyle(color: Colors.white), 
                decoration: const InputDecoration(hintText: "Amount", hintStyle: TextStyle(color: Colors.white38))
              ),
              const SizedBox(height: 20),
              
              // Only show category dropdown for expenses
              if (isExpense) ...[
                const Text("Category", style: TextStyle(color: Colors.white54, fontSize: 12)),
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
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                if (titleCtrl.text.isNotEmpty && amountCtrl.text.isNotEmpty) {
                  final provider = Provider.of<MoneyProvider>(context, listen: false);
                  double val = double.tryParse(amountCtrl.text) ?? 0.0;
                  
                  // [FIX] Now passing the 3rd argument (category)
                  provider.addTransaction(
                    titleCtrl.text, 
                    isExpense ? -val : val,
                    selectedCategory
                  );
                  
                  Navigator.pop(ctx);
                }
              }, 
              child: const Text("Add", style: TextStyle(color: Colors.amber))
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moneyProvider = Provider.of<MoneyProvider>(context);
    final balance = moneyProvider.balance;
    final transactions = moneyProvider.transactions;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Money Tracker", style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // BALANCE CARD
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)]),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 20)],
            ),
            child: Column(
              children: [
                const Text("Total Balance", style: TextStyle(color: Colors.white70)),
                Text(
                  "\$${balance.toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // ACTION BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                onPressed: () => _addTransaction(context, true),
                icon: const Icon(Icons.remove, color: Colors.white),
                label: const Text("Expense", style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                onPressed: () => _addTransaction(context, false),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Income", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // HISTORY LIST
          Expanded(
            child: ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                final isNeg = (tx['amount'] as double) < 0;
                final cat = tx['category'] ?? 'General';
                
                return Dismissible(
                  key: UniqueKey(),
                  onDismissed: (_) => moneyProvider.removeTransaction(index),
                  background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isNeg ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                      child: Icon(
                        isNeg ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isNeg ? Colors.red : Colors.green,
                      ),
                    ),
                    title: Text(tx['title'], style: const TextStyle(color: Colors.white)),
                    subtitle: Text("$cat • ${tx['date'].toString().split(' ')[0]}", style: const TextStyle(color: Colors.white38)),
                    trailing: Text(
                      "${isNeg ? '' : '+'}${tx['amount']}",
                      style: TextStyle(color: isNeg ? Colors.white : Colors.greenAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
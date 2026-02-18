
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/money_provider.dart';

class MoneyTrackerScreen extends StatefulWidget {
  const MoneyTrackerScreen({super.key});

  @override
  State<MoneyTrackerScreen> createState() => _MoneyTrackerScreenState();
}

class _MoneyTrackerScreenState extends State<MoneyTrackerScreen> {
  int _selectedIndex = 0; // 0 = Ledger, 1 = Accounts, 2 = Overview
  String _summaryPeriod = 'Daily'; // [NEW] For Overview filtering

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
       final XFile file = XFile.fromData(
          utf8.encode(csv.toString()),
          mimeType: 'text/csv',
          name: 'transactions_export.csv'
       );
       
       await Share.shareXFiles([file], text: 'My Finance Transactions');
     } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error exporting: $e"), backgroundColor: Colors.red));
     }
  }

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

  void _updateSavingsDialog(BuildContext context, double currentSavings) {
    TextEditingController savingsCtrl = TextEditingController(text: currentSavings.toString());
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Set Savings", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Define your starting savings balance. Transactions will update the total available balance from this point.",
              style: TextStyle(color: Colors.white54, fontSize: 12)
            ),
            const SizedBox(height: 15),
            TextField(
              controller: savingsCtrl, 
              keyboardType: const TextInputType.numberWithOptions(decimal: true), 
              style: const TextStyle(color: Colors.white), 
              decoration: const InputDecoration(
                hintText: "Amount", 
                hintStyle: TextStyle(color: Colors.white38),
                prefixText: "\$ ",
                prefixStyle: TextStyle(color: Colors.white)
              )
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              double val = double.tryParse(savingsCtrl.text) ?? 0.0;
              Provider.of<MoneyProvider>(context, listen: false).updateSavings(val);
              Navigator.pop(ctx);
            }, 
            child: const Text("Save", style: TextStyle(color: Colors.purpleAccent))
          )
        ],
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
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1)))
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                      children: [
                        const Text("Total Balance", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => moneyProvider.toggleSavingsVisibility(),
                          child: Icon(
                            moneyProvider.isSavingsVisible ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white38,
                            size: 16
                          ),
                        )
                      ],
                     ),
                     const SizedBox(height: 4),
                     Text(
                       moneyProvider.isSavingsVisible ? "\$${balance.toStringAsFixed(2)}" : "****",
                       style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                     ),
                   ],
                 ),
                 // MINI SPEND/EARN
                 if (moneyProvider.isSavingsVisible)
                 Row(
                   children: [
                     _miniStat(moneyProvider.totalIncome, Colors.greenAccent, Icons.arrow_upward),
                     const SizedBox(width: 15),
                     _miniStat(moneyProvider.totalExpense.abs(), Colors.redAccent, Icons.arrow_downward),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: () => _addTransaction(context, true),
                      icon: const Icon(Icons.remove, size: 16, color: Colors.redAccent),
                      label: const Text("Expense", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2C2E), 
                        padding: const EdgeInsets.symmetric(vertical: 12),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: () => _addTransaction(context, false),
                      icon: const Icon(Icons.add, size: 16, color: Colors.greenAccent),
                      label: const Text("Income", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),

            // 3. TRANSACTION LIST
            Expanded(
              child: transactions.isEmpty 
               ? const Center(child: Text("No transactions yet.", style: TextStyle(color: Colors.white38)))
               : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: transactions.length,
                  itemBuilder: (ctx, i) {
                    final tx = transactions[i];
                    final isNeg = (tx['amount'] as double) < 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: (isNeg ? Colors.red : Colors.green).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(isNeg ? Icons.shopping_bag_outlined : Icons.attach_money, color: isNeg ? Colors.redAccent : Colors.greenAccent, size: 20),
                        ),
                        title: Text(tx['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(tx['category'] ?? 'General', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        trailing: Text(
                          "${isNeg ? '' : '+'}\$${tx['amount'].abs().toStringAsFixed(2)}",
                          style: TextStyle(color: isNeg ? Colors.white : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    );
                  }
               ),
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
               const Text("MY ASSETS", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
               IconButton(
                 icon: const Icon(Icons.add_circle, color: Colors.amber),
                 onPressed: () => _addAccountDialog(context),
               )
            ],
          ),
          const SizedBox(height: 15),
          ...moneyProvider.accounts.map((acc) => Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E), 
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05))
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (acc['type'] == 'Bank' ? Colors.blue : 
                           acc['type'] == 'Wallet' ? Colors.orange : 
                           acc['type'] == 'Invest' ? Colors.purple : Colors.green).withOpacity(0.2), 
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: Icon(
                    acc['type'] == 'Bank' ? Icons.account_balance : 
                    acc['type'] == 'Wallet' ? Icons.account_balance_wallet :
                    acc['type'] == 'Invest' ? Icons.trending_up : Icons.money, 
                    color: (acc['type'] == 'Bank' ? Colors.blueAccent : 
                           acc['type'] == 'Wallet' ? Colors.orangeAccent : 
                           acc['type'] == 'Invest' ? Colors.purpleAccent : Colors.greenAccent),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(acc['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(acc['type'], style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _updateAccountDialog(context, acc),
                  child: Text("\$${(acc['balance'] as double).toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )).toList(),
          
          if (moneyProvider.accounts.isEmpty)
             const Center(child: Text("Add your savings accounts here.", style: TextStyle(color: Colors.white38))),
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
                    const Text("Spending Summary", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    DropdownButton<String>(
                      value: _summaryPeriod,
                      dropdownColor: const Color(0xFF3C3C3E),
                      underline: Container(),
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                      items: ['Daily', 'Weekly', 'Monthly'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _summaryPeriod = v!)
                    )
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 150,
                  child: summary.isEmpty 
                    ? const Center(child: Text("No data for this period", style: TextStyle(color: Colors.white38)))
                    : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: summary.entries.map((e) {
                         // Simple Bar Logic
                         double max = summary.values.reduce((a, b) => a > b ? a : b);
                         double h = (e.value / max) * 100;
                         return Column(
                           mainAxisAlignment: MainAxisAlignment.end,
                           children: [
                             Container(
                               width: 30, height: h + 10,
                               decoration: BoxDecoration(
                                 color: Colors.redAccent.withOpacity(0.7),
                                 borderRadius: BorderRadius.circular(8)
                               ),
                             ),
                             const SizedBox(height: 5),
                             Text(e.key, style: const TextStyle(color: Colors.white38, fontSize: 10))
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
              gradient: const LinearGradient(colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text("AI Insight", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                 moneyProvider.getSmartAdvice(),
                 style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 25),
          const Text("DAILY BUDGETS", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 15),
          
          // CATEGORY LIST GRID
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              childAspectRatio: 1.3,
              crossAxisSpacing: 15, 
              mainAxisSpacing: 15
            ),
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
                   decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(20)),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(cat, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                           Icon(Icons.edit, size: 14, color: Colors.white24)
                         ],
                       ),
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text("\$${daily.toStringAsFixed(0)} / day", style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                         const SizedBox(height: 5),
                         LinearProgressIndicator(value: progress, backgroundColor: Colors.white10, color: progress > 0.9 ? Colors.red : Colors.blueAccent),
                         const SizedBox(height: 5),
                         Text("${(progress * 100).toStringAsFixed(0)}% Used", style: const TextStyle(color: Colors.white38, fontSize: 10)),
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
               const Text("SAVINGS TARGETS", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
               IconButton(
                 icon: const Icon(Icons.add_circle, color: Colors.purpleAccent), 
                 onPressed: () => _addGoalDialog(context)
               )
            ],
          ),
          
          if (moneyProvider.savingsGoals.isEmpty)
             const Padding(
               padding: EdgeInsets.all(20),
               child: Text("No savings goals yet. Add one!", style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic)),
             ),
             
          ...moneyProvider.savingsGoals.map((g) => Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E), 
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.flag, color: Colors.purpleAccent),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 5),
                    Text("Target: \$${g['targetAmount']}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                Text("by ${g['deadline'].toString().split(' ')[0]}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          )).toList()
          
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(_selectedIndex == 0 ? "Ledger" : _selectedIndex == 1 ? "Assets" : "Overview", style: const TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: _exportCSV,
              tooltip: "Export CSV",
            )
          ],
        ),
        body: _selectedIndex == 0 ? buildLedger() : _selectedIndex == 1 ? buildAccounts() : buildOverview(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: const Color(0xFF1C1C1E),
          selectedItemColor: Colors.amber,
          unselectedItemColor: Colors.white38,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "Ledger"),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: "Assets"),
            BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: "Overview"),
          ],
        ),
    );
  }

  
  Widget _miniStat(double val, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        Text("\$${val.toStringAsFixed(0)}", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))
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
          title: const Text("New Savings Goal", style: TextStyle(color: Colors.white)),
          content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Goal Name (e.g. Trip)", hintStyle: TextStyle(color: Colors.white38))),
               TextField(controller: targetCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Target Amount", hintStyle: TextStyle(color: Colors.white38))),
               const SizedBox(height: 10),
               const Text("Deadline: End of Year (Auto)", style: TextStyle(color: Colors.white38, fontSize: 10))
             ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (titleCtrl.text.isNotEmpty && targetCtrl.text.isNotEmpty) {
                   Provider.of<MoneyProvider>(context, listen: false).addSavingsGoal(
                     titleCtrl.text,
                     double.tryParse(targetCtrl.text) ?? 0.0,
                     DateTime(DateTime.now().year, 12, 31) // Default to End of Year
                   );
                   Navigator.pop(ctx);
                }
              }, 
              child: const Text("Add", style: TextStyle(color: Colors.purpleAccent))
            )
          ],
        )
      );
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
          title: const Text("Add Asset Account", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Account Name (e.g. Chase)", hintStyle: TextStyle(color: Colors.white38))),
              const SizedBox(height: 10),
              TextField(controller: balCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Current Balance", hintStyle: TextStyle(color: Colors.white38))),
              const SizedBox(height: 15),
              DropdownButton<String>(
                value: type,
                dropdownColor: const Color(0xFF2C2C2E),
                isExpanded: true,
                style: const TextStyle(color: Colors.white),
                items: ['Bank', 'Wallet', 'Cash', 'Invest'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => type = v!)
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            TextButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  Provider.of<MoneyProvider>(context, listen: false).addAccount(
                    nameCtrl.text, type, double.tryParse(balCtrl.text) ?? 0.0
                  );
                  Navigator.pop(ctx);
                }
              }, 
              child: const Text("Add", style: TextStyle(color: Colors.amber))
            )
          ],
        )
      )
    );
  }

  void _updateAccountDialog(BuildContext context, Map<String, dynamic> acc) {
    TextEditingController nameCtrl = TextEditingController(text: acc['name']);
    TextEditingController balCtrl = TextEditingController(text: (acc['balance'] as double).toString());
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text("Edit ${acc['name']}", style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: balCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Balance")),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Provider.of<MoneyProvider>(context, listen: false).removeAccount(acc['id']);
              Navigator.pop(ctx);
            }, 
            child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
          TextButton(
            onPressed: () {
              Provider.of<MoneyProvider>(context, listen: false).updateAccount(
                acc['id'], nameCtrl.text, double.tryParse(balCtrl.text) ?? 0.0
              );
              Navigator.pop(ctx);
            }, 
            child: const Text("Save", style: TextStyle(color: Colors.amber))
          )
        ],
      )
    );
  }

  void _editBudgetDialog(BuildContext context, String category, double currentLimit) {
    TextEditingController limitCtrl = TextEditingController(text: currentLimit.toString());
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text("Budget for $category", style: const TextStyle(color: Colors.white)),
        content: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             const Text("Set your monthly spending limit for this category.", style: TextStyle(color: Colors.white54, fontSize: 12)),
             const SizedBox(height: 15),
             TextField(
               controller: limitCtrl, 
               keyboardType: TextInputType.number, 
               style: const TextStyle(color: Colors.white), 
               decoration: const InputDecoration(
                 hintText: "Monthly Limit", 
                 hintStyle: TextStyle(color: Colors.white38),
                 prefixText: "\$ ",
                 prefixStyle: TextStyle(color: Colors.white)
               )
             ),
           ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Cancel", style: TextStyle(color: Colors.white54))
          ),
          TextButton(
            onPressed: () {
               double val = double.tryParse(limitCtrl.text) ?? currentLimit;
               Provider.of<MoneyProvider>(context, listen: false).updateBudget(category, val);
               Navigator.pop(ctx);
            }, 
            child: const Text("Save", style: TextStyle(color: Colors.amber))
          )
        ],
      )
    );
  }
}
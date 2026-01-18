import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/money_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/life_app_scaffold.dart';
import '../chat/chat_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _selectedGroupIndex = 0; 
  int _touchedIndex = -1; 

  // --- AI FEATURE ---
  void _askAiAdvisor(BuildContext context) {
    final moneyProvider = Provider.of<MoneyProvider>(context, listen: false);
    final spending = moneyProvider.spendingByCategory.toString();
    final balance = moneyProvider.balance.toStringAsFixed(2);
    final prompt = "Analyze my finances. Balance: \$$balance. Spending breakdown: $spending. Give me 3 minimalist tips to save money.";
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    chatProvider.sendMessage(
      message: prompt, 
      userMemories: userProvider.user.aiMemory, 
      mode: 'Finance'
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final moneyProvider = Provider.of<MoneyProvider>(context);
    // [THEME] Access Theme Data
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final iconColor = theme.iconTheme.color ?? textColor;

    return LifeAppScaffold(
      title: "WALLET",
      actions: [
        IconButton(
          icon: Icon(CupertinoIcons.chat_bubble_text, color: iconColor),
          onPressed: () => _askAiAdvisor(context),
        ),
      ],
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: FloatingActionButton(
          onPressed: () => _showTransactionSheet(context), 
          // [THEME] High contrast button
          backgroundColor: isDark ? Colors.white : Colors.black,
          elevation: 0,
          shape: const CircleBorder(),
          child: Icon(CupertinoIcons.add, color: isDark ? Colors.black : Colors.white, size: 28),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // BALANCE
          Column(
            children: [
              Text("TOTAL BALANCE", style: TextStyle(color: secondaryTextColor, fontSize: 12, letterSpacing: 2)),
              const SizedBox(height: 5),
              Text(
                "\$${moneyProvider.balance.toStringAsFixed(2)}", 
                style: TextStyle(color: textColor, fontSize: 48, fontWeight: FontWeight.w300, letterSpacing: -1)
              ),
            ],
          ),

          const SizedBox(height: 30),

          // SEGMENTED CONTROL
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                thumbColor: isDark ? Colors.white24 : Colors.white,
                groupValue: _selectedGroupIndex,
                children: {
                  0: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Text("Overview", style: TextStyle(color: textColor))),
                  1: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Text("Transactions", style: TextStyle(color: textColor))),
                },
                onValueChanged: (value) => setState(() => _selectedGroupIndex = value!),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // CONTENT
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedGroupIndex == 0 
                  ? _buildOverviewTab(moneyProvider) 
                  : _buildTransactionsTab(moneyProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(MoneyProvider provider) {
    // [THEME] Colors
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final isDark = theme.brightness == Brightness.dark;
    final trackColor = isDark ? Colors.white10 : Colors.black12;

    return ListView(
      key: const ValueKey(0),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        Row(
          children: [
            Expanded(child: _buildSummaryBox("INCOME", provider.totalIncome, Colors.greenAccent)),
            const SizedBox(width: 15),
            Expanded(child: _buildSummaryBox("EXPENSE", provider.totalExpense.abs(), textColor)),
          ],
        ),
        const SizedBox(height: 40),
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sectionsSpace: 4,
                  centerSpaceRadius: 60,
                  sections: _buildPieSections(provider),
                  borderData: FlBorderData(show: false),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("SPENT", style: TextStyle(color: secondaryTextColor, fontSize: 10)),
                  Text("\$${provider.totalExpense.abs().toStringAsFixed(0)}", style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 40),
        Text("BUDGETS", style: TextStyle(color: secondaryTextColor, fontSize: 12, letterSpacing: 2)),
        const SizedBox(height: 20),
        ...provider.budgets.entries.map((entry) {
          final spent = provider.getSpentForCategory(entry.key);
          final limit = entry.value;
          final pct = (spent / limit).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key, style: TextStyle(color: textColor, fontSize: 16)),
                    Text("\$${spent.toInt()} / \$${limit.toInt()}", style: TextStyle(color: secondaryTextColor, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: pct, minHeight: 2, backgroundColor: trackColor, color: textColor),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummaryBox(String label, double value, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12)
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: secondaryTextColor, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 5),
          Text("\$${value.toStringAsFixed(0)}", style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildTransactionsTab(MoneyProvider provider) {
    final theme = Theme.of(context);
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    if (provider.transactions.isEmpty) return Center(child: Text("No transactions.", style: TextStyle(color: secondaryTextColor)));
    
    return ListView.separated(
      key: const ValueKey(1),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: provider.transactions.length,
      separatorBuilder: (c, i) => Divider(color: theme.dividerColor, height: 1),
      itemBuilder: (context, index) {
        final tx = provider.transactions[index];
        final bool isExp = (tx['amount'] as double) < 0;
        final String cat = tx['category'] ?? 'General';
        
        // [THEME]
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final isDark = theme.brightness == Brightness.dark;
        final iconBg = isDark ? Colors.white10 : Colors.black12;

        return Dismissible(
          key: UniqueKey(),
          onDismissed: (_) => provider.removeTransaction(index),
          background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(CupertinoIcons.trash, color: Colors.red)),
          child: GestureDetector(
            // TAP TO EDIT
            onTap: () => _showTransactionSheet(context, existingTx: tx),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(_getCategoryIcon(cat), color: secondaryTextColor, size: 18),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx['title'], style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(tx['date'].toString().split(' ')[0], style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("${isExp ? '' : '+'}\$${tx['amount'].abs().toStringAsFixed(2)}", style: TextStyle(color: isExp ? textColor : Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(cat, style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- UNIFIED ADD/EDIT SHEET ---
  void _showTransactionSheet(BuildContext context, {Map<String, dynamic>? existingTx}) {
    final isEditing = existingTx != null;
    final titleCtrl = TextEditingController(text: isEditing ? existingTx['title'] : "");
    final amountCtrl = TextEditingController(text: isEditing ? (existingTx['amount'] as double).abs().toString() : "");
    
    // Default Values
    String selectedCat = isEditing ? (existingTx['category'] ?? 'Food') : 'Food';
    bool isExpense = isEditing ? (existingTx['amount'] as double) < 0 : true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor, // [THEME]
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final moneyProvider = Provider.of<MoneyProvider>(context);
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
          final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
          final isDark = theme.brightness == Brightness.dark;
          final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

          return Padding(
            // Spacious padding to avoid keyboard overlay
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 40, top: 20, left: 25, right: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                
                // HEADER ROW
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEditing ? "Edit Transaction" : "New Transaction", style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                    if (isEditing)
                      IconButton(
                        icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
                        onPressed: () {
                          if (existingTx['id'] != null) {
                            Provider.of<MoneyProvider>(context, listen: false).removeTransactionById(existingTx['id']);
                          }
                          Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // CUSTOM TOGGLE (Theme Aware)
                Container(
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => isExpense = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: isExpense ? textColor : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                            child: Text("Expense", textAlign: TextAlign.center, style: TextStyle(color: isExpense ? theme.scaffoldBackgroundColor : secondaryTextColor, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => isExpense = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: !isExpense ? textColor : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                            child: Text("Income", textAlign: TextAlign.center, style: TextStyle(color: !isExpense ? theme.scaffoldBackgroundColor : secondaryTextColor, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // INPUTS
                CupertinoTextField(
                  controller: titleCtrl,
                  placeholder: "Title",
                  placeholderStyle: TextStyle(color: secondaryTextColor),
                  style: TextStyle(color: textColor),
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 15),
                CupertinoTextField(
                  controller: amountCtrl,
                  placeholder: "0.00",
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholderStyle: TextStyle(color: secondaryTextColor),
                  style: TextStyle(color: textColor),
                  prefix: Padding(padding: const EdgeInsets.only(left: 16), child: Icon(CupertinoIcons.money_dollar, color: secondaryTextColor, size: 18)),
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(16),
                ),
                
                const SizedBox(height: 25),
                
                // CATEGORIES
                if (isExpense) 
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ...moneyProvider.categories.map((cat) {
                          final isSelected = selectedCat == cat;
                          return GestureDetector(
                            onTap: () => setSheetState(() => selectedCat = cat),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? textColor : inputBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(cat, style: TextStyle(color: isSelected ? theme.scaffoldBackgroundColor : secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }),
                        // ADD CATEGORY BUTTON
                        GestureDetector(
                          onTap: () => _showAddCategoryDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                            decoration: BoxDecoration(border: Border.all(color: secondaryTextColor), borderRadius: BorderRadius.circular(20)),
                            child: Row(children: [Icon(Icons.add, color: textColor, size: 16), const SizedBox(width: 5), Text("New", style: TextStyle(color: textColor, fontSize: 12))]),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 30),

                // SAVE BUTTON
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: textColor,
                    borderRadius: BorderRadius.circular(15),
                    child: Text(isEditing ? "Update Transaction" : "Save Transaction", style: TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (titleCtrl.text.isNotEmpty && amountCtrl.text.isNotEmpty) {
                        double val = double.tryParse(amountCtrl.text) ?? 0.0;
                        if (isExpense) val = -val.abs(); else val = val.abs();
                        
                        if (isEditing && existingTx['id'] != null) {
                          moneyProvider.editTransaction(existingTx['id'], titleCtrl.text, val, isExpense ? selectedCat : 'Income');
                        } else {
                          moneyProvider.addTransaction(titleCtrl.text, val, isExpense ? selectedCat : 'Income');
                        }
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("New Category"),
        content: Padding(padding: const EdgeInsets.only(top: 10), child: CupertinoTextField(controller: controller, placeholder: "Category Name", style: const TextStyle(color: Colors.black))),
        actions: [
          CupertinoDialogAction(child: const Text("Cancel"), onPressed: () => Navigator.pop(ctx)),
          CupertinoDialogAction(isDefaultAction: true, child: const Text("Add"), onPressed: () {
              if (controller.text.isNotEmpty) {
                Provider.of<MoneyProvider>(context, listen: false).addCategory(controller.text);
                Navigator.pop(ctx);
              }
            }),
        ],
      ),
    );
  }

  // --- CHART HELPERS ---
  List<PieChartSectionData> _buildPieSections(MoneyProvider provider) {
    final data = provider.spendingByCategory;
    if (data.isEmpty) return [];
    return data.entries.map((e) {
      final isTouched = data.keys.toList().indexOf(e.key) == _touchedIndex;
      final radius = isTouched ? 55.0 : 45.0;
      return PieChartSectionData(color: _getCategoryColor(e.key), value: e.value, showTitle: false, radius: radius);
    }).toList();
  }

  // [THEME] Minimalist Monochrome Palette that adapts
  Color _getCategoryColor(String cat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Light Mode: Shades of Black/Grey
    // Dark Mode: Shades of White/Grey
    if (isDark) {
      switch (cat) {
        case 'Food': return Colors.white; 
        case 'Transport': return Colors.white70;
        case 'Entertainment': return Colors.white54;
        case 'Shopping': return Colors.white38;
        default: return Colors.white24;
      }
    } else {
      switch (cat) {
        case 'Food': return Colors.black; 
        case 'Transport': return Colors.black87;
        case 'Entertainment': return Colors.black54;
        case 'Shopping': return Colors.black38;
        default: return Colors.black12;
      }
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'Food': return CupertinoIcons.cart;
      case 'Transport': return CupertinoIcons.car_detailed;
      case 'Entertainment': return CupertinoIcons.game_controller;
      case 'Shopping': return CupertinoIcons.bag;
      case 'Health': return CupertinoIcons.heart;
      case 'Income': return CupertinoIcons.money_dollar;
      default: return CupertinoIcons.circle_grid_3x3;
    }
  }
}
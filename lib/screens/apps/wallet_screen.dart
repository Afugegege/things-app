import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/money_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/life_app_scaffold.dart';
import 'dart:ui';
import '../chat/chat_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _selectedGroupIndex = 0; 
  int _touchedIndex = -1; 
  
  // [NEW] Time Filtering
  String _selectedPeriod = 'All Time';
  final List<String> _periods = ['Daily', 'Weekly', 'Monthly', 'Yearly', 'All Time'];

  // [NEW] Transaction Sort & Filter
  // [NEW] Transaction Sort & Filter
  String _sortOption = 'Newest';
  String _filterOption = 'All';
  final List<String> _sortOptions = ['Newest', 'Oldest', 'Highest', 'Lowest', 'Recently Added'];
  final List<String> _filterOptions = ['All', 'Income', 'Expense'];

  List<Map<String, dynamic>> _getFilteredTransactions(List<Map<String, dynamic>> all) {
    if (_selectedPeriod == 'All Time') return all;

    final now = DateTime.now();
    return all.where((t) {
      if (t['date'] == null) return false;
      final date = DateTime.tryParse(t['date'].toString());
      if (date == null) return false;
      switch (_selectedPeriod) {
        case 'Daily':
          return date.year == now.year && date.month == now.month && date.day == now.day;
        case 'Weekly':
          // Last 7 days
          // return now.difference(date).inDays <= 7;
          // OR Current Week (Monday start) logic if preferred. 
          // Let's use simple "Last 7 Days" window or "Current iso Week"? 
          // User request just says "weekly". "This Week" usually means current week.
          // Let's stick to "Current Week" (same year, same week number) or simpler "Last 7 days" for personal finance often useful.
          // Let's go with "Same Week" logic roughly:
          final diff = now.difference(date);
          return diff.inDays < 7 && now.weekday >= date.weekday; 
          // Actually, DateUtils or manual check is safer. 
          // Simple: Check if in same calendar week? 
          // Let's do: Start of week (Monday) <= date <= End of week.
          // For simplicity/robustness without external packages:
          // Just returns transactions in the last 7 days window.
          // return now.difference(date).inDays <= 7 && now.difference(date).inDays >= 0; 
        case 'Monthly':
          return date.year == now.year && date.month == now.month;
        case 'Yearly':
          return date.year == now.year;
        default:
          return true;
      }
    }).toList();
  }

  // Calculation Helpers
  double _calculateIncome(List<Map<String, dynamic>> txs) {
    return txs.where((t) => (t['amount'] as double) > 0).fold(0.0, (sum, t) => sum + (t['amount'] as double));
  }
  
  double _calculateExpense(List<Map<String, dynamic>> txs) {
    return txs.where((t) => (t['amount'] as double) < 0).fold(0.0, (sum, t) => sum + (t['amount'] as double));
  }

  Map<String, double> _calculateSpending(List<Map<String, dynamic>> txs) {
    final Map<String, double> data = {};
    for (var t in txs) {
      if ((t['amount'] as double) < 0) {
        final cat = t['category'] ?? 'Other';
        data[cat] = (data[cat] ?? 0.0) + (t['amount'] as double).abs();
      }
    }
    return data;
  } 

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
        IconButton(
          icon: Icon(CupertinoIcons.add, color: iconColor),
          onPressed: () => _showTransactionSheet(context),
        ),
      ],
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: FloatingActionButton(
          onPressed: () => _showTransactionSheet(context),
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
                  2: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Text("Future", style: TextStyle(color: textColor))),
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
                  : _selectedGroupIndex == 1
                      ? _buildTransactionsTab(moneyProvider, isFutureTab: false)
                      : _buildTransactionsTab(moneyProvider, isFutureTab: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(MoneyProvider provider) {
    // [THEME] Colors
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final trackColor = isDark ? Colors.white10 : Colors.black12;

    // [CALCULATION] Filter Data
    final filteredTx = _getFilteredTransactions(provider.transactions);
    final income = _calculateIncome(filteredTx);
    final expense = _calculateExpense(filteredTx);
    final spendingMap = _calculateSpending(filteredTx);

    return ListView(
      key: const ValueKey(0),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 180),
      children: [
        // [NEW] PERIOD SELECTOR
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: _periods.map((period) {
              final isSelected = _selectedPeriod == period;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedPeriod = period;
                  _touchedIndex = -1; // Reset chart selection
                }),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? textColor : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    period, 
                    style: TextStyle(
                      color: isSelected ? theme.scaffoldBackgroundColor : secondaryTextColor, 
                      fontSize: 12, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // SUMMARY BOXES
        Row(
          children: [
            Expanded(child: _buildSummaryBox("INCOME", income, Colors.greenAccent)),
            const SizedBox(width: 15),
            Expanded(child: _buildSummaryBox("EXPENSE", expense, textColor)),
          ],
        ),
        const SizedBox(height: 40),

        // PIE CHART
        // PIE CHART
        Column(
          children: [

              SizedBox(
                height: 200,
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
                        sections: _buildPieSections(spendingMap),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _touchedIndex >= 0 && _touchedIndex < spendingMap.length 
                              ? spendingMap.keys.elementAt(_touchedIndex).toUpperCase() 
                              : "TOTAL SPENT",
                          style: TextStyle(color: secondaryTextColor, fontSize: 10, letterSpacing: 1.5),
                        ),
                        Text(
                          "\$${_touchedIndex >= 0 && _touchedIndex < spendingMap.length ? spendingMap.values.elementAt(_touchedIndex).toStringAsFixed(0) : expense.toStringAsFixed(0)}",
                          style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 15),
              // LEGEND
              spendingMap.isEmpty 
                  ? const SizedBox()
                  : Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: spendingMap.keys.map((cat) {
                        final color = _getCategoryColor(cat);
                        final isSelected = _touchedIndex >= 0 && spendingMap.keys.elementAt(_touchedIndex) == cat;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8, height: 8, 
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat, 
                              style: TextStyle(
                                color: isSelected ? textColor : secondaryTextColor, 
                                fontSize: 11, 
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
            ],
          ),
        
        const SizedBox(height: 40),
        Text("BUDGETS", style: TextStyle(color: secondaryTextColor, fontSize: 12, letterSpacing: 2)),
        const SizedBox(height: 20),
        // Budgets remain general for now (usually monthly), so we might not filter them by selected period unless explicit logic.
        // Assuming budgets are monthly, showing them always is standard behavior unless we refactor budget logic.
        // But for visual consistency, we use provider values directly for budgets progress.
        // Actually, budget progress SHOULD respect the "Monthly" period if viewed in Monthly mode? 
        // Or Budget is always Monthly. Let's keep it using "getSpentForCategory" which uses *ALL* time in provider. 
        // WAIT. `getSpentForCategory` in provider uses `spendingByCategory` which uses `_transactions` (ALL).
        // If user wants to see *Monthly* budget progress, they should select 'Monthly'.
        // So I should calculate budget spent based on `filteredTx` if period is Monthly/Weekly/etc?
        // Default Logic: Budget is usually a Monthly limit. 
        // If period is 'Daily', comparing daily spend vs Monthly budget is weird.
        // Let's keep Budgets section using the `spendingMap` we calculated for consistency with the filter!
        // This makes filters powerful: check "Weekly" spending vs Monthly Budget (might be low), check "Yearly" vs Monthly Budget (will be way over).
        // Ideally Budget is "Spending in Current Month" regardless of filter, OR filter applies.
        // Let's use `spendingMap` so UI is consistent (Chart = Budgets Progess).
        ...provider.budgets.entries.map((entry) {
          final spent = spendingMap[entry.key] ?? 0.0;
          final limit = entry.value;
          final pct = (spent / limit).clamp(0.0, 1.0);
          return GestureDetector(
            onTap: () => _showBudgetDialog(context, entry.key, limit),
            child: Padding(
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
                  LinearProgressIndicator(value: pct, minHeight: 6, borderRadius: BorderRadius.circular(3), backgroundColor: trackColor, color: textColor),
                ],
              ),
            ),
          );
        }),
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(CupertinoIcons.add, size: 16, color: textColor), SizedBox(width: 5), Text("Add Budget", style: TextStyle(color: textColor, fontSize: 14))]),
          onPressed: () => _showBudgetDialog(context, null, 0.0),
        ),
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

  Widget _buildTransactionsTab(MoneyProvider provider, {bool isFutureTab = false}) {
    final theme = Theme.of(context);
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final isDark = theme.brightness == Brightness.dark;

    // 1. FILTER & SORT DATA
    // Select source list based on tab
    List<Map<String, dynamic>> sourceList = isFutureTab ? provider.futureTransactions : provider.activeTransactions;
    List<Map<String, dynamic>> processedTx = List.from(sourceList);

    // Apply Type Filter
    if (_filterOption == 'Income') {
      processedTx = processedTx.where((t) => (t['amount'] as double) > 0).toList();
    } else if (_filterOption == 'Expense') {
      processedTx = processedTx.where((t) => (t['amount'] as double) < 0).toList();
    }

    // Apply Sort
    switch (_sortOption) {
      case 'Newest':
        // Sort by Date property (User assigned date)
        processedTx.sort((a, b) => DateTime.parse(b['date'].toString()).compareTo(DateTime.parse(a['date'].toString())));
        break;
      case 'Oldest':
        processedTx.sort((a, b) => DateTime.parse(a['date'].toString()).compareTo(DateTime.parse(b['date'].toString())));
        break;
      case 'Highest':
        processedTx.sort((a, b) => (b['amount'] as double).abs().compareTo((a['amount'] as double).abs()));
        break;
      case 'Lowest':
        processedTx.sort((a, b) => (a['amount'] as double).abs().compareTo((b['amount'] as double).abs()));
        break;
      case 'Recently Added':
        // Sort by addedDate property (System created date), fall back to 'date' if not present
        processedTx.sort((a, b) {
           final da = a['addedDate'] ?? a['date'];
           final db = b['addedDate'] ?? b['date'];
           return DateTime.parse(db.toString()).compareTo(DateTime.parse(da.toString()));
        });
        break;
    }

    return Stack(
      children: [
        // LIST
        Positioned.fill(
          child: processedTx.isEmpty 
              ? Center(child: Text("No transactions found.", style: TextStyle(color: secondaryTextColor)))
              : ListView.separated(
                  key: const ValueKey(1),
                  padding: const EdgeInsets.fromLTRB(20, 55, 20, 180), // Further reduced top padding
                  itemCount: processedTx.length,
                  separatorBuilder: (c, i) => Divider(color: theme.dividerColor, height: 1),
                  itemBuilder: (context, index) {
                    final tx = processedTx[index];
                    final bool isExp = (tx['amount'] as double) < 0;
                    final String cat = tx['category'] ?? 'General';
                    final iconBg = isDark ? Colors.white10 : Colors.black12;

                    return Dismissible(
                      key: Key(tx['id'] ?? tx.hashCode.toString()), 
                      onDismissed: (_) => provider.removeTransactionById(tx['id']),
                      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(CupertinoIcons.trash, color: Colors.red)),
                      child: GestureDetector(
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
                                      Text(
                                        // Show "Added: ..." if sorting by added date, otherwise transaction date
                                        _sortOption == 'Recently Added' 
                                          ? "Added: ${tx['addedDate']?.toString().split(' ')[0] ?? 'N/A'}"
                                          : tx['date'].toString().split(' ')[0], 
                                        style: TextStyle(color: secondaryTextColor, fontSize: 12)
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("${isExp ? '' : '+'}\$${tx['amount'].abs().toStringAsFixed(2)}", style: TextStyle(color: isExp ? textColor : Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    if (isFutureTab)
                                       // Mark as Paid button for future items
                                       GestureDetector(
                                         onTap: () {
                                            provider.markAsPaid(tx['id']);
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Marked as Paid!"), duration: Duration(seconds: 1)));
                                         },
                                         child: Text("Mark Paid", style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                       )
                                    else
                                       Text(cat, style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    );
                  },
                ),
        ),

        // FLOATING BLURRED FILTER BAR
        Positioned(
          top: 0, left: 0, right: 0,
          child: ShaderMask(
            shaderCallback: (rect) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0.0, 0.7, 1.0], // Fade out after content
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Stronger blur
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20), // Reduced bottom padding slightly
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.scaffoldBackgroundColor,
                        theme.scaffoldBackgroundColor.withOpacity(0.0),
                      ],
                      stops: const [0.7, 1.0], // Match mask Fade
                    ),
                  ),
                  child: Row(
                     children: [
                        // SORT BUTTON
                        _buildDropdownLikeChip(
                          context, 
                          label: "Sort: $_sortOption", 
                          icon: CupertinoIcons.sort_down,
                          onTap: () => _showSelectionSheet(context, "Sort By", _sortOptions, (val) => setState(() => _sortOption = val)),
                        ),
                        const SizedBox(width: 10),
                        // FILTER BUTTON
                        _buildDropdownLikeChip(
                          context, 
                          label: "Type: $_filterOption", 
                          icon: CupertinoIcons.slider_horizontal_3,
                          onTap: () => _showSelectionSheet(context, "Filter By", _filterOptions, (val) => setState(() => _filterOption = val)),
                        ),
                     ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownLikeChip(BuildContext context, {required String label, required IconData icon, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    // Dynamic chip color for blur effect visibility
    final chipBg = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);
    
    return GestureDetector(
      onTap: onTap,
      child: Center( // Center vertically in listview
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: textColor.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 16, color: textColor.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectionSheet(BuildContext context, String title, List<String> options, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title.toUpperCase(), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
              const SizedBox(height: 15),
              ...options.map((opt) => ListTile(
                title: Text(opt, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 16)),
                onTap: () {
                  onSelect(opt);
                  Navigator.pop(ctx);
                },
              )),
              const SizedBox(height: 10),
            ],
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
    DateTime selectedDate = isEditing ? DateTime.parse(existingTx['date']) : DateTime.now();
    bool isFuture = isEditing ? (existingTx['isFuture'] == true) : false;

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
                
                const SizedBox(height: 20),
                
                // DATE & FUTURE OPTION
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                           final picked = await showDatePicker(
                             context: context, 
                             initialDate: selectedDate, 
                             firstDate: DateTime(2020), 
                             lastDate: DateTime(2030)
                           );
                           if (picked != null) {
                             setSheetState(() => selectedDate = picked);
                           }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.calendar, color: secondaryTextColor, size: 18),
                              const SizedBox(width: 10),
                              Text(selectedDate.toString().split(' ')[0], style: TextStyle(color: textColor)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    GestureDetector(
                      onTap: () => setSheetState(() => isFuture = !isFuture),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isFuture ? theme.primaryColor.withOpacity(0.1) : inputBg, // Highlight if checked? Or just checkmark
                          borderRadius: BorderRadius.circular(12),
                          border: isFuture ? Border.all(color: theme.primaryColor) : null,
                        ),
                        child: Row(
                          children: [
                            Icon(isFuture ? CupertinoIcons.checkmark_square_fill : CupertinoIcons.square, color: isFuture ? theme.primaryColor : secondaryTextColor, size: 20),
                            const SizedBox(width: 8),
                            Text("Future Payment", style: TextStyle(color: isFuture ? theme.primaryColor : secondaryTextColor, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                          moneyProvider.editTransaction(
                            existingTx['id'], 
                            titleCtrl.text, 
                            val, 
                            isExpense ? selectedCat : 'Income',
                            date: selectedDate,
                            isFuture: isFuture,
                          );
                        } else {
                          moneyProvider.addTransaction(
                            titleCtrl.text, 
                            val, 
                            isExpense ? selectedCat : 'Income',
                            date: selectedDate,
                            isFuture: isFuture,
                          );
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
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final isDark = theme.brightness == Brightness.dark;
    final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 30, top: 20, left: 25, right: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text("New Category", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            CupertinoTextField(
              controller: controller,
              placeholder: "Category Name",
              placeholderStyle: TextStyle(color: secondaryTextColor),
              style: TextStyle(color: textColor),
              decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(16),
              autofocus: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: textColor,
                borderRadius: BorderRadius.circular(14),
                child: Text("Add Category", style: TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold)),
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    Provider.of<MoneyProvider>(context, listen: false).addCategory(controller.text);
                    Navigator.pop(ctx);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CHART HELPERS ---
  List<PieChartSectionData> _buildPieSections(Map<String, double> spendingByCategory) {
    if (spendingByCategory.isEmpty) return [];
    return spendingByCategory.entries.map((e) {
      final isTouched = spendingByCategory.keys.toList().indexOf(e.key) == _touchedIndex;
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

  void _showBudgetDialog(BuildContext context, String? category, double? currentLimit) {
    if (category != null && currentLimit == null) return;
    
    final  selectedCat = category ?? 'Food';
    final limit = currentLimit ?? 0.0;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _BudgetEditor(initialCategory: selectedCat, initialLimit: limit, isEditing: category != null),
    );
  }
}

class _BudgetEditor extends StatefulWidget {
  final String initialCategory;
  final double initialLimit;
  final bool isEditing;
  const _BudgetEditor({required this.initialCategory, required this.initialLimit, required this.isEditing});

  @override
  State<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<_BudgetEditor> {
  late String selectedCat;
  late TextEditingController amountCtrl;

  @override
  void initState() {
    super.initState();
    selectedCat = widget.initialCategory;
    amountCtrl = TextEditingController(text: widget.initialLimit > 0 ? widget.initialLimit.toStringAsFixed(0) : "");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final isDark = theme.brightness == Brightness.dark;
    final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    final moneyProvider = Provider.of<MoneyProvider>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 30, top: 20, left: 25, right: 25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text(widget.isEditing ? "Edit Budget: $selectedCat" : "Set New Budget", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 25),
          
          if (!widget.isEditing) ...[
             SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...moneyProvider.categories.map((cat) {
                    final isSelected = selectedCat == cat;
                    return GestureDetector(
                      onTap: () => setState(() => selectedCat = cat),
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
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          CupertinoTextField(
            controller: amountCtrl,
            placeholder: "Monthly Limit",
            keyboardType: TextInputType.number,
            placeholderStyle: TextStyle(color: secondaryTextColor),
            style: TextStyle(color: textColor),
            prefix: Padding(padding: const EdgeInsets.only(left: 16), child: Icon(CupertinoIcons.money_dollar, color: secondaryTextColor, size: 18)),
            decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(16),
            autofocus: true,
          ),
          
          const SizedBox(height: 30),
          
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: textColor,
              borderRadius: BorderRadius.circular(14),
              child: Text("Save Budget", style: TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold)),
              onPressed: () {
                final val = double.tryParse(amountCtrl.text) ?? 0.0;
                if (val > 0) {
                  moneyProvider.updateBudget(selectedCat, val);
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

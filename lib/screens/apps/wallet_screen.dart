import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/money_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notes_provider.dart';
import '../../models/currency_model.dart';
import '../../widgets/life_app_scaffold.dart';
import 'dart:ui';
import '../chat/chat_screen.dart';
import '../../widgets/common/minimalist_toast.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _selectedGroupIndex = 0;
  int _touchedIndex = -1;
  String? _viewingGroupId;
  bool _showBalanceMode = false;

  // Multi-Select State
  bool _isMultiSelect = false;
  final Set<String> _selectedTxIds = {};

  // [NEW] Time Filtering
  String _selectedPeriod = 'All Time';
  final List<String> _periods = [
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
    'All Time'
  ];

  // [NEW] Transaction Sort & Filter
  String _sortOption = 'Newest';
  String _filterOption = 'All';
  final List<String> _sortOptions = [
    'Newest',
    'Oldest',
    'Highest',
    'Lowest',
    'Recently Added'
  ];
  final List<String> _filterOptions = ['All', 'Income', 'Expense'];

  List<Map<String, dynamic>> _getFilteredTransactions(
      List<Map<String, dynamic>> all) {
    if (_selectedPeriod == 'All Time') return all;

    final now = DateTime.now();
    return all.where((t) {
      if (t['date'] == null) return false;
      final date = DateTime.tryParse(t['date'].toString());
      if (date == null) return false;
      switch (_selectedPeriod) {
        case 'Daily':
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        case 'Weekly':
          final diff = now.difference(date);
          return diff.inDays < 7 && now.weekday >= date.weekday;
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
    return txs
        .where((t) => (t['amount'] as double) > 0 && t['excludeFromExpenses'] != true)
        .fold(0.0, (sum, t) => sum + (t['amount'] as double));
  }

  double _calculateExpense(List<Map<String, dynamic>> txs) {
    return txs
        .where((t) => (t['amount'] as double) < 0 && t['excludeFromExpenses'] != true)
        .fold(0.0, (sum, t) => sum + (t['amount'] as double));
  }

  Map<String, double> _calculateSpending(List<Map<String, dynamic>> txs) {
    final Map<String, double> data = {};
    for (var t in txs) {
      if ((t['amount'] as double) < 0 && t['excludeFromExpenses'] != true) {
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
    final prompt =
        "Analyze my finances in ${moneyProvider.currentCurrency} (${moneyProvider.currentCurrencySymbol}). Balance: ${moneyProvider.currentCurrencySymbol}$balance. Spending breakdown: $spending. Give me 3 minimalist tips to save money.";
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    chatProvider.sendMessage(
        message: prompt,
        userMemories: userProvider.user.aiMemory,
        mode: 'Finance',
        currencyCode: moneyProvider.currentCurrency);
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  void _showCurrencyPicker(BuildContext context, MoneyProvider moneyProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String query = "";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allCurrencies = AppCurrency.currencies;
            final filtered = allCurrencies.where((c) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return c.code.toLowerCase().contains(q) ||
                  c.name.toLowerCase().contains(q) ||
                  c.symbol.toLowerCase().contains(q);
            }).toList();

            final allTxs = moneyProvider.allTransactions;

            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Select Currency",
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${moneyProvider.currentCurrency} (${moneyProvider.currentCurrencySymbol})",
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CupertinoSearchTextField(
                    style: TextStyle(color: textColor),
                    placeholder: "Search currency or country...",
                    placeholderStyle: TextStyle(color: secondaryTextColor),
                    onChanged: (val) {
                      setModalState(() {
                        query = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        color: theme.dividerColor.withOpacity(0.3),
                        height: 1,
                      ),
                      itemBuilder: (context, idx) {
                        final c = filtered[idx];
                        final isSelected = c.code == moneyProvider.currentCurrency;
                        final count = allTxs
                            .where((t) => (t['currency'] ?? 'USD') == c.code)
                            .length;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.black.withOpacity(0.04),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              c.symbol,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                c.code,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.black.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  c.symbol,
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            c.name,
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (count > 0)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "$count ${count == 1 ? 'record' : 'records'}",
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (isSelected)
                                Icon(
                                  CupertinoIcons.checkmark_alt_circle_fill,
                                  color: theme.primaryColor,
                                  size: 22,
                                )
                              else
                                const SizedBox(width: 22),
                            ],
                          ),
                          onTap: () {
                            moneyProvider.setCurrency(c.code);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
          child: Icon(CupertinoIcons.add,
              color: isDark ? Colors.black : Colors.white, size: 28),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),

          // CURRENCY SELECTOR PILL
          GestureDetector(
            onTap: () => _showCurrencyPicker(context, moneyProvider),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.money_dollar_circle,
                      size: 14, color: textColor),
                  const SizedBox(width: 6),
                  Text(
                    "${moneyProvider.currentCurrency} (${moneyProvider.currentCurrencySymbol})",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(CupertinoIcons.chevron_down,
                      size: 12, color: secondaryTextColor),
                ],
              ),
            ),
          ),

          // SPENDING & BALANCE HEADER
          GestureDetector(
            onTap: moneyProvider.hasIncomeRecorded
                ? () => setState(() => _showBalanceMode = !_showBalanceMode)
                : null,
            child: Column(
              children: [
                Text(
                  (!moneyProvider.hasIncomeRecorded || !_showBalanceMode)
                      ? "TOTAL SPENT"
                      : "TOTAL BALANCE",
                  style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  (!moneyProvider.hasIncomeRecorded || !_showBalanceMode)
                      ? "${moneyProvider.currentCurrencySymbol}${moneyProvider.totalSpendingAmount.toStringAsFixed(2)}"
                      : "${moneyProvider.currentCurrencySymbol}${moneyProvider.balance.toStringAsFixed(2)}",
                  style: TextStyle(
                      color: textColor,
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1),
                ),
                if (moneyProvider.hasIncomeRecorded)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.arrow_2_circlepath,
                            size: 10, color: secondaryTextColor),
                        const SizedBox(width: 4),
                        Text(
                          _showBalanceMode
                              ? "Showing Net Balance • Tap for Spent"
                              : "Showing Spent • Tap for Balance",
                          style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // SEGMENTED CONTROL (Fits without scrolling)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                thumbColor: isDark ? Colors.white24 : Colors.white,
                groupValue: _selectedGroupIndex,
                children: {
                  0: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 7),
                      child: Text("Overview", style: TextStyle(color: textColor, fontSize: 11.5, fontWeight: FontWeight.w600))),
                  1: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 7),
                      child: Text("Activity",
                          style: TextStyle(color: textColor, fontSize: 11.5, fontWeight: FontWeight.w600))),
                  2: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 7),
                      child: Text("Future", style: TextStyle(color: textColor, fontSize: 11.5, fontWeight: FontWeight.w600))),
                  3: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 7),
                      child: Text("Groups", style: TextStyle(color: textColor, fontSize: 11.5, fontWeight: FontWeight.w600))),
                },
                onValueChanged: (value) =>
                    setState(() {
                      _selectedGroupIndex = value!;
                      _viewingGroupId = null; // Reset group detail when switching tabs
                    }),
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
                      : _selectedGroupIndex == 2
                          ? _buildTransactionsTab(moneyProvider, isFutureTab: true)
                          : _buildGroupsTab(moneyProvider),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? textColor
                        : (isDark
                            ? Colors.white10
                            : Colors.black.withOpacity(0.05)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(period,
                      style: TextStyle(
                          color: isSelected
                              ? theme.scaffoldBackgroundColor
                              : secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              );
            }).toList(),
          ),
        ),

        // SUMMARY BOXES
        Row(
          children: [
            if (income > 0) ...[
              Expanded(
                  child: _buildSummaryBox("INCOME", income, Colors.greenAccent)),
              const SizedBox(width: 15),
              Expanded(child: _buildSummaryBox("EXPENSE", expense.abs(), textColor)),
            ] else ...[
              Expanded(child: _buildSummaryBox("TOTAL SPENT", expense.abs(), textColor)),
              const SizedBox(width: 15),
              Expanded(
                  child: _buildSummaryBox("TRANSACTIONS",
                      filteredTx.length.toDouble(), secondaryTextColor,
                      isCount: true)),
            ],
          ],
        ),
        const SizedBox(height: 35),

        // PIE CHART OR CLEAN EMPTY STATE
        if (spendingMap.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            margin: const EdgeInsets.only(bottom: 25),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(CupertinoIcons.creditcard,
                      size: 24, color: secondaryTextColor),
                ),
                const SizedBox(height: 14),
                Text("No Expenses Recorded",
                    style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  _selectedPeriod == 'All Time'
                      ? "Tap + to record your first expense."
                      : "No spending recorded for $_selectedPeriod.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryTextColor, fontSize: 13),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () => _showTransactionSheet(context),
                  icon: const Icon(CupertinoIcons.add, size: 16),
                  label: const Text("Add Expense", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: textColor,
                    foregroundColor: theme.scaffoldBackgroundColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ],
            ),
          )
        else
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
                            if (!mounted) return;
                            if (event is FlTapDownEvent || event is FlTapUpEvent) {
                              if (pieTouchResponse != null &&
                                  pieTouchResponse.touchedSection != null) {
                                final targetIndex = pieTouchResponse
                                    .touchedSection!.touchedSectionIndex;
                                if (targetIndex >= 0 && targetIndex < spendingMap.length) {
                                  setState(() {
                                    _touchedIndex = (_touchedIndex == targetIndex) ? -1 : targetIndex;
                                  });
                                }
                              }
                            } else if (event is FlPointerHoverEvent) {
                              if (pieTouchResponse != null &&
                                  pieTouchResponse.touchedSection != null) {
                                final targetIndex = pieTouchResponse
                                    .touchedSection!.touchedSectionIndex;
                                if (targetIndex >= 0 && targetIndex < spendingMap.length && _touchedIndex != targetIndex) {
                                  setState(() {
                                    _touchedIndex = targetIndex;
                                  });
                                }
                              }
                            }
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
                              ? spendingMap.keys
                                  .elementAt(_touchedIndex)
                                  .toUpperCase()
                              : "TOTAL SPENT",
                          style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${provider.currentCurrencySymbol}${_touchedIndex >= 0 && _touchedIndex < spendingMap.length ? spendingMap.values.elementAt(_touchedIndex).toStringAsFixed(2) : expense.abs().toStringAsFixed(2)}",
                          style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        if (_touchedIndex >= 0 && _touchedIndex < spendingMap.length && expense.abs() > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              "${((spendingMap.values.elementAt(_touchedIndex) / expense.abs()) * 100).toStringAsFixed(1)}%",
                              style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              "Tap slice or tag",
                              style: TextStyle(
                                  color: secondaryTextColor.withOpacity(0.6),
                                  fontSize: 9),
                            ),
                          ),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 15),
              // INTERACTIVE LEGEND CHIPS
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: spendingMap.keys.toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final cat = entry.value;
                  final color = _getCategoryColor(cat);
                  final isSelected = _touchedIndex == idx;
                  final val = spendingMap[cat] ?? 0.0;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _touchedIndex = (_touchedIndex == idx) ? -1 : idx;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08))
                            : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? Colors.white70 : Colors.black87)
                              : (isDark ? Colors.white12 : Colors.black12),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "$cat  ${provider.currentCurrencySymbol}${val.toStringAsFixed(0)}",
                            style: TextStyle(
                              color: isSelected ? textColor : secondaryTextColor,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

        const SizedBox(height: 35),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("BUDGETS",
                style: TextStyle(
                    color: secondaryTextColor, fontSize: 12, letterSpacing: 2)),
            if (provider.budgets.isNotEmpty)
              GestureDetector(
                onTap: () {
                  for (var cat in provider.budgets.keys.toList()) {
                    provider.removeBudget(cat);
                  }
                },
                child: Text("Clear All",
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 15),

        if (provider.budgets.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? theme.cardColor : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
                  width: 1.0),
            ),
            child: Column(
              children: [
                Icon(CupertinoIcons.money_dollar_circle,
                    size: 32, color: secondaryTextColor.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text("No Active Budgets",
                    style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text("Tap below to set a budget limit.",
                    style: TextStyle(
                        color: secondaryTextColor, fontSize: 12)),
              ],
            ),
          )
        else
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
                        Text(entry.key,
                            style: TextStyle(color: textColor, fontSize: 16)),
                        Row(
                          children: [
                            Text("${provider.currentCurrencySymbol}${spent.toStringAsFixed(2)} / ${provider.currentCurrencySymbol}${limit.toStringAsFixed(2)}",
                                style: TextStyle(
                                    color: secondaryTextColor, fontSize: 14)),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                provider.removeBudget(entry.key);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text("Removed ${entry.key} budget"),
                                  duration: const Duration(seconds: 2),
                                ));
                              },
                              child: Icon(CupertinoIcons.xmark_circle_fill,
                                  size: 18,
                                  color: secondaryTextColor.withOpacity(0.4)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                        backgroundColor: trackColor,
                        color: textColor),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 10),
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(CupertinoIcons.add, size: 16, color: textColor),
            const SizedBox(width: 5),
            Text("Add Budget", style: TextStyle(color: textColor, fontSize: 14))
          ]),
          onPressed: () => _showBudgetDialog(context, null, 0.0),
        ),
      ],
    );
  }

  Widget _buildSummaryBox(String label, double value, Color color,
      {bool isCount = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final moneyProv = Provider.of<MoneyProvider>(context, listen: false);

    final String displayVal = isCount
        ? "${value.toInt()}"
        : "${moneyProv.currentCurrencySymbol}${value.abs().toStringAsFixed(2)}";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
              width: 1.0)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: secondaryTextColor,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(displayVal,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildTransactionsTab(MoneyProvider provider,
      {bool isFutureTab = false}) {
    final theme = Theme.of(context);
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final isDark = theme.brightness == Brightness.dark;

    // 1. FILTER & SORT DATA
    // Select source list based on tab
    List<Map<String, dynamic>> sourceList =
        isFutureTab ? provider.futureTransactions : provider.activeTransactions;
    List<Map<String, dynamic>> processedTx = List.from(sourceList);

    // Apply Type Filter
    if (_filterOption == 'Income') {
      processedTx =
          processedTx.where((t) => (t['amount'] as double) > 0).toList();
    } else if (_filterOption == 'Expense') {
      processedTx =
          processedTx.where((t) => (t['amount'] as double) < 0).toList();
    }

    // Apply Sort
    switch (_sortOption) {
      case 'Newest':
        processedTx.sort((a, b) =>
            DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
        break;
      case 'Oldest':
        processedTx.sort((a, b) =>
            DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
        break;
      case 'Highest':
        processedTx.sort((a, b) => (b['amount'] as double)
            .abs()
            .compareTo((a['amount'] as double).abs()));
        break;
      case 'Lowest':
        processedTx.sort((a, b) => (a['amount'] as double)
            .abs()
            .compareTo((b['amount'] as double).abs()));
        break;
      case 'Recently Added':
        // Sort by addedDate property (System created date), fall back to 'date' if not present
        processedTx.sort((a, b) {
          final da = a['addedDate'] ?? a['date'];
          final db = b['addedDate'] ?? b['date'];
          return DateTime.parse(db.toString())
              .compareTo(DateTime.parse(da.toString()));
        });
        break;
    }

    return Stack(
      children: [
        // LIST
        Positioned.fill(
          child: processedTx.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.tray,
                          size: 44,
                          color: secondaryTextColor.withOpacity(0.35)),
                      const SizedBox(height: 12),
                      Text("No transactions found",
                          style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text("Tap + below to record your first transaction",
                          style: TextStyle(
                              color: secondaryTextColor, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  key: const ValueKey(1),
                  padding: const EdgeInsets.fromLTRB(
                      20, 55, 20, 180), // Further reduced top padding
                  itemCount: processedTx.length,
                  separatorBuilder: (c, i) =>
                      Divider(color: theme.dividerColor, height: 1),
                  itemBuilder: (context, index) {
                    final tx = processedTx[index];
                    final txId = tx['id']?.toString() ?? '';
                    final bool isSelected = _selectedTxIds.contains(txId);
                    final bool isExp = (tx['amount'] as double) < 0;
                    final String cat = tx['category'] ?? 'General';
                    final iconBg = isDark ? Colors.white10 : Colors.black12;
                    final groupName = provider.getGroupName(tx['groupId']);
                    final groupIcon = provider.getGroupIcon(tx['groupId']);
                    final isExcluded = tx['excludeFromExpenses'] == true;

                    final Widget rowContent = Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          if (_isMultiSelect) ...[
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? theme.primaryColor : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? theme.primaryColor : (isDark ? Colors.white38 : Colors.black38),
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(CupertinoIcons.checkmark, size: 14, color: Colors.white)
                                  : null,
                            ),
                          ],
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(_getCategoryIcon(cat),
                                color: secondaryTextColor, size: 18),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(tx['title'],
                                          style: TextStyle(
                                              color: isExcluded
                                                  ? textColor.withOpacity(0.5)
                                                  : textColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              decoration: isExcluded
                                                  ? TextDecoration.lineThrough
                                                  : null)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                        // Show "Added: ..." if sorting by added date, otherwise transaction date
                                        _sortOption == 'Recently Added'
                                            ? "Added: ${tx['addedDate']?.toString().split(' ')[0] ?? 'N/A'}"
                                            : tx['date']
                                                .toString()
                                                .split(' ')[0],
                                        style: TextStyle(
                                            color: secondaryTextColor,
                                            fontSize: 12)),
                                    if (groupName != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withOpacity(0.08)
                                              : Colors.black.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(CupertinoIcons.folder,
                                                size: 10,
                                                color: secondaryTextColor),
                                            const SizedBox(width: 4),
                                            Text(
                                              groupName,
                                              style: TextStyle(
                                                  color: secondaryTextColor,
                                                  fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (isExcluded) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          "excluded",
                                          style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  "${isExp ? '' : '+'}${AppCurrency.getSymbol(tx['currency'] ?? provider.currentCurrency)}${tx['amount'].abs().toStringAsFixed(2)}",
                                  style: TextStyle(
                                      color: isExcluded
                                          ? textColor.withOpacity(0.4)
                                          : isExp
                                              ? textColor
                                              : Colors.greenAccent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      decoration: isExcluded
                                          ? TextDecoration.lineThrough
                                          : null)),
                              const SizedBox(height: 2),
                              if (isFutureTab)
                                // Mark as Paid button for future items
                                GestureDetector(
                                  onTap: () {
                                    provider.markAsPaid(tx['id']);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                            content:
                                                Text("Marked as Paid!"),
                                            duration:
                                                Duration(seconds: 1)));
                                  },
                                  child: Text("Mark Paid",
                                      style: TextStyle(
                                          color: textColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                )
                              else
                                Text(cat,
                                    style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    );

                    final Widget tile = GestureDetector(
                      onTap: () {
                        if (_isMultiSelect) {
                          setState(() {
                            if (isSelected) {
                              _selectedTxIds.remove(txId);
                            } else {
                              _selectedTxIds.add(txId);
                            }
                          });
                        } else {
                          _showTransactionSheet(context, existingTx: tx);
                        }
                      },
                      onLongPress: () {
                        if (!_isMultiSelect) {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _isMultiSelect = true;
                            _selectedTxIds.add(txId);
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: isSelected
                            ? BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                                borderRadius: BorderRadius.circular(16),
                              )
                            : null,
                        child: rowContent,
                      ),
                    );

                    if (_isMultiSelect) {
                      return tile;
                    }

                    return Dismissible(
                      key: Key(tx['id'] ?? tx.hashCode.toString()),
                      direction: DismissDirection.endToStart,
                      dismissThresholds: const {
                        DismissDirection.endToStart: 0.65,
                      },
                      onDismissed: (_) {
                        final deletedTx = Map<String, dynamic>.from(tx);
                        final index = provider.transactions.indexWhere((t) => t['id'] == tx['id']);
                        provider.removeTransactionById(tx['id']);
                        MinimalistToast.showUndo(
                          context,
                          title: tx['title']?.toString().isNotEmpty == true
                              ? tx['title'].toString()
                              : "Expense",
                          onUndo: () => provider.restoreTransaction(deletedTx, index: index),
                        );
                      },
                      background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(CupertinoIcons.trash,
                              color: Colors.red)),
                      child: tile,
                    );
                  },
                ),
        ),

        // FLOATING BLURRED FILTER BAR
        Positioned(
          top: 0,
          left: 0,
          right: 0,
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
                filter:
                    ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Stronger blur
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                      20, 10, 20, 20), // Reduced bottom padding slightly
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
                        onTap: () => _showSelectionSheet(
                            context,
                            "Sort By",
                            _sortOptions,
                            (val) => setState(() => _sortOption = val)),
                      ),
                      const SizedBox(width: 10),
                      // FILTER BUTTON
                      _buildDropdownLikeChip(
                        context,
                        label: "Type: $_filterOption",
                        icon: CupertinoIcons.slider_horizontal_3,
                        onTap: () => _showSelectionSheet(
                            context,
                            "Filter By",
                            _filterOptions,
                            (val) => setState(() => _filterOption = val)),
                      ),
                      const SizedBox(width: 10),
                      // MULTI-SELECT BUTTON
                      _buildDropdownLikeChip(
                        context,
                        label: _isMultiSelect ? "Done" : "Select",
                        icon: _isMultiSelect ? CupertinoIcons.checkmark : CupertinoIcons.checkmark_circle,
                        onTap: () {
                          setState(() {
                            _isMultiSelect = !_isMultiSelect;
                            if (!_isMultiSelect) _selectedTxIds.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // FLOATING MULTI-SELECT ACTION BAR
        if (_isMultiSelect)
          Positioned(
            bottom: 110,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222226).withOpacity(0.92) : Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            "${_selectedTxIds.length} Selected",
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_selectedTxIds.length == processedTx.length) {
                                  _selectedTxIds.clear();
                                } else {
                                  _selectedTxIds.addAll(processedTx.map((t) => t['id']?.toString() ?? ''));
                                }
                              });
                            },
                            child: Text(
                              _selectedTxIds.length == processedTx.length ? "Deselect All" : "Select All",
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: _selectedTxIds.isEmpty ? null : () => _showBatchCategoryDialog(context, provider),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.tag, size: 14, color: textColor),
                                  const SizedBox(width: 6),
                                  Text("Category", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              color: Colors.redAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: _selectedTxIds.isEmpty ? null : () => _showBatchDeleteConfirm(context, provider),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.trash, size: 14, color: Colors.redAccent),
                                  SizedBox(width: 6),
                                  Text("Delete", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdownLikeChip(BuildContext context,
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    // Dynamic chip color for blur effect visibility
    final chipBg =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);

    return GestureDetector(
      onTap: onTap,
      child: Center(
        // Center vertically in listview
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
              Text(label,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down,
                  size: 16, color: textColor.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectionSheet(BuildContext context, String title,
      List<String> options, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title.toUpperCase(),
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 12)),
              const SizedBox(height: 15),
              ...options.map((opt) => ListTile(
                    title: Text(opt,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textColor, fontSize: 16)),
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
  void _showTransactionSheet(BuildContext context,
      {Map<String, dynamic>? existingTx}) {
    final isEditing = existingTx != null;
    final titleCtrl =
        TextEditingController(text: isEditing ? existingTx['title'] : "");
    final amountCtrl = TextEditingController(
        text:
            isEditing ? (existingTx['amount'] as double).abs().toString() : "");

    // Default Values
    String selectedCat =
        isEditing ? (existingTx['category'] ?? 'Food') : 'Food';
    bool isExpense = isEditing ? (existingTx['amount'] as double) < 0 : true;
    DateTime selectedDate =
        isEditing ? DateTime.parse(existingTx['date']) : DateTime.now();
    bool isFuture = isEditing ? (existingTx['isFuture'] == true) : false;
    String? selectedNoteId = isEditing ? existingTx['linkedNoteId'] : null;
    String? selectedGroupId = isEditing ? existingTx['groupId'] : null;
    bool excludeFromExpenses = isEditing ? (existingTx['excludeFromExpenses'] == true) : false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor, // [THEME]
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final moneyProvider = Provider.of<MoneyProvider>(context);
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
          final secondaryTextColor =
              theme.textTheme.bodyMedium?.color ?? Colors.grey;
          final isDark = theme.brightness == Brightness.dark;
          final inputBg = isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05);

          return Padding(
            // Spacious padding to avoid keyboard overlay
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                top: 20,
                left: 25,
                right: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),

                // HEADER ROW
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEditing ? "Edit Transaction" : "New Transaction",
                        style: TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    if (isEditing)
                      IconButton(
                        icon: const Icon(CupertinoIcons.trash,
                            color: Colors.redAccent),
                        onPressed: () {
                          if (existingTx['id'] != null) {
                            final deletedTx = Map<String, dynamic>.from(existingTx);
                            final moneyProv = Provider.of<MoneyProvider>(context, listen: false);
                            moneyProv.removeTransactionById(existingTx['id']);
                            Navigator.pop(ctx);
                            MinimalistToast.showUndo(
                              context,
                              title: existingTx['title']?.toString().isNotEmpty == true
                                  ? existingTx['title'].toString()
                                  : "Expense",
                              onUndo: () => moneyProv.restoreTransaction(deletedTx),
                            );
                          } else {
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // CUSTOM TOGGLE (Theme Aware)
                Container(
                  decoration: BoxDecoration(
                      color: inputBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => isExpense = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                                color:
                                    isExpense ? textColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text("Expense",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: isExpense
                                        ? theme.scaffoldBackgroundColor
                                        : secondaryTextColor,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => isExpense = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                                color:
                                    !isExpense ? textColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text("Income",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: !isExpense
                                        ? theme.scaffoldBackgroundColor
                                        : secondaryTextColor,
                                    fontWeight: FontWeight.bold)),
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
                  decoration: BoxDecoration(
                      color: inputBg, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 15),
                CupertinoTextField(
                  controller: amountCtrl,
                  placeholder: "0.00",
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  placeholderStyle: TextStyle(color: secondaryTextColor),
                  style: TextStyle(color: textColor),
                  prefix: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        moneyProvider.currentCurrencySymbol,
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      )),
                  decoration: BoxDecoration(
                      color: inputBg, borderRadius: BorderRadius.circular(12)),
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
                              lastDate: DateTime(2030));
                          if (picked != null) {
                            setSheetState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.calendar,
                                  color: secondaryTextColor, size: 18),
                              const SizedBox(width: 10),
                              Text(selectedDate.toString().split(' ')[0],
                                  style: TextStyle(color: textColor)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    GestureDetector(
                      onTap: () => setSheetState(() => isFuture = !isFuture),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isFuture
                              ? theme.primaryColor.withOpacity(0.1)
                              : inputBg, // Highlight if checked? Or just checkmark
                          borderRadius: BorderRadius.circular(12),
                          border: isFuture
                              ? Border.all(color: theme.primaryColor)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                                isFuture
                                    ? CupertinoIcons.checkmark_square_fill
                                    : CupertinoIcons.square,
                                color: isFuture
                                    ? theme.primaryColor
                                    : secondaryTextColor,
                                size: 20),
                            const SizedBox(width: 8),
                            Text("Future Payment",
                                style: TextStyle(
                                    color: isFuture
                                        ? theme.primaryColor
                                        : secondaryTextColor,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),
                Text("Related Note",
                    style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 15),
                // ATTACH NOTE SELECTION
                Consumer<NotesProvider>(
                  builder: (context, notesProvider, child) {
                    final notes = notesProvider.notes;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedNoteId,
                          hint: Text("Select a note to link (optional)",
                              style: TextStyle(
                                  color: secondaryTextColor, fontSize: 14)),
                          dropdownColor: theme.cardColor,
                          icon: Icon(CupertinoIcons.chevron_down,
                              color: secondaryTextColor, size: 16),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text("None",
                                  style: TextStyle(
                                      color: textColor, fontSize: 14)),
                            ),
                            ...notes.map((note) => DropdownMenuItem<String>(
                                  value: note.id,
                                  child: Text(note.title,
                                      style: TextStyle(
                                          color: textColor, fontSize: 14)),
                                )),
                          ],
                          onChanged: (val) {
                            setSheetState(() => selectedNoteId = val);
                          },
                        ),
                      ),
                    );
                  },
                ),

                // Group selector
                if (isExpense && moneyProvider.groups.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Group (Optional)",
                        style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: selectedGroupId,
                        hint: Text("None",
                            style: TextStyle(
                                color: secondaryTextColor, fontSize: 14)),
                        dropdownColor: theme.cardColor,
                        icon: Icon(CupertinoIcons.chevron_down,
                            color: secondaryTextColor, size: 16),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text("None",
                                style: TextStyle(
                                    color: textColor, fontSize: 14)),
                          ),
                          ...moneyProvider.groups.map((g) => DropdownMenuItem<String?>(
                                value: g['id'],
                                child: Text(
                                    "${g['name']}",
                                    style: TextStyle(
                                        color: textColor, fontSize: 14)),
                              )),
                        ],
                        onChanged: (val) {
                          setSheetState(() => selectedGroupId = val);
                        },
                      ),
                    ),
                  ),
                ],

                // Exclude switch
                if (isExpense) ...[
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: () => setSheetState(() => excludeFromExpenses = !excludeFromExpenses),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: excludeFromExpenses
                            ? Colors.orange.withOpacity(0.1)
                            : inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: excludeFromExpenses
                            ? Border.all(color: Colors.orange.withOpacity(0.5))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            excludeFromExpenses
                                ? CupertinoIcons.checkmark_square_fill
                                : CupertinoIcons.square,
                            color: excludeFromExpenses
                                ? Colors.orange
                                : secondaryTextColor,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Exclude from my expenses",
                                    style: TextStyle(
                                        color: excludeFromExpenses ? Colors.orange : textColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                Text("Company or other people paying",
                                    style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? textColor : inputBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(cat,
                                  style: TextStyle(
                                      color: isSelected
                                          ? theme.scaffoldBackgroundColor
                                          : secondaryTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          );
                        }),
                        // ADD CATEGORY BUTTON
                        GestureDetector(
                          onTap: () => _showAddCategoryDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 10),
                            decoration: BoxDecoration(
                                border: Border.all(color: secondaryTextColor),
                                borderRadius: BorderRadius.circular(20)),
                            child: Row(children: [
                              Icon(Icons.add, color: textColor, size: 16),
                              const SizedBox(width: 5),
                              Text("New",
                                  style:
                                      TextStyle(color: textColor, fontSize: 12))
                            ]),
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
                    child: Text(
                        isEditing ? "Update Transaction" : "Save Transaction",
                        style: TextStyle(
                            color: theme.scaffoldBackgroundColor,
                            fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (titleCtrl.text.isNotEmpty &&
                          amountCtrl.text.isNotEmpty) {
                        double val = double.tryParse(amountCtrl.text) ?? 0.0;
                        if (isExpense) {
                          val = -val.abs();
                        } else {
                          val = val.abs();
                        }

                        if (isEditing && existingTx['id'] != null) {
                          moneyProvider.editTransaction(
                            existingTx['id'],
                            titleCtrl.text,
                            val,
                            isExpense ? selectedCat : 'Income',
                            date: selectedDate,
                            isFuture: isFuture,
                            linkedNoteId: selectedNoteId,
                            groupId: selectedGroupId,
                            excludeFromExpenses: excludeFromExpenses,
                            currency: existingTx['currency'] ?? moneyProvider.currentCurrency,
                          );
                        } else {
                          moneyProvider.addTransaction(
                            titleCtrl.text,
                            val,
                            isExpense ? selectedCat : 'Income',
                            date: selectedDate,
                            isFuture: isFuture,
                            linkedNoteId: selectedNoteId,
                            groupId: selectedGroupId,
                            excludeFromExpenses: excludeFromExpenses,
                            currency: moneyProvider.currentCurrency,
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
    final inputBg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 30,
            top: 20,
            left: 25,
            right: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text("New Category",
                style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            CupertinoTextField(
              controller: controller,
              placeholder: "Category Name",
              placeholderStyle: TextStyle(color: secondaryTextColor),
              style: TextStyle(color: textColor),
              decoration: BoxDecoration(
                  color: inputBg, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(16),
              autofocus: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: textColor,
                borderRadius: BorderRadius.circular(14),
                child: Text("Add Category",
                    style: TextStyle(
                        color: theme.scaffoldBackgroundColor,
                        fontWeight: FontWeight.bold)),
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    Provider.of<MoneyProvider>(context, listen: false)
                        .addCategory(controller.text);
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
  List<PieChartSectionData> _buildPieSections(
      Map<String, double> spendingByCategory) {
    if (spendingByCategory.isEmpty) return [];
    return spendingByCategory.entries.map((e) {
      final isTouched =
          spendingByCategory.keys.toList().indexOf(e.key) == _touchedIndex;
      final radius = isTouched ? 55.0 : 45.0;
      return PieChartSectionData(
          color: _getCategoryColor(e.key),
          value: e.value,
          showTitle: false,
          radius: radius);
    }).toList();
  }

  // [THEME] Minimalist Monochrome Palette that adapts
  Color _getCategoryColor(String cat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Light Mode: Shades of Black/Grey
    // Dark Mode: Shades of White/Grey
    if (isDark) {
      switch (cat) {
        case 'Food':
          return Colors.white;
        case 'Transport':
          return Colors.white70;
        case 'Entertainment':
          return Colors.white54;
        case 'Shopping':
          return Colors.white38;
        default:
          return Colors.white24;
      }
    } else {
      switch (cat) {
        case 'Food':
          return Colors.black;
        case 'Transport':
          return Colors.black87;
        case 'Entertainment':
          return Colors.black54;
        case 'Shopping':
          return Colors.black38;
        default:
          return Colors.black12;
      }
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'Food':
        return CupertinoIcons.cart;
      case 'Transport':
        return CupertinoIcons.car_detailed;
      case 'Entertainment':
        return CupertinoIcons.game_controller;
      case 'Shopping':
        return CupertinoIcons.bag;
      case 'Health':
        return CupertinoIcons.heart;
      case 'Income':
        return CupertinoIcons.money_dollar;
      default:
        return CupertinoIcons.circle_grid_3x3;
    }
  }

  void _showBudgetDialog(
      BuildContext context, String? category, double? currentLimit) {
    if (category != null && currentLimit == null) return;

    final selectedCat = category ?? 'Food';
    final limit = currentLimit ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _BudgetEditor(
          initialCategory: selectedCat,
          initialLimit: limit,
          isEditing: category != null),
    );
  }

  // --- GROUPS TAB BUILDER ---
  Widget _buildGroupsTab(MoneyProvider provider) {
    if (_viewingGroupId != null) {
      return _buildGroupDetailView(provider, _viewingGroupId!);
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final groups = provider.groups;

    return ListView(
      key: const ValueKey(3),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 180),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("SPENDING GROUPS",
                style: TextStyle(
                    color: secondaryTextColor, fontSize: 12, letterSpacing: 2)),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showCreateGroupDialog(context),
              child: Icon(CupertinoIcons.add_circled, color: textColor),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          "Organize transactions by trip, event, or project. Toggle individual items to exclude them from your personal budget.",
          style: TextStyle(color: secondaryTextColor, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 25),

        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(CupertinoIcons.folder,
                    size: 48, color: secondaryTextColor.withOpacity(0.3)),
                const SizedBox(height: 15),
                Text("No groups created yet.",
                    style: TextStyle(color: secondaryTextColor, fontSize: 14)),
                const SizedBox(height: 10),
                CupertinoButton(
                  onPressed: () => _showCreateGroupDialog(context),
                  child: Text("Create a Group",
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          )
        else
          ...groups.map((g) {
            final id = g['id'] as String;
            final count = provider.getGroupTransactionCount(id);
            final total = provider.getGroupTotal(id);
            final personal = provider.getGroupPersonalTotal(id);
            final excluded = total - personal;

            return GestureDetector(
              onTap: () => setState(() => _viewingGroupId = id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(CupertinoIcons.folder,
                                size: 22, color: textColor),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g['name'] ?? 'Trip',
                                  style: TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 3),
                              Text("$count transaction${count == 1 ? '' : 's'}",
                                  style: TextStyle(
                                      color: secondaryTextColor, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(CupertinoIcons.chevron_right,
                            color: secondaryTextColor.withOpacity(0.5), size: 16),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGroupStatSmall("Total", total, textColor),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        Expanded(
                          child: _buildGroupStatSmall("My Share", personal, Colors.greenAccent),
                        ),
                        if (excluded > 0) ...[
                          Container(
                            width: 1,
                            height: 24,
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          Expanded(
                            child: _buildGroupStatSmall("Excluded", excluded, Colors.orange),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildGroupStatSmall(String label, double val, Color color) {
    final theme = Theme.of(context);
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final moneyProv = Provider.of<MoneyProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(color: secondaryTextColor, fontSize: 10)),
        const SizedBox(height: 4),
        Text("${moneyProv.currentCurrencySymbol}${val.toStringAsFixed(2)}",
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildGroupDetailView(MoneyProvider provider, String groupId) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final txs = provider.getTransactionsForGroup(groupId);
    final total = provider.getGroupTotal(groupId);
    final personal = provider.getGroupPersonalTotal(groupId);
    final excluded = total - personal;

    final groupIdx = provider.groups.indexWhere((g) => g['id'] == groupId);
    final group = groupIdx != -1
        ? provider.groups[groupIdx]
        : {'name': 'Group', 'icon': 'folder'};

    return ListView(
      key: ValueKey("group-detail-$groupId"),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 180),
      children: [
        Row(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _viewingGroupId = null),
              child: Row(
                children: [
                  Icon(CupertinoIcons.left_chevron, color: textColor, size: 16),
                  const SizedBox(width: 4),
                  Text("Back", style: TextStyle(color: textColor, fontSize: 14)),
                ],
              ),
            ),
            const Spacer(),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showDeleteGroupConfirm(provider, groupId),
              child: const Text("Delete Group", style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 15),

        // Group Card Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Column(
            children: [
              Icon(CupertinoIcons.folder_fill, size: 48, color: textColor),
              const SizedBox(height: 10),
              Text(group['name'] ?? 'Group',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildGroupStatBig("Total Spent", total, textColor),
                  Container(
                    width: 1,
                    height: 36,
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                  _buildGroupStatBig("My Expense", personal, Colors.greenAccent),
                  Container(
                    width: 1,
                    height: 36,
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                  _buildGroupStatBig("Excluded", excluded, Colors.orange),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 25),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("TRANSACTIONS",
                style: TextStyle(
                    color: secondaryTextColor, fontSize: 12, letterSpacing: 2)),
            Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showLinkPastExpensesDialog(context, provider, groupId),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.link, color: textColor, size: 14),
                      const SizedBox(width: 4),
                      Text("Link Past", style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showAddTransactionToGroupDialog(context, groupId),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.add, color: textColor, size: 14),
                      const SizedBox(width: 4),
                      Text("Add New", style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 15),

        if (txs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text("No transactions in this group yet.",
                  style: TextStyle(color: secondaryTextColor, fontSize: 14)),
            ),
          )
        else
          ...txs.map((tx) {
            final isNeg = (tx['amount'] as double) < 0;
            final isExcluded = tx['excludeFromExpenses'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isExcluded
                        ? Colors.orange.withOpacity(0.3)
                        : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx['title'],
                            style: TextStyle(
                                color: isExcluded ? textColor.withOpacity(0.5) : textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                decoration: isExcluded ? TextDecoration.lineThrough : null)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(tx['category'] ?? 'General',
                                style: TextStyle(color: secondaryTextColor, fontSize: 11)),
                            const SizedBox(width: 8),
                            Text(
                                "${AppCurrency.getSymbol(tx['currency'] ?? provider.currentCurrency)}${(tx['amount'] as double).abs().toStringAsFixed(2)}",
                                style: TextStyle(
                                    color: isExcluded ? secondaryTextColor : textColor.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    decoration: isExcluded ? TextDecoration.lineThrough : null)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: isExcluded
                        ? Colors.orange.withOpacity(0.15)
                        : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () {
                      provider.toggleExcludeFromExpenses(tx['id']);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isExcluded ? CupertinoIcons.person_badge_minus : CupertinoIcons.person,
                          size: 14,
                          color: isExcluded ? Colors.orange : secondaryTextColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isExcluded ? "Excluded" : "My Expense",
                          style: TextStyle(
                              color: isExcluded ? Colors.orange : textColor.withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildGroupStatBig(String label, double val, Color color) {
    final theme = Theme.of(context);
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final moneyProv = Provider.of<MoneyProvider>(context, listen: false);
    return Column(
      children: [
        Text(label, style: TextStyle(color: secondaryTextColor, fontSize: 11)),
        const SizedBox(height: 6),
        Text("${moneyProv.currentCurrencySymbol}${val.toStringAsFixed(2)}",
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }

  void _showDeleteGroupConfirm(MoneyProvider provider, String groupId) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Delete Group?"),
        content: const Text("Transactions inside this group will be unlinked but not deleted."),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              provider.removeGroup(groupId);
              Navigator.pop(ctx);
              setState(() => _viewingGroupId = null);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
        final isDark = theme.brightness == Brightness.dark;
        final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 30,
              top: 20,
              left: 25,
              right: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text("New Spending Group",
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                "Create a group (e.g. Japan Trip) to organize and track expenses.",
                style: TextStyle(color: secondaryTextColor, fontSize: 12),
              ),
              const SizedBox(height: 20),
              CupertinoTextField(
                controller: nameCtrl,
                placeholder: "Group Name (e.g. Japan Trip)",
                placeholderStyle: TextStyle(color: secondaryTextColor),
                style: TextStyle(color: textColor),
                decoration: BoxDecoration(
                    color: inputBg, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(16),
                autofocus: true,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: textColor,
                  borderRadius: BorderRadius.circular(14),
                  child: Text("Create Group",
                      style: TextStyle(
                          color: theme.scaffoldBackgroundColor,
                          fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty) {
                      Provider.of<MoneyProvider>(context, listen: false)
                          .addGroup(nameCtrl.text, 'folder');
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddTransactionToGroupDialog(BuildContext context, String groupId) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController amountCtrl = TextEditingController();
    String selectedCategory = 'Food';
    bool excludeFromExpenses = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
          final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
          final isDark = theme.brightness == Brightness.dark;
          final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
          final provider = Provider.of<MoneyProvider>(context, listen: false);

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 30,
                top: 20,
                left: 25,
                right: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                Text("Add Expense to Group",
                    style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                CupertinoTextField(
                  controller: titleCtrl,
                  placeholder: "Title",
                  placeholderStyle: TextStyle(color: secondaryTextColor),
                  style: TextStyle(color: textColor),
                  decoration: BoxDecoration(
                      color: inputBg, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(16),
                  autofocus: true,
                ),
                const SizedBox(height: 15),
                CupertinoTextField(
                  controller: amountCtrl,
                  placeholder: "0.00",
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholderStyle: TextStyle(color: secondaryTextColor),
                  style: TextStyle(color: textColor),
                  prefix: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Icon(CupertinoIcons.money_dollar,
                          color: secondaryTextColor, size: 18)),
                  decoration: BoxDecoration(
                      color: inputBg, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 20),
                Text("Category",
                    style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: provider.categories.map((cat) {
                      final isSelected = selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedCategory = cat),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? textColor : inputBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(cat,
                              style: TextStyle(
                                  color: isSelected
                                      ? theme.scaffoldBackgroundColor
                                      : secondaryTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => setSheetState(() => excludeFromExpenses = !excludeFromExpenses),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: excludeFromExpenses
                          ? Colors.orange.withOpacity(0.1)
                          : inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: excludeFromExpenses
                          ? Border.all(color: Colors.orange.withOpacity(0.5))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          excludeFromExpenses
                              ? CupertinoIcons.checkmark_square_fill
                              : CupertinoIcons.square,
                          color: excludeFromExpenses
                              ? Colors.orange
                              : secondaryTextColor,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Exclude from my expenses",
                                  style: TextStyle(
                                      color: excludeFromExpenses ? Colors.orange : textColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              Text("Company or other people paying",
                                  style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: textColor,
                    borderRadius: BorderRadius.circular(14),
                    child: Text("Add Group Expense",
                        style: TextStyle(
                            color: theme.scaffoldBackgroundColor,
                            fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (titleCtrl.text.isNotEmpty && amountCtrl.text.isNotEmpty) {
                        double val = double.tryParse(amountCtrl.text) ?? 0.0;
                        provider.addTransaction(
                          titleCtrl.text,
                          -val.abs(),
                          selectedCategory,
                          groupId: groupId,
                          excludeFromExpenses: excludeFromExpenses,
                        );
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLinkPastExpensesDialog(BuildContext context, MoneyProvider provider, String groupId) {
    // Get all transactions that do not belong to this group
    final eligibleTxs = provider.transactions.where((t) => t['groupId'] != groupId).toList();

    // Map to keep track of checked state
    final checkedTxs = <String, bool>{};
    for (var tx in eligibleTxs) {
      checkedTxs[tx['id']] = false;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
          final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
          final isDark = theme.brightness == Brightness.dark;
          final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.only(top: 20, left: 25, right: 25, bottom: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                Text("Add Past Expenses",
                    style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  "Select existing transactions to add to this group.",
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
                const SizedBox(height: 15),
                Expanded(
                  child: eligibleTxs.isEmpty
                      ? Center(
                          child: Text("No other transactions available.",
                              style: TextStyle(color: secondaryTextColor)),
                        )
                      : ListView.separated(
                          itemCount: eligibleTxs.length,
                          separatorBuilder: (c, idx) => Divider(color: theme.dividerColor, height: 1),
                          itemBuilder: (context, idx) {
                            final tx = eligibleTxs[idx];
                            final txId = tx['id'] as String;
                            final isChecked = checkedTxs[txId] ?? false;
                            final amount = tx['amount'] as double;
                            final isExp = amount < 0;

                            return CheckboxListTile(
                              title: Text(tx['title'],
                                  style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                "${tx['date'].toString().split(' ')[0]} • ${tx['category'] ?? 'General'}",
                                style: TextStyle(color: secondaryTextColor, fontSize: 12),
                              ),
                              secondary: Text(
                                "${isExp ? '' : '+'}${AppCurrency.getSymbol(tx['currency'] ?? provider.currentCurrency)}${amount.abs().toStringAsFixed(2)}",
                                style: TextStyle(
                                    color: isExp ? textColor : Colors.greenAccent,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold),
                              ),
                              value: isChecked,
                              activeColor: theme.primaryColor,
                              checkColor: theme.scaffoldBackgroundColor,
                              onChanged: (val) {
                                setSheetState(() {
                                  checkedTxs[txId] = val ?? false;
                                });
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: textColor,
                    borderRadius: BorderRadius.circular(14),
                    child: Text("Add Selected",
                        style: TextStyle(
                            color: theme.scaffoldBackgroundColor,
                            fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final selectedIds = checkedTxs.entries
                          .where((e) => e.value)
                          .map((e) => e.key)
                          .toList();

                      for (var id in selectedIds) {
                        final tx = provider.transactions.firstWhere((t) => t['id'] == id);
                        provider.editTransaction(
                          id,
                          tx['title'],
                          tx['amount'],
                          tx['category'] ?? 'General',
                          date: DateTime.parse(tx['date']),
                          isFuture: tx['isFuture'] == true,
                          linkedNoteId: tx['linkedNoteId'],
                          groupId: groupId,
                          excludeFromExpenses: tx['excludeFromExpenses'] == true,
                        );
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showBatchDeleteConfirm(BuildContext context, MoneyProvider provider) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Delete Transactions?"),
        content: Text("Are you sure you want to delete ${_selectedTxIds.length} transactions? This cannot be undone."),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Delete"),
            onPressed: () {
              Navigator.pop(ctx);
              final count = _selectedTxIds.length;
              final deletedList = provider.transactions
                  .where((t) => _selectedTxIds.contains(t['id']))
                  .map((t) => Map<String, dynamic>.from(t))
                  .toList();
              provider.removeTransactions(_selectedTxIds);
              setState(() {
                _selectedTxIds.clear();
                _isMultiSelect = false;
              });
              MinimalistToast.showUndo(
                context,
                title: "$count transactions",
                onUndo: () => provider.restoreTransactions(deletedList),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showBatchCategoryDialog(BuildContext context, MoneyProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Choose Category for Selected", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: provider.categories.map((cat) {
                  return ActionChip(
                    avatar: Icon(_getCategoryIcon(cat), size: 14),
                    label: Text(cat),
                    onPressed: () {
                      provider.batchUpdateCategory(_selectedTxIds, cat);
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedTxIds.clear();
                        _isMultiSelect = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Updated category to $cat")),
                      );
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetEditor extends StatefulWidget {
  final String initialCategory;
  final double initialLimit;
  final bool isEditing;
  const _BudgetEditor(
      {required this.initialCategory,
      required this.initialLimit,
      required this.isEditing});

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
    amountCtrl = TextEditingController(
        text: widget.initialLimit > 0
            ? widget.initialLimit.toStringAsFixed(0)
            : "");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final isDark = theme.brightness == Brightness.dark;
    final inputBg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);
    final moneyProvider = Provider.of<MoneyProvider>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 30,
          top: 20,
          left: 25,
          right: 25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text(
              widget.isEditing ? "Edit Budget: $selectedCat" : "Set New Budget",
              style: TextStyle(
                  color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? textColor : inputBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                                color: isSelected
                                    ? theme.scaffoldBackgroundColor
                                    : secondaryTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            // [ADDED] Delete Button for Existing Budget
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: () {
                    moneyProvider.removeBudget(widget.initialCategory);
                    Navigator.pop(context);
                  },
                  icon: const Icon(CupertinoIcons.trash,
                      color: Colors.redAccent, size: 16),
                  label: const Text("Remove Budget",
                      style: TextStyle(color: Colors.redAccent))),
            ),
            const SizedBox(height: 10),
          ],
          CupertinoTextField(
            controller: amountCtrl,
            placeholder: "Monthly Limit",
            keyboardType: TextInputType.number,
            placeholderStyle: TextStyle(color: secondaryTextColor),
            style: TextStyle(color: textColor),
            prefix: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  moneyProvider.currentCurrencySymbol,
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                )),
            decoration: BoxDecoration(
                color: inputBg, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(16),
            autofocus: true,
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: textColor,
              borderRadius: BorderRadius.circular(14),
              child: Text("Save Budget",
                  style: TextStyle(
                      color: theme.scaffoldBackgroundColor,
                      fontWeight: FontWeight.bold)),
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

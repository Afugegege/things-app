import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/money_provider.dart';
import '../../providers/user_provider.dart';

class ExpenseSummaryWidget extends StatefulWidget {
  const ExpenseSummaryWidget({super.key});

  @override
  State<ExpenseSummaryWidget> createState() => _ExpenseSummaryWidgetState();
}

class _ExpenseSummaryWidgetState extends State<ExpenseSummaryWidget> {
  // 'Today', 'Week', 'Month', 'All'
  String _selectedTimeframe = 'Today';

  String _getTimeframeLabel(String tf) {
    switch (tf) {
      case 'Today':
        return 'Today';
      case 'Week':
        return 'This Week';
      case 'Month':
        return 'This Month';
      case 'All':
      default:
        return 'All Time';
    }
  }

  void _showSpendingDetails(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black);
    final dimmedColor = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white60 : Colors.black54);
    final moneyProv = Provider.of<MoneyProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final spent = moneyProv.getSpendingForTimeframe(_selectedTimeframe);
            final txns = moneyProv.getTransactionsForTimeframe(_selectedTimeframe);
            final catSpending = moneyProv.getCategorySpendingForTimeframe(_selectedTimeframe);
            final sortedCats = catSpending.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Container(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 32),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
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
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "SPENDING DETAILS",
                        style: TextStyle(
                          color: dimmedColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          Provider.of<UserProvider>(context, listen: false).changeView('wallet');
                        },
                        child: Row(
                          children: [
                            Text(
                              "Open Wallet",
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(CupertinoIcons.arrow_right, size: 12, color: textColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Timeframe switcher in sheet
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: ['Today', 'Week', 'Month', 'All'].map((tf) {
                        final isSelected = _selectedTimeframe == tf;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedTimeframe = tf);
                              setSheetState(() {});
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? Colors.white12 : Colors.black.withOpacity(0.08))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                tf,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? textColor : dimmedColor,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Total spent hero in sheet
                  Text(
                    "${moneyProv.currentCurrencySymbol}${spent.abs().toStringAsFixed(2)}",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    "${_getTimeframeLabel(_selectedTimeframe)} (${txns.length} transaction${txns.length == 1 ? '' : 's'})",
                    style: TextStyle(color: dimmedColor, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: [
                        if (sortedCats.isNotEmpty) ...[
                          Text(
                            "CATEGORIES",
                            style: TextStyle(
                              color: dimmedColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...sortedCats.map((entry) {
                            final pct = spent > 0 ? (entry.value / spent) : 0.0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        "${moneyProv.currentCurrencySymbol}${entry.value.toStringAsFixed(2)} (${(pct * 100).toStringAsFixed(0)}%)",
                                        style: TextStyle(
                                          color: dimmedColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct.clamp(0.0, 1.0),
                                      minHeight: 5,
                                      backgroundColor: isDark
                                          ? Colors.white.withOpacity(0.08)
                                          : Colors.black.withOpacity(0.06),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          "TRANSACTIONS",
                          style: TextStyle(
                            color: dimmedColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (txns.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                "No spending recorded in this period.",
                                style: TextStyle(color: dimmedColor, fontSize: 13),
                              ),
                            ),
                          )
                        else
                          ...txns.map((t) {
                            final double amt = (t['amount'] as num?)?.toDouble() ?? 0.0;
                            final String title = t['title']?.toString() ?? 'Expense';
                            final String cat = t['category']?.toString() ?? 'Other';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.04)
                                    : Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark
                                          ? Colors.white.withOpacity(0.06)
                                          : Colors.black.withOpacity(0.05),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.arrow_down_right,
                                      size: 14,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          cat,
                                          style: TextStyle(
                                            color: dimmedColor,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "-${moneyProv.currentCurrencySymbol}${amt.abs().toStringAsFixed(2)}",
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
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
    final double spent = moneyProvider.getSpendingForTimeframe(_selectedTimeframe);
    final int count = moneyProvider.getTransactionsForTimeframe(_selectedTimeframe).length;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black);
    final dimmedColor = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white60 : Colors.black54);
    final bgColor = isDark ? theme.cardColor : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(color: Colors.white12, width: 1.0)
            : Border.all(color: Colors.black.withOpacity(0.08), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "SPENDING",
                style: TextStyle(
                  color: dimmedColor,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => _showSpendingDetails(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Text(
                        "Details",
                        style: TextStyle(
                          color: dimmedColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_outward, color: dimmedColor, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Timeframe selector tabs
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: ['Today', 'Week', 'Month', 'All'].map((tf) {
                final isSelected = _selectedTimeframe == tf;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTimeframe = tf);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? Colors.white12 : Colors.black.withOpacity(0.08))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tf,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? textColor : dimmedColor,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showSpendingDetails(context),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${moneyProvider.currentCurrencySymbol}${spent.abs().toStringAsFixed(2)}",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 34,
                    fontWeight: FontWeight.w300,
                    height: 1.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getTimeframeLabel(_selectedTimeframe),
                      style: TextStyle(color: dimmedColor, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      "$count item${count == 1 ? '' : 's'}",
                      style: TextStyle(color: dimmedColor, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

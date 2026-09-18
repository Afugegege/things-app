import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/money_provider.dart';
import '../../providers/user_provider.dart';

class ExpensesChartWidget extends StatelessWidget {
  final bool isCompact;

  const ExpensesChartWidget({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black);
    final dimmedColor = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white60 : Colors.black54);
    final bgColor = isDark ? theme.cardColor : Colors.white;

    return Consumer<MoneyProvider>(
      builder: (context, moneyProv, child) {
        final currency = moneyProv.currentCurrencySymbol;
        final monthSpending = moneyProv.monthSpendingAmount;
        final catSpending = moneyProv.getCategorySpendingForTimeframe('Month');
        final sortedCats = catSpending.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topCats = sortedCats.take(isCompact ? 2 : 4).toList();
        final maxVal = topCats.isNotEmpty ? topCats.first.value : 1.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Provider.of<UserProvider>(context, listen: false).changeView('wallet');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
                width: 1.0,
              ),
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
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(CupertinoIcons.chart_bar_alt_fill, color: textColor, size: 14),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "SPENDING",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: dimmedColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "THIS MONTH",
                      style: TextStyle(
                        color: dimmedColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "$currency${monthSpending.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),
                if (topCats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "No expenses logged this month.",
                      style: TextStyle(color: dimmedColor, fontSize: 11),
                    ),
                  )
                else
                  Column(
                    children: topCats.map((entry) {
                      final pct = (maxVal > 0 ? entry.value / maxVal : 0.0).clamp(0.05, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
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
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  "$currency${entry.value.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    color: dimmedColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 6,
                                backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

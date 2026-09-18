import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/money_provider.dart';

class SavingsGoalWidget extends StatelessWidget {
  const SavingsGoalWidget({super.key});

  void _showDepositDialog(BuildContext context, Map<String, dynamic> goal) {
    final controller = TextEditingController(text: "50");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Add Funds to ${goal['title']}"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: "Deposit Amount (${Provider.of<MoneyProvider>(context, listen: false).currentCurrencySymbol})",
            prefixText: "${Provider.of<MoneyProvider>(context, listen: false).currentCurrencySymbol} ",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final double? amt = double.tryParse(controller.text);
              if (amt != null && amt > 0) {
                Provider.of<MoneyProvider>(context, listen: false)
                    .addGoalDeposit(goal['id'], amt);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Deposit"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black);
    final dimmedColor = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white60 : Colors.black54);
    final bgColor = isDark ? theme.cardColor : Colors.white;

    final moneyProv = Provider.of<MoneyProvider>(context);
    final goals = moneyProv.savingsGoals;

    // Use top goal or default demo goal
    final goal = goals.isNotEmpty
        ? goals.first
        : {
            'id': 'demo_goal',
            'title': 'Vacation Fund',
            'targetAmount': 2000.0,
            'currentAmount': 1450.0,
          };

    final double current = (goal['currentAmount'] as num?)?.toDouble() ?? 0.0;
    final double target = (goal['targetAmount'] as num?)?.toDouble() ?? 1000.0;
    final double percent = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER BADGE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.money_dollar_circle, size: 14, color: textColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "SAVINGS GOAL",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(CupertinoIcons.plus_circle_fill, color: textColor, size: 22),
                onPressed: () => _showDepositDialog(context, goal),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // GOAL TITLE
          Text(
            goal['title'] ?? 'Savings Target',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),

          // PROGRESS NUMBERS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${moneyProv.currentCurrencySymbol}${current.toStringAsFixed(0)}",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  "Target: ${moneyProv.currentCurrencySymbol}${target.toStringAsFixed(0)} (${(percent * 100).toStringAsFixed(0)}%)",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: dimmedColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // PROGRESS BAR
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
        ],
      ),
    );
  }
}

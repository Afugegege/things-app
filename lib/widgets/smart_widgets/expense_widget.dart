import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/money_provider.dart';

class ExpenseSummaryWidget extends StatelessWidget {
  const ExpenseSummaryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final moneyProvider = Provider.of<MoneyProvider>(context);
    final transactions = moneyProvider.transactions;
    
    // Calculate Today's Spend
    final double todaySpent = transactions
        .where((t) => (t['amount'] as double) < 0)
        .fold(0.0, (sum, t) => sum + (t['amount'] as double));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 140, 
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        gradient: isDark ? null : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE53935), // Red
            const Color(0xFFE35D5B), // Lighter red
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: isDark 
            ? Border.all(color: Colors.white24, width: 2.0) 
            : Border.all(color: const Color(0xFFE53935).withOpacity(0.1), width: 2.0), // Subtle red border
        boxShadow: isDark ? [] : [
          BoxShadow(color: const Color(0xFFE53935).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("SPENDING", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              Icon(Icons.arrow_outward, color: Colors.white38, size: 16),
            ],
          ),
          const Spacer(),
          Text(
            "\$${todaySpent.abs().toStringAsFixed(0)}",
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w300), // Thin clean font
          ),
          const SizedBox(height: 5),
          const Text("Today", style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}